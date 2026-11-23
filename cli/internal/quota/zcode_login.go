// SPDX-License-Identifier: MIT
//
// ZCode sign-in (QR code / OAuth) route, owner decision D369 (2026-11-21).
//
// Behaviour ported from Token Monitor (https://github.com/Javis603/token-monitor, MIT,
// Copyright (c) 2026 Javis) at 9de6288ca4e9af091b42f979570f1408781f8419:
// src/shared/providers/zai/zcodeDiscovery.js (selection, credential store, envelope and secret
// derivation, account-key naming, mirror fallback) and src/shared/providers/zai/limits.js
// (quota on the family's host, Start Plan billing on zcode.z.ai with X-Device-Mid, body codes,
// balance buckets). Licence: LICENSES/TokenMonitor-MIT.txt; notes: docs/borrowed/token-monitor-zcode.md.
//
// ModelPlan changes: read only behind the zai.account_usage.saved_login scope (default off); one
// request per read; never refresh, write, rename or delete anything of ZCode's; the credential
// stays in memory (no subscription reference, no log, no error text); a Start Plan JWT is checked
// for expiry before it is sent; a mainland (BigModel) login is never sent to zcode.z.ai.
package quota

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"math"
	"net/http"
	"net/url"
	"os"
	"os/user"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
)

// zcodeLoginTool names the ZaiConfigSource of the sign-in route; SettingsPath is ZCode's data
// folder (~/.zcode/v2), never a file outside it.
const zcodeLoginTool = "zcode-login"

// zcodeBillingURL is ZCode's own Start/Weekend plan balance endpoint. It is a z.ai (international)
// host; Token Monitor sends every family there, ModelPlan sends only the z.ai family.
const zcodeBillingURL = "https://zcode.z.ai/api/v1/zcode-plan/billing/balance"

// ZCodeLoginDir: the folder ZCode Desktop keeps its sign-in in.
func ZCodeLoginDir(home string) string { return filepath.Join(home, ".zcode", "v2") }

// ZCodeLoginPresent: ZCode's sign-in layout is there (detect.ZCodeLoginPresent; metadata only).
func ZCodeLoginPresent(home string) bool { return detect.ZCodeLoginPresent(home) }

// zcodeLoginStamp: size and modification time of the credential store, so a new sign-in releases
// a held "sign in again" state. File metadata only; the value is never read here.
func zcodeLoginStamp(home string) string {
	fi, err := os.Lstat(filepath.Join(ZCodeLoginDir(home), "credentials.json"))
	if err != nil {
		return ""
	}
	return strconv.FormatInt(fi.Size(), 10) + "." + strconv.FormatInt(fi.ModTime().UnixNano(), 10)
}

// zcodeLogin is one resolved read. credential is in memory only.
type zcodeLogin struct {
	region     string // global | bigmodel-cn
	billing    bool   // Start Plan balance (JWT) rather than Coding Plan quota (account key)
	credential string
	deviceMid  string
}

var zcodeProviderIDs = map[string]map[string]string{
	"startPlan":  {"zai": "builtin:zai-start-plan", "bigmodel": "builtin:bigmodel-start-plan"},
	"codingPlan": {"zai": "builtin:zai-coding-plan", "bigmodel": "builtin:bigmodel-coding-plan"},
}

// zcodeSelectionSlot: ZCode 3.12.3+ kind-based family selection.
var zcodeSelectionSlot = map[string]string{"start-plan": "startPlan", "individual-coding-plan": "codingPlan", "team-coding-plan": "codingPlan"}

type zcodeSettings struct {
	Domain     string `json:"providerFamilyDomain"`
	Selections map[string]struct {
		Kind string `json:"kind"`
	} `json:"providerFamilyConnectionSelections"`
	Legacy map[string]string `json:"modelProviderFamilySelectedKeys"`
}

type zcodeProvider struct {
	Enabled        *bool  `json:"enabled"`
	DisabledReason string `json:"systemDisabledReason"`
	Options        struct {
		APIKey  string `json:"apiKey"`
		BaseURL string `json:"baseURL"`
	} `json:"options"`
}

// zcodeSelectedProvider follows Token Monitor's selectedProviderId: the kind-based selection
// wins; the legacy selected-key string serves 3.11.x only; an unknown kind selects nothing.
func zcodeSelectedProvider(s zcodeSettings, family string) (id, kind string) {
	if sel, ok := s.Selections[family]; ok && strings.TrimSpace(sel.Kind) != "" {
		kind = strings.TrimSpace(sel.Kind)
		slot := zcodeSelectionSlot[kind]
		if slot == "" {
			return "", kind
		}
		return zcodeProviderIDs[slot][family], kind
	}
	legacy := strings.TrimSpace(s.Legacy[family])
	for _, prefix := range []string{"coding-plan:", "preset:"} {
		if rest, ok := strings.CutPrefix(legacy, prefix); ok {
			return strings.TrimSpace(rest), ""
		}
	}
	return "", ""
}

// zcodeCredentialSecret: ZCode's defaultCredentialSecret. An explicit ZCODE_CREDENTIAL_SECRET
// wins, otherwise machine-local values (platform, home directory, account name).
func zcodeCredentialSecret() string {
	if s := strings.TrimSpace(os.Getenv("ZCODE_CREDENTIAL_SECRET")); s != "" {
		return s
	}
	platform := runtime.GOOS
	if platform == "windows" {
		platform = "win32"
	}
	home, _ := os.UserHomeDir()
	name := "unknown"
	if u, err := user.Current(); err == nil && u.Username != "" {
		name = u.Username
	}
	return "zcode-credential-fallback:" + platform + ":" + home + ":" + name
}

// zcodeDecrypt opens ZCode's "enc:v1:" envelope: base64url(iv).base64url(tag).base64url(cipher),
// AES-256-GCM under sha256(secret). Any failure is "", never an error text.
func zcodeDecrypt(value, secret string) string {
	rest, ok := strings.CutPrefix(value, "enc:v1:")
	if !ok {
		return ""
	}
	parts := strings.Split(rest, ".")
	if len(parts) != 3 {
		return ""
	}
	decode := func(s string) []byte {
		b, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(s, "="))
		if err != nil {
			return nil
		}
		return b
	}
	iv, tag, body := decode(parts[0]), decode(parts[1]), decode(parts[2])
	if len(iv) != 12 || len(tag) != 16 || body == nil {
		return ""
	}
	key := sha256.Sum256([]byte(secret))
	block, err := aes.NewCipher(key[:])
	if err != nil {
		return ""
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return ""
	}
	plain, err := gcm.Open(nil, iv, append(body, tag...), nil)
	if err != nil {
		return ""
	}
	return string(plain)
}

// zcodeIdentity: the signed-in account as the family's stored profile names it (Token Monitor's
// storedProfileIdentity): a normalized profile's id, or a zai document's user_id.
func zcodeIdentity(store map[string]any, secret, family string) string {
	raw, _ := store["oauth:"+family+":user_info"].(string)
	doc := zcodeDecrypt(raw, secret)
	if doc == "" {
		return ""
	}
	var profile map[string]any
	if json.Unmarshal([]byte(doc), &profile) != nil {
		return ""
	}
	id, idOK := profile["id"].(string)
	_, userOK := profile["username"].(string)
	_, displayOK := profile["displayName"].(string)
	field := ""
	switch {
	case idOK && userOK && displayOK:
		field = id
	case family == "zai":
		field, _ = profile["user_id"].(string)
	}
	return strings.TrimSpace(field)
}

// zcodeJWTExpired: the token is a JWT whose exp has passed. A token that is not a JWT, or has no
// exp, is left to the server to judge.
func zcodeJWTExpired(token string, now time.Time) bool {
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return false
	}
	payload, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(parts[1], "="))
	if err != nil {
		return false
	}
	var claims struct {
		Exp *float64 `json:"exp"`
	}
	if json.Unmarshal(payload, &claims) != nil || claims.Exp == nil || *claims.Exp <= 0 {
		return false
	}
	return int64(*claims.Exp) <= now.Unix()
}

// zcodeBaseRegion: the region a provider entry's base URL names, "" when it names neither.
func zcodeBaseRegion(base string) string {
	u, err := url.Parse(strings.TrimSpace(base))
	if err != nil {
		return ""
	}
	switch strings.ToLower(u.Hostname()) {
	case "api.z.ai", "zcode.z.ai", "api.chatglm.site":
		return "global"
	case "open.bigmodel.cn", "bigmodel.cn":
		return "bigmodel-cn"
	}
	return ""
}

// readZCodeLogin resolves what one read may send and where, from ZCode's own files, read-only.
// The code on failure is a reader error code; nothing of the files appears in it.
func readZCodeLogin(dir string, now time.Time) (zcodeLogin, string) {
	var settings zcodeSettings
	var registry struct {
		Provider map[string]zcodeProvider `json:"provider"`
	}
	b, err := zaiConfigFile(filepath.Join(dir, "setting.json"))
	if err != nil {
		return zcodeLogin{}, errorCode(err)
	}
	if json.Unmarshal(b, &settings) != nil {
		return zcodeLogin{}, "parse_error"
	}
	if b, err = zaiConfigFile(filepath.Join(dir, "config.json")); err != nil {
		return zcodeLogin{}, errorCode(err)
	}
	if json.Unmarshal(b, &registry) != nil {
		return zcodeLogin{}, "parse_error"
	}
	family := strings.TrimSpace(settings.Domain)
	region := map[string]string{"zai": "global", "bigmodel": "bigmodel-cn"}[family]
	if region == "" {
		return zcodeLogin{}, "not_signed_in"
	}
	providerID, kind := zcodeSelectedProvider(settings, family)
	provider, ok := registry.Provider[providerID]
	if providerID == "" || !ok {
		return zcodeLogin{}, "not_signed_in"
	}
	if provider.Enabled != nil && !*provider.Enabled {
		if reason := strings.TrimSpace(provider.DisabledReason); reason == "" || reason == "oauth_provider_inactive" {
			return zcodeLogin{}, "not_signed_in"
		}
	}
	start := providerID == zcodeProviderIDs["startPlan"][family]
	if !start && providerID != zcodeProviderIDs["codingPlan"][family] {
		return zcodeLogin{}, "unsupported_login" // a pay-as-you-go API key entry: no plan quota to read
	}
	// Region scoping (Pulse lesson): the entry's own endpoint must not name the other region.
	if r := zcodeBaseRegion(provider.Options.BaseURL); r != "" && r != region {
		return zcodeLogin{}, "region_refused"
	}
	var store map[string]any
	if b, err = zaiConfigFile(filepath.Join(dir, "credentials.json")); err == nil {
		if json.Unmarshal(b, &store) != nil {
			store = nil
		}
	}
	// G3-158: ZCode 3.19+ entries (enc:v2) are keyed by a secret in the system credential store,
	// which is not read. Such a store is unsupported; neither "sign in again" nor the plaintext
	// mirror, which may belong to another account, stands in for it.
	for _, v := range store {
		if raw, ok := v.(string); ok && strings.HasPrefix(raw, "enc:") && !strings.HasPrefix(raw, "enc:v1:") {
			return zcodeLogin{}, "unsupported_login"
		}
	}
	secret := zcodeCredentialSecret()
	identity := ""
	if store != nil {
		identity = zcodeIdentity(store, secret, family)
	}
	mirror := strings.TrimSpace(provider.Options.APIKey)
	login := zcodeLogin{region: region, billing: start}
	if start {
		if family != "zai" {
			// zcode.z.ai is the international host; a mainland login is never sent there.
			return zcodeLogin{}, "region_refused"
		}
		raw, _ := store["zcodejwttoken"].(string)
		login.credential = zcodeDecrypt(raw, secret)
		if login.credential == "" && identity == "" {
			login.credential = mirror // 3.11.x: no store names the account
		}
		if login.credential == "" {
			return zcodeLogin{}, "login_expired"
		}
		if zcodeJWTExpired(login.credential, now) {
			return zcodeLogin{}, "login_expired"
		}
		login.deviceMid = zcodeDeviceMid(dir)
	} else {
		switch {
		case identity != "":
			name := "account-provider:coding-plan:account:" + family + "-" + kind + ":account:" + encodeURIComponent(identity) + ":api-key"
			raw, present := store[name].(string)
			if !present {
				// The account is known but its own key is absent; a mirror may belong to a previous account.
				return zcodeLogin{}, "login_expired"
			}
			login.credential = zcodeDecrypt(raw, secret)
		default:
			login.credential = mirror
		}
		if login.credential == "" {
			return zcodeLogin{}, "login_expired"
		}
	}
	login.credential = strings.TrimSpace(login.credential)
	if len(login.credential) > 8192 || strings.ContainsAny(login.credential, "\r\n\x00") {
		return zcodeLogin{}, "unsupported_login"
	}
	return login, ""
}

// encodeURIComponent: JavaScript's encodeURIComponent, which ZCode uses to name the entry.
func encodeURIComponent(s string) string {
	const keep = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
	var b strings.Builder
	for _, c := range []byte(s) {
		if strings.IndexByte(keep, c) >= 0 {
			b.WriteByte(c)
		} else {
			b.WriteString("%" + strings.ToUpper(strconv.FormatInt(int64(c)>>4, 16)) + strings.ToUpper(strconv.FormatInt(int64(c)&15, 16)))
		}
	}
	return b.String()
}

// zcodeDeviceMid: ZCode's own device id, which its billing gateway requires (code 3001 without it).
func zcodeDeviceMid(dir string) string {
	b, err := zaiConfigFile(filepath.Join(dir, "telemetry-state.json"))
	if err != nil {
		return ""
	}
	var state struct {
		DeviceMid string `json:"deviceMid"`
	}
	if json.Unmarshal(b, &state) != nil {
		return ""
	}
	mid := strings.TrimSpace(state.DeviceMid)
	if len(mid) > 256 || strings.ContainsAny(mid, "\r\n\x00") {
		return ""
	}
	return mid
}

// fetchZCodeLogin is one read of the sign-in route: Coding Plan quota on the family's own host, or
// the Start Plan balance on zcode.z.ai for the z.ai family. Errors carry fixed codes only.
func fetchZCodeLogin(ctx context.Context, c *http.Client, source ZaiConfigSource, now time.Time) codexbarEntry {
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC()}
	login, code := readZCodeLogin(source.SettingsPath, now)
	if code != "" {
		e.ErrorCode, e.Error = code, code
		return e
	}
	if source.Region != "" && source.Region != login.region {
		e.ErrorCode, e.Error = "region_refused", "region_refused"
		return e
	}
	c = accountReadClient(consent.ScopeZaiAccountUsageSavedLogin, c)
	headers := map[string]string{"Authorization": "Bearer " + login.credential}
	if login.billing {
		if login.deviceMid != "" {
			headers["X-Device-Mid"] = login.deviceMid
		}
		var r zcodeBillingResponse
		if err := getJSONHeaders(ctx, c, zcodeBillingURL, headers, &r); err != nil {
			e.ErrorCode = zcodeLoginFailure(errorCode(err))
			e.Error = e.ErrorCode
			return e
		}
		return parseZCodeBilling(r, now)
	}
	host := zaiHosts[login.region]
	if host == "" {
		e.ErrorCode, e.Error = "region_refused", "region_refused"
		return e
	}
	var r zaiResponse
	if err := getJSONHeaders(ctx, c, host+"/api/monitor/usage/quota/limit", headers, &r); err != nil {
		e.ErrorCode = zcodeLoginFailure(errorCode(err))
		e.Error = e.ErrorCode
		return e
	}
	e = parseZai(r, now)
	if e.Status != "ok" {
		e.ErrorCode = zcodeLoginFailure(e.ErrorCode)
		e.Error = e.ErrorCode
	}
	return e
}

// zcodeLoginFailure: a rejected ZCode credential means ZCode's sign-in has ended; the remedy is to
// sign in to ZCode again (ModelPlan never renews it).
func zcodeLoginFailure(code string) string {
	if code == "http_401" || code == "http_403" {
		return "login_expired"
	}
	return code
}

type zcodeBillingResponse struct {
	Code    *int  `json:"code"`
	Success *bool `json:"success"`
	Data    *struct {
		Plans []struct {
			Name         string `json:"name"`
			Status       string `json:"status"`
			PlanID       string `json:"plan_id"`
			UserPlanID   string `json:"user_plan_id"`
			Entitlements []struct {
				ID     string `json:"entitlement_id"`
				Period string `json:"period"`
			} `json:"entitlements"`
		} `json:"plans"`
		Balances []struct {
			EntitlementID string          `json:"entitlement_id"`
			PlanID        string          `json:"plan_id"`
			UserPlanID    string          `json:"user_plan_id"`
			ShowName      string          `json:"show_name"`
			Period        string          `json:"period"`
			Total         *float64        `json:"total_units"`
			Used          *float64        `json:"used_units"`
			Remaining     *float64        `json:"remaining_units"`
			Percentage    *float64        `json:"percentage"`
			ExpiresAt     json.RawMessage `json:"expires_at"`
			PeriodEnd     json.RawMessage `json:"period_end"`
		} `json:"balances"`
	} `json:"data"`
}

// zcodeSeconds: the billing gateway's Unix seconds, as a number or an all-digit string; a
// non-positive value is absent.
func zcodeSeconds(raw json.RawMessage) *time.Time {
	s := strings.Trim(strings.TrimSpace(string(raw)), `"`)
	if s == "" || strings.Trim(s, "0123456789") != "" {
		return nil
	}
	n, err := strconv.ParseInt(s, 10, 64)
	if err != nil || n <= 0 {
		return nil
	}
	t := time.Unix(n, 0).UTC()
	return &t
}

// parseZCodeBilling follows Token Monitor's parseZcodeStartPlanBalances: one bucket per model
// name (complete buckets of the same name are added), daily when every grant is daily with one
// reset time. Body code 401/403 is a rejected sign-in; another non-success code is a state, not a
// server error (Token Monitor's readZaiBody).
func parseZCodeBilling(r zcodeBillingResponse, now time.Time) codexbarEntry {
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC(), ErrorCode: "schema_changed"}
	if r.Code != nil && (*r.Code == 401 || *r.Code == 403) {
		e.ErrorCode = "login_expired"
		e.Error = e.ErrorCode
		return e
	}
	if r.Code != nil && *r.Code == 500 {
		e.ErrorCode = "no_plan" // no plan under this sign-in: a state, not a server error
		e.Error = e.ErrorCode
		return e
	}
	if r.Code != nil && *r.Code != 0 && *r.Code != 200 {
		e.ErrorCode = "other"
		e.Error = e.ErrorCode
		return e
	}
	if r.Data == nil {
		e.Error = e.ErrorCode
		return e
	}
	period := map[[2]string]string{}
	for _, p := range r.Data.Plans {
		for _, ent := range p.Entitlements {
			if ent.ID == "" || ent.Period == "" {
				continue
			}
			for _, key := range []string{p.UserPlanID, p.PlanID} {
				if key != "" {
					period[[2]string{key, ent.ID}] = ent.Period
				}
			}
		}
	}
	type bucket struct {
		name                   string
		total, used, remaining float64
		complete               bool
		percent                *float64
		periods                map[string]bool
		resets                 map[int64]bool
		earliest               *time.Time
	}
	groups := map[string]*bucket{}
	var order []string
	for i, b := range r.Data.Balances {
		total, used, remaining := b.Total, b.Used, b.Remaining
		if total == nil && used == nil && remaining == nil {
			continue
		}
		if used == nil && total != nil && remaining != nil {
			v := math.Max(0, *total-*remaining)
			used = &v
		}
		if remaining == nil && total != nil && used != nil {
			v := math.Max(0, *total-*used)
			remaining = &v
		}
		p := ""
		for _, key := range []string{b.UserPlanID, b.PlanID} {
			if p == "" && key != "" && b.EntitlementID != "" {
				p = period[[2]string{key, b.EntitlementID}]
			}
		}
		if p == "" {
			p = b.Period
		}
		name := label(b.ShowName)
		complete := total != nil && *total > 0 && remaining != nil && used != nil
		key := strings.ToLower(name)
		if name == "" || !complete {
			key = "#" + strconv.Itoa(i)
		}
		g := groups[key]
		if g == nil {
			g = &bucket{name: name, complete: true, periods: map[string]bool{}, resets: map[int64]bool{}}
			groups[key] = g
			order = append(order, key)
		}
		if complete {
			g.total += *total
			g.used += *used
			g.remaining += *remaining
		} else {
			g.complete = false
			if total != nil && *total > 0 && remaining != nil {
				v := 100 - *remaining / *total * 100
				g.percent = &v
			} else if total != nil && *total > 0 && used != nil {
				v := *used / *total * 100
				g.percent = &v
			} else if b.Percentage != nil {
				v := *b.Percentage
				g.percent = &v
			}
		}
		g.periods[p] = true
		at := zcodeSeconds(b.ExpiresAt)
		if at == nil {
			at = zcodeSeconds(b.PeriodEnd)
		}
		if at != nil {
			g.resets[at.Unix()] = true
			if g.earliest == nil || at.Before(*g.earliest) {
				g.earliest = at
			}
		}
	}
	sort.SliceStable(order, func(i, j int) bool { return groups[order[i]].name < groups[order[j]].name })
	e.Windows = []Window{}
	for _, key := range order {
		g := groups[key]
		var used float64
		switch {
		case g.complete && g.total > 0:
			used = g.used / g.total * 100
		case g.percent != nil:
			used = *g.percent
		default:
			continue
		}
		used = math.Round(math.Max(0, math.Min(100, used))*10) / 10
		w := Window{Kind: "unknown", Limit: g.name, UsedPercent: &used, ResetMode: "fixed", ObservedAt: now.UTC()}
		if len(g.periods) == 1 && g.periods["daily"] && len(g.resets) <= 1 {
			w.WindowMinutes = 24 * 60
		}
		if g.earliest != nil && g.earliest.After(now) {
			at := *g.earliest
			w.ResetsAt = &at
		}
		e.Windows = append(e.Windows, w)
	}
	for _, p := range r.Data.Plans {
		if p.Status == "active" {
			if name := label(p.Name); name != "" {
				e.Plan = name
				break
			}
		}
	}
	e.Status, e.ErrorCode, e.Error = "ok", "", ""
	return e
}

// zcodeProviderFileKeyless: ZCode's provider file selects no key (no selection, an account
// selection, or a selected rule without a key), so the key route can never read. The file is read
// only when its size or time changed (paths are built every watcher pass); the key, if any, is
// dropped at once and only the verdict is kept.
var zcodeProviderRead = zaiConfigFile

// Discovery may use a previous admitted classification, but never opens the
// provider file itself. A changed file requires another admitted scan.
func zcodeProviderCachedKeyless(path string) bool {
	fi, err := os.Lstat(path)
	if err != nil || !fi.Mode().IsRegular() {
		return false
	}
	stamp := strconv.FormatInt(fi.Size(), 10) + "." + strconv.FormatInt(fi.ModTime().UnixNano(), 10)
	zcodeKeylessMu.Lock()
	defer zcodeKeylessMu.Unlock()
	m, ok := zcodeKeylessMemo[path]
	return ok && m.stamp == stamp && m.keyless
}

func zcodeProviderFileKeyless(path string) bool {
	fi, err := os.Lstat(path)
	if err != nil || !fi.Mode().IsRegular() {
		return false
	}
	stamp := strconv.FormatInt(fi.Size(), 10) + "." + strconv.FormatInt(fi.ModTime().UnixNano(), 10)
	zcodeKeylessMu.Lock()
	defer zcodeKeylessMu.Unlock()
	if m, ok := zcodeKeylessMemo[path]; ok && m.stamp == stamp {
		return m.keyless
	}
	b, err := zcodeProviderRead(path)
	if err != nil {
		return false // An I/O failure is not a classification; retry on the next pass.
	}
	_, key, state, code := zcodeProviderKey(b)
	keyless := (state != "" && (code == "unsupported_login" || code == "no_key")) || (state == "" && strings.TrimSpace(key) == "")
	zcodeKeylessMemo[path] = zcodeKeylessEntry{stamp, keyless}
	return keyless
}

type zcodeKeylessEntry struct {
	stamp   string
	keyless bool
}

var (
	zcodeKeylessMu   sync.Mutex
	zcodeKeylessMemo = map[string]zcodeKeylessEntry{}
)

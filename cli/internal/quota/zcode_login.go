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
	"encoding/hex"
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
	key := sha256.Sum256([]byte(secret))
	return zcodeOpen(rest, key[:])
}

// zcodeOpen opens one sealed payload, iv.tag.cipher in base64url, AES-256-GCM under a 32-byte key.
func zcodeOpen(payload string, key []byte) string {
	parts := strings.Split(payload, ".")
	if len(parts) != 3 || len(key) != 32 {
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
	block, err := aes.NewCipher(key)
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

// D380: ZCode 3.19+ (zai-org/ZCode packages/shared/src/credential-security/systemCredentialCipher.ts)
// keeps a random 32-byte key in the system credential store: a generic password under the service
// "ZCode Credential Encryption", account hex(sha256(absolute credentials.json path)), whose value
// is the key in unpadded base64url (43 characters). Entries are "enc:v2:os:<fp>:<iv>.<tag>.<ct>",
// fp = the first 24 hex digits of sha256(key). ModelPlan reads that item only through the app's
// credential operation, after the user's own Keychain choice, and only in memory.
const (
	zcodeKeychainService = "ZCode Credential Encryption"
	zcodeV2OSPrefix      = "enc:v2:os:"
)

// ZCodeKeychainAccount: the Keychain account ZCode files its key under for a credentials file.
func ZCodeKeychainAccount(credentialsPath string) string {
	abs, err := filepath.Abs(credentialsPath)
	if err != nil {
		return ""
	}
	sum := sha256.Sum256([]byte(abs))
	return hex.EncodeToString(sum[:])
}

// zcodeKeychainKey decodes the Keychain item's value; nil when it is not a 32-byte base64url key.
func zcodeKeychainKey(encoded []byte) []byte {
	if len(encoded) != 43 {
		return nil
	}
	for _, c := range encoded {
		if !(c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-' || c == '_') {
			return nil
		}
	}
	key := make([]byte, 32)
	if n, err := base64.RawURLEncoding.Decode(key, encoded); err != nil || n != 32 {
		clear(key)
		return nil
	}
	return key
}

func zcodeKeyFingerprint(key []byte) string {
	sum := sha256.Sum256(key)
	return hex.EncodeToString(sum[:])[:24]
}

// zcodeDecryptV2 opens an "enc:v2:os:" entry with the Keychain key; "" on any mismatch or failure.
func zcodeDecryptV2(value string, key []byte) string {
	rest, ok := strings.CutPrefix(value, zcodeV2OSPrefix)
	if !ok || key == nil {
		return ""
	}
	fp, payload, ok := strings.Cut(rest, ":")
	if !ok || fp != zcodeKeyFingerprint(key) {
		return ""
	}
	return zcodeOpen(payload, key)
}

// zcodeStoreFormat names the store's encryption: "v1" (machine-derived secret, ZCode 3.11-3.18),
// "os" (Keychain key, 3.19+), "" for a store without encrypted entries, or "unsupported" for
// anything else (enc:v2:env, an unknown envelope, or v1 and v2 entries mixed mid-migration).
func zcodeStoreFormat(dir string, store map[string]any) string {
	v1, os2, other := false, false, false
	for _, v := range store {
		raw, ok := v.(string)
		if !ok || !strings.HasPrefix(raw, "enc:") {
			continue
		}
		switch {
		case strings.HasPrefix(raw, "enc:v1:"):
			v1 = true
		case strings.HasPrefix(raw, zcodeV2OSPrefix):
			os2 = true
		default:
			other = true
		}
	}
	pinned := zcodeSourcePinned(dir)
	switch {
	case other || v1 && os2 || v1 && pinned:
		return "unsupported"
	case os2 || pinned:
		return "os"
	case v1:
		return "v1"
	}
	return ""
}

// zcodeSourcePinned: ZCode's credential-source marker pins the folder to the system store ("os").
func zcodeSourcePinned(dir string) bool {
	fi, err := os.Lstat(filepath.Join(dir, "credential-source"))
	if err != nil || !fi.Mode().IsRegular() || fi.Size() > 64 {
		return false
	}
	b, err := os.ReadFile(filepath.Join(dir, "credential-source"))
	return err == nil && strings.TrimSpace(string(b)) == "os"
}

// ZCodeKeychain is the in-memory Keychain capability of one ZCode sign-in read (D380). Consent is
// the saved-login scope's own Keychain choice (allowed | denied | unset). Key runs the app's
// credential operation and returns the item's value or a closed status; nil without the app.
type ZCodeKeychain struct {
	Consent string
	Key     func(context.Context) ([]byte, string)
	// StillValid is checked again after the store is opened: a consent revoked meanwhile drops
	// the key and the plaintext before anything is sent.
	StillValid func() bool
}

// zcodeKeychainFailure maps the credential operation's closed status to a reader code.
func zcodeKeychainFailure(status string) string {
	switch status {
	case "denied":
		return "keychain_denied"
	case "canceled":
		return "keychain_canceled"
	case "interaction_required", "timeout", "keychain-confirmation-needed", "confirmation-needed":
		return "keychain_confirmation_needed"
	case "consent-required", "consent_required", "unset":
		return "keychain_unset"
	}
	return "keychain_unavailable"
}

// zcodeIdentity: the signed-in account as the family's stored profile names it (Token Monitor's
// storedProfileIdentity): a normalized profile's id, or a zai document's user_id.
func zcodeIdentity(store map[string]any, open func(string) string, family string) string {
	raw, _ := store["oauth:"+family+":user_info"].(string)
	doc := open(raw)
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
func readZCodeLogin(ctx context.Context, dir string, keychain *ZCodeKeychain, now time.Time) (zcodeLogin, string) {
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
	// The route follows the store's own format (owner, 2026-11-21): enc:v1 opens with ZCode's
	// machine-derived secret (3.11-3.18); enc:v2:os (3.19+, credential-source "os") opens only with
	// the Keychain key, after the user's own Keychain choice (D380). Anything else, including a store
	// mixing both, is unsupported. A Keychain-bound store never falls back to config.json's
	// plaintext mirror, which may belong to a previous account.
	format := zcodeStoreFormat(dir, store)
	if format == "unsupported" {
		return zcodeLogin{}, "unsupported_login"
	}
	secret := zcodeCredentialSecret()
	open := func(v string) string { return zcodeDecrypt(v, secret) }
	if format == "os" {
		switch {
		case keychain == nil || keychain.Consent == "" || keychain.Consent == "unset":
			return zcodeLogin{}, "keychain_unset"
		case keychain.Consent != "allowed":
			return zcodeLogin{}, "keychain_denied"
		case keychain.Key == nil:
			return zcodeLogin{}, "keychain_unavailable" // no app credential operation (standalone CLI)
		}
		encoded, status := keychain.Key(ctx)
		key := zcodeKeychainKey(encoded)
		clear(encoded)
		if status != "" && status != "ok" {
			clear(key)
			return zcodeLogin{}, zcodeKeychainFailure(status)
		}
		if key == nil {
			return zcodeLogin{}, "keychain_unavailable"
		}
		defer clear(key)
		fp := zcodeKeyFingerprint(key)
		matched := false
		for _, v := range store {
			if raw, ok := v.(string); ok && strings.HasPrefix(raw, zcodeV2OSPrefix+fp+":") {
				matched = true
			}
		}
		if !matched && len(store) > 0 {
			return zcodeLogin{}, "keychain_unavailable" // the item's key opens none of this store
		}
		open = func(v string) string { return zcodeDecryptV2(v, key) }
	}
	identity := ""
	if store != nil {
		identity = zcodeIdentity(store, open, family)
	}
	mirror := strings.TrimSpace(provider.Options.APIKey)
	login := zcodeLogin{region: region, billing: start}
	if start {
		if family != "zai" {
			// zcode.z.ai is the international host; a mainland login is never sent there.
			return zcodeLogin{}, "region_refused"
		}
		raw, _ := store["zcodejwttoken"].(string)
		login.credential = open(raw)
		if login.credential == "" && identity == "" && format != "os" {
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
			login.credential = open(raw)
		case format == "os":
			return zcodeLogin{}, "login_expired" // no account in the Keychain-bound store; never the mirror
		default:
			login.credential = mirror
		}
		if login.credential == "" {
			return zcodeLogin{}, "login_expired"
		}
	}
	if format == "os" && keychain.StillValid != nil && !keychain.StillValid() {
		return zcodeLogin{}, "consent_required"
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
	login, code := readZCodeLogin(ctx, source.SettingsPath, source.Keychain, now)
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
	keyless := false
	if b, err := zaiConfigFile(path); err == nil {
		_, key, state, code := zcodeProviderKey(b)
		keyless = (state != "" && (code == "unsupported_login" || code == "no_key")) || (state == "" && strings.TrimSpace(key) == "")
	}
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

// WithZCodeKeychain binds the app's credential operation (D380) to ZCode's sign-in route when the
// scope's Keychain choice is Allow. key returns the item's value for one read, or a closed status;
// the caller holds nothing. Any other grant, or a route without that choice, is returned unchanged.
func WithZCodeKeychain(p Paths, key func(context.Context) ([]byte, string)) Paths {
	g, ok := p.ReaderAccessGrant("zai")
	if !ok || g.ConfigSource == nil || g.ConfigSource.Tool != zcodeLoginTool || g.ConfigSource.Keychain == nil || g.ConfigSource.Keychain.Consent != "allowed" || key == nil {
		return p
	}
	source := *g.ConfigSource
	keychain := *source.Keychain
	still := g.StillValid
	keychain.Key = func(ctx context.Context) ([]byte, string) {
		// Revoked or changed consent: no Keychain operation at all.
		if ctx.Err() != nil || (still != nil && !still()) {
			return nil, "consent-required"
		}
		return key(ctx)
	}
	keychain.StillValid = still
	source.Keychain = &keychain
	g.ConfigSource = &source
	grants := map[string]ReaderGrant{}
	for provider, v := range p.ReaderAccess.Grants {
		grants[provider] = v
	}
	grants["zai"] = g
	p.ReaderAccess = &ReaderAccess{Grants: grants}
	return p
}

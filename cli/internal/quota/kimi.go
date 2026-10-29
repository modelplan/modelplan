package quota

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"io"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"
)

// Undocumented compatibility endpoint. Contract evidence: CodexBar (0827f30,
// MIT) KimiModels/UsageFetcher and token-monitor (0c7dd85, MIT) kimi/limits.
// Original implementation. The legacy explicit-key route is separate from the
// consent-admitted, China-only saved-login route below; neither refreshes auth.
var kimiHosts = map[string]string{"china": "https://api.kimi.com", "international": "https://api.kimi.ai"}
var kimiReader = &nativeReader{Name: "Kimi Code", Regions: []string{"china", "international"}, KeyEnv: "KIMI_CODE_API_KEY", Fetch: fetchKimi, Managed: collectKimiLogin, Profiles: kimiLoginProfiles, Budget: &nativeReadBudget{Due: kimiBudgetDue, Reserve: kimiReserve, Finish: kimiFinish}}

const KimiEndpointNotice = "Undocumented compatibility endpoint: GET /coding/v1/usages. Only the selected environment key is read; its value is never printed or stored. No Kimi credentials are refreshed or rewritten."

func KimiHost(region string) string {
	if region == "" {
		region = "china"
	}
	return kimiHosts[region]
}

func fetchKimi(ctx context.Context, c *http.Client, region, key string, now time.Time) codexbarEntry {
	c = accountReadClient(consent.ScopeKimiAccountUsageAPIKey, c)
	e := codexbarEntry{Status: "error", ObservedAt: now.UTC(), Plan: "Kimi Code"}
	host := kimiHosts[region]
	if host == "" {
		e.Error = "unknown region"
		return e
	}
	if key == "" {
		e.Error = "no API key in the environment; Kimi quota is unknown. The plan-key quota endpoint is undocumented; see docs/kimi-code-quota.md"
		return e
	}
	// A redirect must never send the region's key to another host/path.
	client := *c
	client.Jar = nil
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	var raw json.RawMessage
	if err := getJSON(ctx, &client, host+"/coding/v1/usages", key, &raw); err != nil {
		e.Error = err.Error()
		e.ErrorCode = errorCode(err)
		return e
	}
	return parseKimi(raw, now)
}

func parseKimi(b []byte, now time.Time) codexbarEntry {
	e := codexbarEntry{ErrorCode: "schema_changed", Status: "error", ObservedAt: now.UTC(), Plan: "Kimi Code", Error: "unsupported Kimi quota format"}
	var body map[string]json.RawMessage
	if err := json.Unmarshal(b, &body); err != nil {
		e.ErrorCode = jsonErrorCode(err)
		return e
	}
	if body == nil || body["error"] != nil {
		return e
	}
	// Some monitors accept the same payload in a data envelope.
	if data := body["data"]; data != nil {
		if json.Unmarshal(data, &body) != nil || body == nil || body["error"] != nil {
			return e
		}
	}
	by := map[int]Window{}
	add := func(minutes int, raw json.RawMessage, ratio bool) {
		var v map[string]json.RawMessage
		if json.Unmarshal(raw, &v) != nil || v == nil {
			return
		}
		kind := "unknown"
		switch minutes {
		case 300:
			kind = "five_hour"
		case 10080:
			kind = "weekly"
		case 43200:
			kind = "monthly"
		}
		w := Window{Kind: kind, WindowMinutes: minutes, ResetMode: "fixed", ObservedAt: now.UTC()}
		if w.Kind == "unknown" {
			w.Limit = strconv.Itoa(minutes) + " minute quota"
		}
		for _, k := range []string{"reset_time", "resetTime", "reset_at", "resetAt"} {
			var s string
			if json.Unmarshal(v[k], &s) == nil {
				if at := stamp(s); at != nil {
					w.ResetsAt = at
					break
				}
			}
		}
		if ratio {
			n := kimiNumber(v["used_ratio"], false)
			if n == nil {
				n = kimiNumber(v["usedRatio"], false)
			}
			if n != nil {
				p := math.Min(100, *n*100)
				w.UsedPercent = &p
			}
		} else {
			limit, used, remaining := kimiNumber(v["limit"], true), kimiNumber(v["used"], true), kimiNumber(v["remaining"], true)
			if limit != nil && *limit > 0 {
				if used == nil && remaining != nil && *remaining <= *limit {
					n := *limit - *remaining
					used = &n
				}
				if used != nil {
					p := math.Min(100, *used / *limit * 100)
					w.UsedPercent = &p
				}
			}
		}
		if old, ok := by[minutes]; ok {
			// Do not combine values from different reset periods. A valid ratio pool
			// supersedes a legacy window; matching periods retain the higher use.
			if w.UsedPercent == nil {
				return
			}
			if old.UsedPercent != nil && old.ResetsAt != nil && w.ResetsAt != nil && math.Abs(old.ResetsAt.Sub(*w.ResetsAt).Seconds()) <= 2 && *old.UsedPercent > *w.UsedPercent {
				w.UsedPercent = old.UsedPercent
			}
		}
		by[minutes] = w
	}
	if raw := body["usage"]; raw != nil && string(raw) != "null" {
		add(10080, raw, false)
	}
	var limits []struct {
		Window struct {
			Duration int    `json:"duration"`
			TimeUnit string `json:"timeUnit"`
		} `json:"window"`
		Detail json.RawMessage `json:"detail"`
	}
	if json.Unmarshal(body["limits"], &limits) == nil && len(limits) <= 64 {
		for _, l := range limits {
			unit := map[string]int{"TIME_UNIT_MINUTE": 1, "TIME_UNIT_HOUR": 60, "TIME_UNIT_DAY": 1440}[l.Window.TimeUnit]
			if unit > 0 && l.Window.Duration > 0 && l.Window.Duration <= 46000/unit {
				m := l.Window.Duration * unit
				if _, seen := by[m]; !seen {
					add(m, l.Detail, false)
				}
			}
		}
	}
	var pools map[string]json.RawMessage
	if json.Unmarshal(body["usages"], &pools) == nil {
		for _, p := range []struct {
			key     string
			minutes int
		}{{"limit_5h", 300}, {"limit_7d", 10080}, {"limit_month_total", 43200}} {
			if raw := pools[p.key]; raw != nil && string(raw) != "null" {
				add(p.minutes, raw, true)
			}
		}
	}
	minutes := make([]int, 0, len(by))
	for m := range by {
		minutes = append(minutes, m)
	}
	sort.Ints(minutes)
	for _, m := range minutes {
		if w, ok := by[m]; ok {
			// Neither an expired window nor a malformed reset can imply a fresh tank.
			if w.ResetsAt != nil && !w.ResetsAt.After(now) {
				w.UsedPercent = nil
			}
			e.Windows = append(e.Windows, w)
		}
	}
	if len(e.Windows) > 0 {
		e.Status, e.Error = "ok", ""
		e.ErrorCode = ""
	}
	return e
}

// Saved-login approach/headers: CodexBar 0.81.0 KimiSettingsReader.swift (MIT),
// ee890b5f392e70d6e20162d3e95cf9f1be265b60. Unlike that helper, never create a
// device ID, import cookies, refresh auth or enrich through extra web endpoints.
var kimiLoginHost = "https://api.kimi.com"
var kimiLoginID = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._-]{0,199}$`)

func kimiLoginProfiles() []ReaderProfile {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil
	}
	root := filepath.Join(home, ".kimi-code")
	if override := os.Getenv("KIMI_CODE_HOME"); override != "" {
		if !filepath.IsAbs(override) {
			return nil
		}
		root = override
	}
	return []ReaderProfile{{Root: root}}
}

type kimiAttempt struct {
	SchemaVersion int       `json:"schemaVersion"`
	Next          time.Time `json:"nextAttemptAt"`
}

func kimiBudgetPath(cache string) string {
	return filepath.Join(cache, "observed", "kimi-attempt-v1.json")
}
func kimiBudgetDue(cache string, now time.Time) bool {
	b, status := readBounded(kimiBudgetPath(cache), 4096)
	if status == "missing" {
		return true
	}
	var s kimiAttempt
	return status == "" && json.Unmarshal(b, &s) == nil && s.SchemaVersion == 1 && !now.Before(s.Next)
}
func kimiFinish(cache string, next time.Time) error {
	path := kimiBudgetPath(cache)
	if os.MkdirAll(filepath.Dir(path), 0o700) != nil {
		return errors.New("Kimi usage budget unavailable")
	}
	b, _ := json.Marshal(kimiAttempt{SchemaVersion: 1, Next: next.UTC()})
	if writeAtomic(path, append(b, '\n')) != nil {
		return errors.New("Kimi usage budget unavailable")
	}
	return nil
}
func kimiReserve(cache string, now time.Time) error { return kimiFinish(cache, now.Add(5*time.Minute)) }

func collectKimiLogin(ctx context.Context, c *http.Client, r readerContext) readerOutcome {
	c = accountReadClient(consent.ScopeKimiAccountUsageSavedLogin, c)
	meta := r.Previous.Metadata
	changed := meta.CredentialKey != ""
	fail := func(state, notice string, codes ...string) readerOutcome {
		return readerOutcome{Entry: readerEntry{Status: state, Notice: notice, ErrorCode: failureCode(state, codes)}, Invalidate: changed}
	}
	if r.Grant.Region != "" && r.Grant.Region != "china" {
		return fail("unavailable", "Kimi Code saved login is supported in China only")
	}
	for _, name := range []string{"KIMI_CODE_API_KEY", "KIMI_CODE_BASE_URL", "KIMI_CODE_OAUTH_HOST", "KIMI_OAUTH_HOST", "KIMI_AUTH_TOKEN", "kimi_auth_token"} {
		if os.Getenv(name) != "" {
			return fail("unavailable", "This Kimi Code selected login/endpoint is not supported yet", "unsupported_login")
		}
	}
	path := filepath.Join(r.Profile.Root, "credentials", "kimi-code.json")
	before, _ := os.Lstat(path)
	b, status := readBounded(path, 64<<10)
	var credential struct {
		Access string          `json:"access_token"`
		Expiry json.RawMessage `json:"expires_at"`
	}
	if status != "" {
		return fail("unavailable", "No supported Kimi Code saved login", fileErrorCode(status))
	}
	if json.Unmarshal(b, &credential) != nil {
		return fail("unavailable", "No supported Kimi Code saved login", "parse_error")
	}
	credentialKey := readerHash(r.Paths.Cache, "kimi-login:credential", credential.Access)
	changed = meta.CredentialKey != "" && (credentialKey == "" || meta.CredentialKey != credentialKey)
	if credential.Access == "" || len(credential.Access) > 16<<10 || strings.ContainsAny(credential.Access, " \t\r\n") {
		return fail("unavailable", "No supported Kimi Code saved login", "unsupported_login")
	}
	expires := kimiNumber(credential.Expiry, false)
	if expires == nil || *expires <= float64(r.Now.Add(time.Minute).Unix()) {
		out := fail("expired", "Open Kimi Code to refresh")
		out.Entry.NextStep = out.Entry.Notice
		return out
	}
	subject := ""
	if parts := strings.Split(credential.Access, "."); len(parts) == 3 {
		payload, err := base64.RawURLEncoding.DecodeString(parts[1])
		if err != nil {
			return fail("unavailable", "Unsupported Kimi Code saved token", "unsupported_login")
		}
		var claims struct {
			Subject string `json:"sub"`
			Expiry  int64  `json:"exp"`
		}
		if json.Unmarshal(payload, &claims) != nil {
			return fail("unavailable", "Unsupported Kimi Code saved token", "unsupported_login")
		}
		if claims.Expiry > 0 && claims.Expiry <= r.Now.Add(time.Minute).Unix() {
			return fail("expired", "Open Kimi Code to refresh")
		}
		if kimiLoginID.MatchString(claims.Subject) {
			subject = claims.Subject
		}
	}
	deviceBytes, deviceStatus := readBounded(filepath.Join(r.Profile.Root, "device_id"), 1024)
	device := strings.TrimSpace(string(deviceBytes))
	if deviceStatus != "" {
		return fail("unavailable", "Kimi Code device identity unavailable", fileErrorCode(deviceStatus))
	}
	if !kimiLoginID.MatchString(device) {
		return fail("unavailable", "Kimi Code device identity is missing or unsupported; open Kimi Code")
	}
	if credentialKey == "" {
		return fail("unavailable", "Identity key unavailable")
	}
	var raw json.RawMessage
	state, retry, code := kimiLoginGet(ctx, c, credential.Access, device, &raw, r.Now)
	if state != "" {
		out := fail(state, "Kimi Code usage temporarily unavailable")
		if state == "expired" || state == "denied" {
			out.Entry.NextStep = "Open Kimi Code to refresh"
		}
		out.Invalidate = changed
		out.Entry.ErrorCode = code
		out.RetryAfter = retry
		return out
	}
	parsed := parseKimi(raw, r.Now)
	usable := false
	for _, w := range parsed.Windows {
		if w.UsedPercent != nil {
			usable = true
		}
	}
	if parsed.Status != "ok" || !usable {
		return readerOutcome{Entry: readerEntry{Status: "unsupported_schema", ErrorCode: "schema_changed", Notice: "This Kimi Code quota format is not supported yet"}, Invalidate: changed}
	}
	after, err := os.Lstat(path)
	if before == nil || err != nil || !after.Mode().IsRegular() || !os.SameFile(before, after) || before.Size() != after.Size() || !before.ModTime().Equal(after.ModTime()) {
		return readerOutcome{Entry: readerEntry{Status: "unavailable", Notice: "Kimi Code sign-in changed during the read"}, Invalidate: true}
	}
	a := &Account{Source: "native:kimi", Via: "native", Plan: "Kimi Code (China)", ObservedAt: r.Now.UTC(), Windows: parsed.Windows}
	meta = readerMetadata{CredentialKey: credentialKey, VerifiedAt: r.Now.UTC(), Plan: a.Plan}
	if subject != "" {
		meta.AccountKey = readerHash(r.Paths.Cache, "kimi-login:account-cn", subject)
		if !IdentityOff() {
			if ref := assignSubscription(r.Paths.Cache, "kimi-code-login:china", subject, r.Now); ref != "" {
				a.Subscription = &Binding{Ref: ref, Status: "verified", Basis: "kimi-code-login:china", ObservedAt: r.Now.UTC()}
			}
		}
	}
	// Device ID is transport metadata, never proof of an account or subscription.
	return readerOutcome{Entry: readerEntry{Status: "ok", Account: a, Metadata: meta}}
}

func kimiLoginGet(ctx context.Context, c *http.Client, token, device string, out any, now time.Time) (string, time.Time, string) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, kimiLoginHost+"/coding/v1/usages", nil)
	if err != nil {
		return "unavailable", time.Time{}, "other"
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "modelplan")
	req.Header.Set("X-Msh-Platform", "kimi_code_cli")
	req.Header.Set("X-Msh-Version", "modelplan-native-beta")
	req.Header.Set("X-Msh-Device-Id", device)
	req.Header.Set("X-Msh-Device-Name", "ModelPlan usage reader")
	req.Header.Set("X-Msh-Device-Model", runtime.GOOS+"/"+runtime.GOARCH)
	req.Header.Set("X-Msh-Os-Version", runtime.GOOS)
	client := *c
	client.Jar = nil
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	resp, err := client.Do(req)
	if err != nil {
		return "unavailable", time.Time{}, transportErrorCode(err)
	}
	defer resp.Body.Close()
	retry := time.Time{}
	if resp.StatusCode == 429 || resp.StatusCode == 503 {
		if seconds, err := strconv.Atoi(resp.Header.Get("Retry-After")); err == nil && seconds > 0 && seconds <= 86400 {
			retry = now.Add(time.Duration(seconds) * time.Second)
		} else if at, err := http.ParseTime(resp.Header.Get("Retry-After")); err == nil && at.After(now) {
			retry = at
		}
	}
	switch resp.StatusCode {
	case 200:
	case 401:
		return "expired", retry, "http_401"
	case 403:
		return "denied", retry, "http_403"
	case 429:
		return "rate-limited", retry, "http_429"
	default:
		return "unavailable", retry, httpErrorCode(resp.StatusCode)
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
	if err != nil {
		return "unavailable", retry, transportErrorCode(err)
	}
	if len(b) > nativeMaxBody {
		return "unsupported_schema", retry, "schema_changed"
	}
	if err := json.Unmarshal(b, out); err != nil {
		return "unsupported_schema", retry, jsonErrorCode(err)
	}
	return "", retry, ""
}

func kimiNumber(b json.RawMessage, integer bool) *float64 {
	s := strings.TrimSpace(string(b))
	if len(s) > 40 || len(s) == 0 {
		return nil
	}
	if s[0] == '"' {
		if json.Unmarshal(b, &s) != nil {
			return nil
		}
	}
	n, err := strconv.ParseFloat(s, 64)
	if err != nil || math.IsNaN(n) || math.IsInf(n, 0) || n < 0 || n > 1e15 || (integer && math.Trunc(n) != n) {
		return nil
	}
	return &n
}

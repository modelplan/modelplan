package quota

// Independent protocol implementation from xai-org/grok-build 2bdd1d6a6369de0e8c68132ea4539e9abd9e14a8
// (Apache-2.0): login/{model,config,storage}, shell/extensions/billing and http.
// Never import its AuthManager: even its read paths can refresh/chmod credentials.

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"io"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/pelletier/go-toml/v2"
)

var grokReader = &nativeReader{Name: "Grok Build", Regions: []string{"oauth"}, Profiles: grokProfiles, Managed: collectGrok}
var grokHost = "https://cli-chat-proxy.grok.com"

const grokDefaultClient = "b1a00492-073a-47ea-816f-4c329264a828"

var grokID = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._-]{0,199}$`)

func grokProfiles() []ReaderProfile {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil
	}
	root := filepath.Join(home, ".grok")
	if override := os.Getenv("GROK_HOME"); override != "" {
		if !filepath.IsAbs(override) {
			return nil
		}
		root = override
	}
	file := filepath.Join(root, "auth.json")
	if override := os.Getenv("GROK_AUTH_PATH"); override != "" {
		if !filepath.IsAbs(override) {
			return nil
		}
		file = override
	}
	return []ReaderProfile{{Root: root, AccountFile: file}}
}

type grokAuth struct {
	Key           string `json:"key"`
	Mode          string `json:"auth_mode"`
	User          string `json:"user_id"`
	Expires       string `json:"expires_at"`
	Issuer        string `json:"oidc_issuer"`
	Client        string `json:"oidc_client_id"`
	PrincipalType string `json:"principal_type"`
	Principal     string `json:"principal_id"`
	Team          string `json:"team_id"`
}

// Pointer fields preserve omitted versus explicitly empty provider values.
// Provider tables merge only over a base of the same type, as in the pinned
// first-party GrokComConfigSection; an OIDC table cannot inherit OAuth2 defaults.
type grokProviderConfig struct {
	Issuer        *string `toml:"issuer"`
	Client        *string `toml:"client_id"`
	Principal     string  `toml:"principal_id"`
	PrincipalType string  `toml:"principal_type"`
}
type grokLoginConfig struct {
	Preferred  *string             `toml:"preferred_method"`
	External   *string             `toml:"auth_provider_command"`
	ForcedTeam any                 `toml:"force_login_team_uuid"`
	OIDC       *grokProviderConfig `toml:"oidc"`
	OAuth2     *grokProviderConfig `toml:"oauth2"`
}
type grokLocalConfig struct {
	Auth   grokLoginConfig `toml:"auth"`
	Login  grokLoginConfig `toml:"grok_com_config"`
	Models map[string]struct {
		Key string `toml:"api_key"`
		Env string `toml:"env_key"`
	} `toml:"model"`
	Endpoints struct {
		Deployment string `toml:"deployment_key"`
	} `toml:"endpoints"`
}

func grokMergeProvider(table, base *grokProviderConfig) (*grokProviderConfig, bool) {
	if table == nil {
		return base, true
	}
	merged := *table
	if base != nil {
		if merged.Issuer == nil {
			merged.Issuer = base.Issuer
		}
		if merged.Client == nil {
			merged.Client = base.Client
		}
	}
	return &merged, merged.Issuer != nil && merged.Client != nil
}

// Return the selected first-party scope, or fail before credential/HTTP I/O.
// A complex per-model credential catalogue is deliberately not guessed as OAuth.
func grokAuthScope(root string) (string, bool) {
	scope, ok, _ := grokAuthScopeCode(root)
	return scope, ok
}
func grokAuthScopeCode(root string) (string, bool, string) {
	for _, name := range []string{"GROK_AUTH", "GROK_AUTH_PROVIDER_COMMAND", "GROK_DEPLOYMENT_KEY", "GROK_LOCAL_AUTH"} {
		if v := os.Getenv(name); v != "" && v != "0" && v != "false" {
			return "", false, "unsupported_login"
		}
	}
	var cfg grokLocalConfig
	b, status := readBounded(filepath.Join(root, "config.toml"), 256<<10)
	if status != "missing" {
		if status != "" {
			return "", false, fileErrorCode(status)
		}
		if toml.Unmarshal(b, &cfg) != nil {
			return "", false, "parse_error"
		}
	}
	// [auth] is a top-level alias. An explicit grok_com_config key wins;
	// provider tables are not deep-merged between the alias and explicit section.
	login := cfg.Login
	if login.Preferred == nil {
		login.Preferred = cfg.Auth.Preferred
	}
	if login.External == nil {
		login.External = cfg.Auth.External
	}
	if login.ForcedTeam == nil {
		login.ForcedTeam = cfg.Auth.ForcedTeam
	}
	if login.OIDC == nil {
		login.OIDC = cfg.Auth.OIDC
	}
	if login.OAuth2 == nil {
		login.OAuth2 = cfg.Auth.OAuth2
	}
	if login.Preferred != nil && *login.Preferred != "oidc" {
		return "", false, "unsupported_login"
	}
	if (login.External != nil && *login.External != "") || cfg.Endpoints.Deployment != "" || login.ForcedTeam != nil {
		return "", false, "unsupported_login"
	}
	if login.OAuth2 != nil && (login.OAuth2.Principal != "" || login.OAuth2.PrincipalType != "") {
		return "", false, "unsupported_login"
	}
	for _, model := range cfg.Models {
		if model.Key != "" || model.Env != "" {
			return "", false, "unsupported_login"
		}
	}
	oidcIssuer, oidcClient := os.Getenv("GROK_OIDC_ISSUER"), os.Getenv("GROK_OIDC_CLIENT_ID")
	oauthIssuer, oauthClient := os.Getenv("GROK_OAUTH2_ISSUER"), os.Getenv("GROK_OAUTH2_CLIENT_ID")
	// A partially named environment provider is ambiguous and unsupported here.
	if (oidcIssuer == "") != (oidcClient == "") || (oauthIssuer == "") != (oauthClient == "") {
		return "", false, "unsupported_login"
	}
	var oidc, oauth2 *grokProviderConfig
	if oidcIssuer != "" {
		oidc = &grokProviderConfig{Issuer: &oidcIssuer, Client: &oidcClient}
	} else {
		if oauthIssuer == "" {
			oauthIssuer, oauthClient = "https://auth.x.ai", grokDefaultClient
		}
		oauth2 = &grokProviderConfig{Issuer: &oauthIssuer, Client: &oauthClient}
	}
	var valid bool
	oidc, valid = grokMergeProvider(login.OIDC, oidc)
	if !valid {
		return "", false, "unsupported_login"
	}
	oauth2, valid = grokMergeProvider(login.OAuth2, oauth2)
	if !valid {
		return "", false, "unsupported_login"
	}
	selected := oidc
	if selected == nil {
		selected = oauth2
	}
	if selected == nil || selected.Issuer == nil || selected.Client == nil {
		return "", false, "unsupported_login"
	}
	issuer, client := *selected.Issuer, *selected.Client
	if strings.TrimRight(issuer, "/") != "https://auth.x.ai" || !grokID.MatchString(client) {
		return "", false, "unsupported_login"
	}
	return "https://auth.x.ai::" + client, true, ""
}

func grokExpiry(auth grokAuth, now time.Time) bool {
	expiry := stamp(auth.Expires)
	if auth.Expires != "" && expiry == nil {
		return false
	}
	parts := strings.Split(auth.Key, ".")
	if len(parts) == 3 {
		b, err := base64.RawURLEncoding.DecodeString(parts[1])
		if err != nil {
			return false
		}
		var claims struct {
			Expires int64  `json:"exp"`
			Issuer  string `json:"iss"`
		}
		if json.Unmarshal(b, &claims) != nil {
			return false
		}
		if claims.Issuer != "" && strings.TrimRight(claims.Issuer, "/") != "https://auth.x.ai" {
			return false
		}
		if claims.Expires > 0 {
			at := time.Unix(claims.Expires, 0).UTC()
			if expiry == nil || at.Before(*expiry) {
				expiry = &at
			}
		}
	}
	return expiry != nil && expiry.After(now.Add(time.Minute))
}

func collectGrok(ctx context.Context, c *http.Client, r readerContext) readerOutcome {
	c = accountReadClient(consent.ScopeGrokAccountUsageSavedLogin, c)
	meta := r.Previous.Metadata
	changed := meta.CredentialKey != "" || meta.AccountKey != ""
	fail := func(state, notice string, codes ...string) readerOutcome {
		return readerOutcome{Entry: readerEntry{Status: state, Notice: notice, ErrorCode: failureCode(state, codes)}, Invalidate: changed}
	}
	scope, ok, scopeCode := grokAuthScopeCode(r.Profile.Root)
	if !ok {
		return fail("unavailable", "This Grok Build auth configuration is not supported yet", scopeCode)
	}
	path := r.Profile.AccountFile
	if path == "" {
		path = filepath.Join(r.Profile.Root, "auth.json")
	}
	if !filepath.IsAbs(path) {
		return fail("unavailable", "Unsupported Grok Build account path", "unsupported_login")
	}
	before, _ := os.Lstat(path)
	b, status := readBounded(path, 256<<10)
	var store map[string]grokAuth
	if status != "" {
		return fail("unavailable", "No supported Grok Build saved session", fileErrorCode(status))
	}
	if json.Unmarshal(b, &store) != nil {
		return fail("unavailable", "No supported Grok Build saved session", "parse_error")
	}
	if len(store) > 64 {
		return fail("unavailable", "No supported Grok Build saved session", "schema_changed")
	}
	auth, found := store[scope]
	credentialKey := readerHash(r.Paths.Cache, "grok:credential", auth.Key)
	identity := auth.User + "\x00" + auth.PrincipalType + "\x00" + auth.Principal + "\x00" + auth.Team
	accountKey := readerHash(r.Paths.Cache, "grok:account", identity)
	changed = (meta.CredentialKey != "" && (credentialKey == "" || meta.CredentialKey != credentialKey)) || (meta.AccountKey != "" && (accountKey == "" || meta.AccountKey != accountKey))
	if !found || (auth.Mode != "oidc" && auth.Mode != "external") || strings.TrimRight(auth.Issuer, "/") != "https://auth.x.ai" || !grokID.MatchString(auth.User) || auth.Key == "" || len(auth.Key) > 16<<10 || strings.ContainsAny(auth.Key, " \t\r\n") {
		return fail("unavailable", "This Grok Build login type is not supported yet", "unsupported_login")
	}
	if auth.Client != "" && scope != "https://auth.x.ai::"+auth.Client {
		return fail("unavailable", "Grok Build login scope mismatch", "unsupported_login")
	}
	if forced := os.Getenv("GROK_FORCE_LOGIN_TEAM_ID"); forced != "" && forced != auth.Team {
		return fail("unavailable", "Grok Build selected team mismatch", "unsupported_login")
	}
	if value := os.Getenv("GROK_OAUTH2_PRINCIPAL_ID"); value != "" && value != auth.Principal {
		return fail("unavailable", "Grok Build selected principal mismatch", "unsupported_login")
	}
	if value := os.Getenv("GROK_OAUTH2_PRINCIPAL_TYPE"); value != "" && value != auth.PrincipalType {
		return fail("unavailable", "Grok Build selected principal mismatch", "unsupported_login")
	}
	if !grokExpiry(auth, r.Now) {
		out := fail("expired", "Open Grok Build to refresh")
		out.Entry.NextStep = out.Entry.Notice
		return out
	}
	if credentialKey == "" || accountKey == "" {
		return fail("unavailable", "Identity key unavailable")
	}
	var billing grokBilling
	state, retry, code := grokBillingGet(ctx, c, auth, &billing, r.Now)
	if state != "" {
		out := fail(state, "Grok Build usage temporarily unavailable")
		if state == "expired" || state == "denied" {
			out.Entry.NextStep = "Open Grok Build to refresh"
		}
		out.Invalidate = changed
		out.Entry.ErrorCode = code
		out.RetryAfter = retry
		return out
	}
	a, ok := parseGrokBilling(billing, r.Now)
	if !ok {
		return readerOutcome{Entry: readerEntry{Status: "unsupported_schema", ErrorCode: "schema_changed", Notice: "This Grok Build billing format is not supported yet"}, Invalidate: changed}
	}
	after, statErr := os.Lstat(path)
	if before == nil || statErr != nil || !after.Mode().IsRegular() || !os.SameFile(before, after) || before.Size() != after.Size() || !before.ModTime().Equal(after.ModTime()) {
		return readerOutcome{Entry: readerEntry{Status: "unavailable", Notice: "Grok Build sign-in changed during the read"}, Invalidate: true}
	}
	if !IdentityOff() {
		if ref := assignSubscription(r.Paths.Cache, "grok-auth-principal", identity, r.Now); ref != "" {
			a.Subscription = &Binding{Ref: ref, Status: "verified", Basis: "grok-auth-principal", ObservedAt: r.Now.UTC()}
		}
	}
	notice := ""
	if a.SharedPool != nil {
		notice = "Shared-pool link unverified"
	}
	return readerOutcome{Entry: readerEntry{Status: "ok", Account: a, Notice: notice, Metadata: readerMetadata{CredentialKey: credentialKey, AccountKey: accountKey, VerifiedAt: r.Now.UTC(), Plan: a.Plan}}}
}

type grokCent struct {
	Val json.RawMessage `json:"val"`
}

func grokUSD(c *grokCent) (*float64, bool) {
	if c == nil {
		return nil, true
	}
	value := int64(0)
	if len(c.Val) > 0 {
		if string(c.Val) == "null" {
			return nil, false
		}
		var n json.Number
		if json.Unmarshal(c.Val, &n) != nil {
			return nil, false
		}
		v, err := strconv.ParseInt(string(n), 10, 64)
		if err != nil || v < 0 || v > 1e14 {
			return nil, false
		}
		value = v
	}
	n := float64(value) / 100
	return &n, true
}

type grokBilling struct {
	Config *struct {
		Percent *float64 `json:"creditUsagePercent"`
		Period  *struct {
			Type  string `json:"type"`
			Start string `json:"start"`
			End   string `json:"end"`
		} `json:"currentPeriod"`
		Limit      *grokCent `json:"monthlyLimit"`
		Used       *grokCent `json:"used"`
		DemandCap  *grokCent `json:"onDemandCap"`
		DemandUsed *grokCent `json:"onDemandUsed"`
		Prepaid    *grokCent `json:"prepaidBalance"`
		Unified    *bool     `json:"isUnifiedBillingUser"`
		LegacyEnd  string    `json:"billingPeriodEnd"`
	} `json:"config"`
}

func parseGrokBilling(b grokBilling, now time.Time) (*Account, bool) {
	cfg := b.Config
	if cfg == nil {
		return nil, false
	}
	a := &Account{Source: "native:grok", Via: "native", Plan: "Grok Build", ObservedAt: now.UTC(), Windows: []Window{}}
	if cfg.Unified != nil && *cfg.Unified {
		a.SharedPool = unverifiedXSubscription()
		a.Plan = "The X Subscription"
	}
	var reset *time.Time
	kind, label, minutes := "unknown", "Included (other period)", 0
	if cfg.Period != nil {
		if cfg.Period.End != "" {
			reset = stamp(cfg.Period.End)
			if reset == nil {
				return nil, false
			}
		}
		if cfg.Period.Start != "" {
			start := stamp(cfg.Period.Start)
			if start == nil || (reset != nil && !reset.After(*start)) {
				return nil, false
			}
		}
		switch cfg.Period.Type {
		case "USAGE_PERIOD_TYPE_WEEKLY":
			kind, label, minutes = "weekly", "Included", 10080
		case "USAGE_PERIOD_TYPE_MONTHLY":
			kind, label, minutes = "monthly", "Included", 43200
		case "USAGE_PERIOD_TYPE_DAILY":
			label, minutes = "Included daily", 1440
		}
	}
	if cfg.Percent != nil {
		if math.IsNaN(*cfg.Percent) || math.IsInf(*cfg.Percent, 0) || *cfg.Percent < 0 || *cfg.Percent > 100 {
			return nil, false
		}
		if reset == nil || reset.After(now) {
			a.Windows = append(a.Windows, Window{Kind: kind, Limit: label, UsedPercent: cfg.Percent, ResetsAt: reset, WindowMinutes: minutes, ResetMode: "fixed", ObservedAt: now.UTC()})
		}
	} else if cfg.Limit != nil || cfg.Used != nil {
		// Legacy monthly cents are never relabelled as a unified included pool.
		if cfg.Unified != nil && *cfg.Unified {
			return nil, false
		}
		used, ok := grokUSD(cfg.Used)
		if !ok {
			return nil, false
		}
		limit, ok := grokUSD(cfg.Limit)
		if !ok {
			return nil, false
		}
		legacyReset := stamp(cfg.LegacyEnd)
		if cfg.LegacyEnd != "" && legacyReset == nil {
			return nil, false
		}
		w := Window{Kind: "monthly", Limit: "Legacy included", WindowMinutes: 43200, UsedUSD: used, LimitUSD: limit, ResetsAt: legacyReset, ObservedAt: now.UTC(), ResetMode: "fixed"}
		if used != nil && limit != nil && *limit > 0 {
			pct := 100 * *used / *limit
			w.UsedPercent = &pct
		}
		if legacyReset == nil || legacyReset.After(now) {
			a.Windows = append(a.Windows, w)
		}
	}
	if cfg.Prepaid != nil {
		balance, ok := grokUSD(cfg.Prepaid)
		if !ok {
			return nil, false
		}
		a.Credits = &Credits{Balance: balance, Currency: "USD", Unit: "money", ObservedAt: now.UTC()}
	}
	if cfg.DemandUsed != nil || cfg.DemandCap != nil {
		used, ok := grokUSD(cfg.DemandUsed)
		if !ok {
			return nil, false
		}
		cap, ok := grokUSD(cfg.DemandCap)
		if !ok {
			return nil, false
		}
		w := Window{Kind: "spend", Limit: "Additional usage", UsedUSD: used, LimitUSD: cap, ObservedAt: now.UTC(), ResetMode: "unknown"}
		if used != nil && cap != nil && *cap > 0 {
			pct := 100 * *used / *cap
			w.UsedPercent = &pct
		}
		a.Windows = append(a.Windows, w)
	}
	// A valid reset-past capture may retain a separately observed wallet. No
	// period is rolled over and missing wallets are never interpreted as zero.
	return a, len(a.Windows) > 0 || a.Credits != nil || (cfg.Percent != nil && reset != nil)
}

func grokBillingGet(ctx context.Context, c *http.Client, auth grokAuth, out any, now time.Time) (string, time.Time, string) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, grokHost+"/v1/billing?format=credits", nil)
	if err != nil {
		return "unavailable", time.Time{}, "other"
	}
	req.Header.Set("Authorization", "Bearer "+auth.Key)
	req.Header.Set("X-XAI-Token-Auth", "xai-grok-cli")
	req.Header.Set("x-userid", auth.User)
	req.Header.Set("x-grok-client-version", "0.0.0-modelplan-native-beta")
	req.Header.Set("x-grok-client-mode", "headless")
	req.Header.Set("User-Agent", "modelplan")
	req.Header.Set("Accept", "application/json")
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

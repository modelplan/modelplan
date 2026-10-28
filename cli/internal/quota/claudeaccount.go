package quota

// Claude's undocumented OAuth usage/profile contract is beta. Protocol evidence:
// CodexBar 0.81.0 (MIT), ClaudeOAuthUsageFetcher.swift and ClaudeAccountProfile.swift,
// commit ee890b5f392e70d6e20162d3e95cf9f1be265b60. Independently implemented; no
// delegated refresh, auth helper, browser session or inference request is used.

import (
	"context"
	"encoding/json"
	"io"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/keychain"
)

var claudeAccountReader = &nativeReader{
	Name: "Claude Code", Regions: []string{"oauth"},
	Profiles: claudeProfiles, Managed: collectClaudeAccount,
}

// Compiled endpoint; never selected by settings, detection or publication data.
var claudeOAuthHost = "https://api.anthropic.com"
var claudeSecurity keychain.Execute // tests inject a process; nil uses /usr/bin/security
var claudeID = regexp.MustCompile(`^[A-Za-z0-9-]{1,128}$`)

func claudeProfiles() []ReaderProfile {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil
	}
	root := filepath.Join(home, ".claude")
	if dir := os.Getenv("CLAUDE_CONFIG_DIR"); dir != "" {
		if !filepath.IsAbs(dir) {
			return nil
		}
		root = dir
	}
	return []ReaderProfile{{Root: root, AccountFile: ClaudeConfigFile(home)}}
}

type claudeCredential struct {
	OAuth *struct {
		AccessToken      string   `json:"accessToken"`
		ExpiresAt        int64    `json:"expiresAt"`
		Scopes           []string `json:"scopes"`
		SubscriptionType string   `json:"subscriptionType"`
	} `json:"claudeAiOauth"`
}

func claudeFailure(state, notice string) readerOutcome {
	return readerOutcome{Entry: readerEntry{Status: state, Notice: notice}}
}

// Refuse API keys, alternate hosts, cloud logins and auth helpers locally. The
// second lane owns GLM-from-config; this reader must never send its key to Claude.
func claudeLoginUnsupported(root string) bool {
	env := map[string]string{}
	b, status := readBounded(filepath.Join(root, "settings.json"), 256<<10)
	if status != "missing" {
		var settings struct {
			Env          map[string]string `json:"env"`
			APIKeyHelper json.RawMessage   `json:"apiKeyHelper"`
		}
		if status != "" || json.Unmarshal(b, &settings) != nil {
			return true
		}
		if len(settings.APIKeyHelper) > 0 && string(settings.APIKeyHelper) != "null" {
			return true
		}
		env = settings.Env
	}
	for _, name := range []string{"ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"} {
		if v := os.Getenv(name); v != "" && v != "0" && v != "false" {
			return true
		}
		if v := env[name]; v != "" && v != "0" && v != "false" {
			return true
		}
	}
	for _, base := range []string{os.Getenv("ANTHROPIC_BASE_URL"), env["ANTHROPIC_BASE_URL"]} {
		if base != "" && strings.TrimRight(base, "/") != claudeOAuthHost {
			return true
		}
	}
	return false
}

func collectClaudeAccount(ctx context.Context, c *http.Client, r readerContext) readerOutcome {
	meta := r.Previous.Metadata
	changed := meta.CredentialKey != ""
	fail := func(state, notice string) readerOutcome {
		out := claudeFailure(state, notice)
		out.Invalidate = changed
		return out
	}
	if claudeLoginUnsupported(r.Profile.Root) {
		return fail("unavailable", "This Claude Code login type is not supported yet")
	}
	b, status := readBounded(filepath.Join(r.Profile.Root, ".credentials.json"), 64<<10)
	if status == "missing" {
		profiles := claudeProfiles()
		if len(profiles) != 1 || profiles[0].Root != r.Profile.Root || os.Getenv("CLAUDE_CONFIG_DIR") != "" {
			return fail("unavailable", "No supported Claude Code saved login")
		}
		if runtime.GOOS == "darwin" && !r.Grant.Keychain && r.Grant.KeychainConsent == "unset" {
			out := fail("consent_required", consent.ClaudeKeychainUnsetNotice)
			out.Entry.NextStep = consent.ClaudeKeychainNextStep
			return out
		}
		if !r.Grant.Keychain {
			return fail("unavailable", "No supported Claude Code saved login")
		}
		k := (keychain.Reader{Cache: r.Paths.Cache, Execute: claudeSecurity}).ClaudeCredentials(ctx, keychain.Policy{
			Allowed: true, PriorGrant: r.Grant.KeychainPriorGrant, Interactive: r.Grant.Interactive, ProfileRef: r.ProfileKey,
		})
		if k.State != "ok" {
			return readerOutcome{Entry: readerEntry{Status: k.State, NextStep: k.NextStep}}
		}
		b, status = k.Value, ""
	}
	if status != "" {
		return fail("unavailable", "Claude Code saved login is unreadable")
	}
	var credential claudeCredential
	if json.Unmarshal(b, &credential) != nil || credential.OAuth == nil {
		return fail("unavailable", "This Claude Code login type is not supported yet")
	}
	oauth := credential.OAuth
	credentialKey := readerHash(r.Paths.Cache, "claude:credential", oauth.AccessToken)
	changed = meta.CredentialKey != "" && (credentialKey == "" || meta.CredentialKey != credentialKey)
	if oauth.AccessToken == "" || len(oauth.AccessToken) > 16<<10 || strings.ContainsAny(oauth.AccessToken, "\r\n") || oauth.ExpiresAt <= r.Now.UnixMilli() {
		return fail("expired", "Open Claude Code to refresh")
	}
	if !contains(oauth.Scopes, "user:profile") {
		return fail("unavailable", "This Claude Code login scope is not supported yet")
	}
	if credentialKey == "" {
		return fail("unavailable", "Identity key unavailable")
	}
	cold := meta.CredentialKey != credentialKey || meta.AccountKey == "" || meta.VerifiedAt.After(r.Now) || r.Now.Sub(meta.VerifiedAt) >= 24*time.Hour
	var binding *Binding
	if cold {
		var profile claudeOAuthProfile
		state, retry := claudeGet(ctx, c, "/api/oauth/profile", oauth.AccessToken, &profile, r.Now)
		if state != "" {
			out := claudeFailure(state, claudeNextStep(state))
			out.Invalidate = changed
			out.RetryAfter = retry
			return out
		}
		account, org := profile.ids()
		if !claudeID.MatchString(account) || (org != "" && !claudeID.MatchString(org)) {
			out := claudeFailure("unsupported_schema", "Claude profile identity is not supported yet")
			out.Invalidate = changed
			return out
		}
		meta = readerMetadata{CredentialKey: credentialKey, AccountKey: readerHash(r.Paths.Cache, "claude:account", account), OrganizationKey: readerHash(r.Paths.Cache, "claude:organization", org), VerifiedAt: r.Now.UTC(), Plan: claudePlan(oauth.SubscriptionType)}
		if !IdentityOff() {
			ref := assignSubscription(r.Paths.Cache, "claude-oauth", account+"\x00"+org, r.Now)
			if ref != "" {
				binding = &Binding{Ref: ref, Status: "verified", Basis: "claude-oauth", ObservedAt: r.Now.UTC()}
			}
		}
	} else {
		if !IdentityOff() && r.Previous.Account != nil {
			binding = r.Previous.Account.Subscription
		}
	}
	var usage map[string]json.RawMessage
	state, retry := claudeGet(ctx, c, "/api/oauth/usage", oauth.AccessToken, &usage, r.Now)
	if state != "" {
		out := claudeFailure(state, claudeNextStep(state))
		out.Invalidate = changed
		out.RetryAfter = retry
		return out
	}
	windows, ok := parseClaudeUsage(usage, r.Now)
	if !ok {
		out := claudeFailure("unsupported_schema", "Claude usage is not supported yet")
		out.Invalidate = changed
		return out
	}
	a := &Account{Source: "claude-code", Plan: meta.Plan, Via: "native", ObservedAt: r.Now.UTC(), Windows: windows, Subscription: binding}
	entry := readerEntry{Status: "ok", Account: a, Metadata: meta}
	if len(windows) == 0 {
		entry.Notice = "This plan does not publish quota windows"
	}
	return readerOutcome{Entry: entry, RetryAfter: retry}
}

type claudeOAuthProfile struct {
	Account struct {
		UUID string `json:"uuid"`
	} `json:"account"`
	Organization struct {
		UUID string `json:"uuid"`
	} `json:"organization"`
	AccountUUID      string `json:"account_uuid"`
	OrganizationUUID string `json:"organization_uuid"`
}

func (p claudeOAuthProfile) ids() (string, string) {
	a, o := p.Account.UUID, p.Organization.UUID
	if a == "" {
		a = p.AccountUUID
	}
	if o == "" {
		o = p.OrganizationUUID
	}
	return a, o
}

func claudePlan(s string) string {
	switch strings.ToLower(s) {
	case "pro":
		return "Pro"
	case "max":
		return "Max"
	case "team":
		return "Team"
	case "enterprise":
		return "Enterprise"
	case "free":
		return "Free"
	}
	return ""
}

func claudeNextStep(state string) string {
	if state == "expired" || state == "denied" {
		return "Open Claude Code to refresh"
	}
	return "Claude usage temporarily unavailable"
}

func claudeGet(ctx context.Context, c *http.Client, path, token string, v any, now time.Time) (string, time.Time) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, claudeOAuthHost+path, nil)
	if err != nil {
		return "unavailable", time.Time{}
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Accept", "application/json")
	req.Header.Set("anthropic-beta", "oauth-2025-04-20")
	req.Header.Set("User-Agent", "modelplan")
	client := *c
	client.Jar = nil
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	resp, err := client.Do(req)
	if err != nil {
		return "unavailable", time.Time{}
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
		return "expired", retry
	case 403:
		return "denied", retry
	case 404:
		return "not-supported", retry
	case 429:
		return "rate-limited", retry
	default:
		return "unavailable", retry
	}
	b, err := io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
	if err != nil || len(b) > nativeMaxBody || json.Unmarshal(b, v) != nil {
		return "unsupported_schema", retry
	}
	return "", retry
}

func parseClaudeUsage(raw map[string]json.RawMessage, now time.Time) ([]Window, bool) {
	if raw == nil {
		return nil, false
	}
	types := []struct {
		key, kind, label string
		minutes          int
	}{
		{"five_hour", "five_hour", "", 300}, {"seven_day", "weekly", "", 10080},
		{"seven_day_opus", "weekly", "Opus", 10080}, {"seven_day_sonnet", "weekly", "Sonnet", 10080},
		{"seven_day_oauth_apps", "weekly", "OAuth apps", 10080}, {"seven_day_cowork", "weekly", "Cowork", 10080},
	}
	ws := []Window{}
	known := false
	for _, spec := range types {
		b, present := raw[spec.key]
		if !present {
			continue
		}
		known = true
		if string(b) == "null" {
			continue
		}
		var v struct {
			Utilization *float64 `json:"utilization"`
			ResetsAt    string   `json:"resets_at"`
		}
		if json.Unmarshal(b, &v) != nil || v.Utilization == nil || math.IsNaN(*v.Utilization) || math.IsInf(*v.Utilization, 0) || *v.Utilization < 0 {
			return nil, false
		}
		reset := stamp(v.ResetsAt)
		if v.ResetsAt != "" && reset == nil {
			return nil, false
		}
		if reset != nil && !reset.After(now) {
			continue
		}
		ws = append(ws, Window{Kind: spec.kind, Limit: spec.label, WindowMinutes: spec.minutes, UsedPercent: v.Utilization, ResetsAt: reset, ResetMode: "fixed", ObservedAt: now.UTC()})
	}
	if b, present := raw["extra_usage"]; present && string(b) != "null" {
		known = true
		var v struct {
			Enabled  bool     `json:"is_enabled"`
			Used     *float64 `json:"used_credits"`
			Limit    *float64 `json:"monthly_limit"`
			Currency string   `json:"currency"`
		}
		if json.Unmarshal(b, &v) != nil {
			return nil, false
		}
		// Usage and limit are minor USD units in this beta contract. An explicit
		// different currency is not converted or silently labelled as USD.
		if v.Enabled && (v.Currency == "" || strings.EqualFold(v.Currency, "usd")) && v.Used != nil && v.Limit != nil && *v.Used >= 0 && *v.Limit > 0 {
			used, limit := *v.Used/100, *v.Limit/100
			pct := 100 * used / limit
			ws = append(ws, Window{Kind: "spend", Limit: "Extra usage", WindowMinutes: 43200, UsedUSD: &used, LimitUSD: &limit, UsedPercent: &pct, ObservedAt: now.UTC(), ResetMode: "unknown"})
		}
	}
	return ws, known
}

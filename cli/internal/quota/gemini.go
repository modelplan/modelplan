package quota

// Independent read-only Code Assist reader. Protocol evidence: google-gemini/
// gemini-cli 363a13119a57354f469732577518b9d6b319d1d6, code_assist types/server/
// setup and utils/paths (Apache-2.0); CodexBar 0.81.0 GeminiStatusProbe.swift
// (MIT). No source is vendored. No OAuth refresh, client-secret extraction,
// project enumeration, onboarding, provider CLI launch or inference is performed.

import (
	"bytes"
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
	"sync"
	"time"
)

var geminiReader = &nativeReader{Name: "Gemini CLI", Regions: []string{"oauth"}, Profiles: geminiProfiles, Managed: collectGemini}
var geminiHost = "https://cloudcode-pa.googleapis.com"
var geminiIdentifier = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$`)
var geminiProjectID = regexp.MustCompile(`^[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,199}$`)

func geminiProfiles() []ReaderProfile {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil
	}
	if override := os.Getenv("GEMINI_CLI_HOME"); override != "" {
		if !filepath.IsAbs(override) {
			return nil
		}
		home = override
	}
	return []ReaderProfile{{Root: filepath.Join(home, ".gemini")}}
}

type geminiCredential struct {
	AccessToken string `json:"access_token"`
	Expiry      int64  `json:"expiry_date"`
	IDToken     string `json:"id_token"`
}

// Project selectors remain transient. Persist only their HMAC and stable tier.
// Configured tool-owned project selectors can also recover a warm read across
// processes; otherwise discovery costs one of the same read's two slots.
var geminiProjects = struct {
	sync.Mutex
	values map[string]geminiProject
}{values: map[string]geminiProject{}}

type geminiProject struct {
	ID, Plan string
	At       time.Time
}

func geminiRemember(key string, value geminiProject, now time.Time) {
	geminiProjects.Lock()
	defer geminiProjects.Unlock()
	for k, v := range geminiProjects.values {
		if now.Sub(v.At) >= 24*time.Hour || v.At.After(now) {
			delete(geminiProjects.values, k)
		}
	}
	if len(geminiProjects.values) >= 32 {
		oldest := ""
		var at time.Time
		for k, v := range geminiProjects.values {
			if oldest == "" || v.At.Before(at) {
				oldest, at = k, v.At
			}
		}
		delete(geminiProjects.values, oldest)
	}
	geminiProjects.values[key] = value
}

func geminiRecalled(key string, now time.Time) geminiProject {
	geminiProjects.Lock()
	defer geminiProjects.Unlock()
	v := geminiProjects.values[key]
	if v.At.After(now) || now.Sub(v.At) >= 24*time.Hour {
		return geminiProject{}
	}
	return v
}

func geminiUnsupported(root string) string {
	if os.Getenv("GEMINI_FORCE_ENCRYPTED_FILE_STORAGE") == "true" {
		return "unsupported_login"
	}
	for _, name := range []string{"GEMINI_API_KEY", "GOOGLE_API_KEY", "GOOGLE_GENAI_USE_VERTEXAI"} {
		if v := os.Getenv(name); v != "" && v != "0" && v != "false" {
			return "unsupported_login"
		}
	}
	if v := os.Getenv("CODE_ASSIST_ENDPOINT"); v != "" && strings.TrimRight(v, "/") != "https://cloudcode-pa.googleapis.com" {
		return "unsupported_login"
	}
	if v := os.Getenv("CODE_ASSIST_API_VERSION"); v != "" && v != "v1internal" {
		return "unsupported_login"
	}
	b, status := readBounded(filepath.Join(root, "settings.json"), 256<<10)
	if status == "missing" {
		return ""
	}
	var settings struct {
		Security struct {
			Auth struct {
				SelectedType string `json:"selectedType"`
			} `json:"auth"`
		} `json:"security"`
	}
	if status != "" {
		return fileErrorCode(status)
	}
	if json.Unmarshal(b, &settings) != nil {
		return "parse_error"
	}
	selected := settings.Security.Auth.SelectedType
	if selected != "" && selected != "oauth-personal" {
		return "unsupported_login"
	}
	return ""
}

func collectGemini(ctx context.Context, c *http.Client, r readerContext) readerOutcome {
	c = accountReadClient(consent.ScopeGeminiAccountUsageSavedLogin, c)
	meta := r.Previous.Metadata
	configured := os.Getenv("GOOGLE_CLOUD_PROJECT")
	if configured == "" {
		configured = os.Getenv("GOOGLE_CLOUD_PROJECT_ID")
	}
	configuredKey := ""
	if configured != "" && geminiProjectID.MatchString(configured) {
		configuredKey = readerHash(r.Paths.Cache, "gemini:project", configured)
	}
	// A selector switch invalidates the old scope even if token validation exits
	// early (for example the same token expires just as the project changes).
	scopeChanged := configured != "" && meta.ScopeKey != "" && (configuredKey == "" || configuredKey != meta.ScopeKey)
	// Unknown/malformed/unsupported bindings cannot retain another account's
	// numbers. Once decoded, an equal token can retain its original-age capture.
	changed := meta.CredentialKey != ""
	fail := func(state, notice string, codes ...string) readerOutcome {
		return readerOutcome{Entry: readerEntry{Status: state, Notice: notice, ErrorCode: failureCode(state, codes)}, Invalidate: changed}
	}
	if code := geminiUnsupported(r.Profile.Root); code != "" {
		return fail("unavailable", "This Gemini CLI login type is not supported yet", code)
	}
	credentialPath := filepath.Join(r.Profile.Root, "oauth_creds.json")
	before, _ := os.Lstat(credentialPath)
	b, status := readBounded(credentialPath, 64<<10)
	var credential geminiCredential
	if status != "" {
		return fail("unavailable", "Gemini CLI login unavailable", fileErrorCode(status))
	}
	if json.Unmarshal(b, &credential) != nil {
		return fail("unavailable", "Gemini CLI login invalid", "parse_error")
	}
	credentialKey := readerHash(r.Paths.Cache, "gemini:credential", credential.AccessToken)
	changed = scopeChanged || (meta.CredentialKey != "" && (credentialKey == "" || meta.CredentialKey != credentialKey))
	if credential.AccessToken == "" || len(credential.AccessToken) > 16<<10 || strings.ContainsAny(credential.AccessToken, "\r\n") || credential.Expiry <= r.Now.Add(time.Minute).UnixMilli() {
		out := fail("expired", "Open Gemini CLI to refresh")
		out.Entry.NextStep = out.Entry.Notice
		return out
	}
	if credentialKey == "" {
		return fail("unavailable", "Identity key unavailable")
	}
	projectCacheKey := readerHash(r.Paths.Cache, "gemini:transient-project", r.ProfileKey+"\x00"+credentialKey+"\x00"+r.Grant.Generation)
	if projectCacheKey == "" {
		changed = meta.CredentialKey != ""
		return fail("unavailable", "Identity key unavailable")
	}
	if configured != "" {
		if !geminiProjectID.MatchString(configured) {
			changed = changed || meta.ScopeKey != ""
			return fail("unavailable", "Unsupported configured Gemini project", "unsupported_login")
		}
		if configuredKey == "" {
			changed = meta.CredentialKey != ""
			return fail("unavailable", "Identity key unavailable")
		}
	}
	project := geminiRecalled(projectCacheKey, r.Now)
	cold := meta.CredentialKey != credentialKey || meta.ScopeKey == "" || meta.VerifiedAt.After(r.Now) || r.Now.Sub(meta.VerifiedAt) >= 24*time.Hour
	// Validate the current selector even when a transient warm project exists.
	// Discovery for a switched selector uses this same read's first of two slots.
	if configured != "" && configuredKey != meta.ScopeKey {
		cold = true
		project = geminiProject{}
	}
	if project.ID != "" && readerHash(r.Paths.Cache, "gemini:project", project.ID) != meta.ScopeKey {
		cold = true
		project = geminiProject{}
	}
	if !cold && project.ID == "" && configured != "" && configuredKey == meta.ScopeKey {
		project = geminiProject{ID: configured, Plan: meta.Plan, At: meta.VerifiedAt}
	}
	if project.ID == "" {
		cold = true
	}
	var wallet *Credits
	if !changed && r.Previous.Account != nil {
		wallet = r.Previous.Account.Credits
	}
	if cold {
		request := map[string]any{"mode": "HEALTH_CHECK", "metadata": map[string]string{"ideType": "GEMINI_CLI", "pluginType": "GEMINI"}}
		if configured != "" {
			request["cloudaicompanionProject"] = configured
		}
		var assist geminiAssist
		state, retry, code := geminiJSON(ctx, c, "loadCodeAssist", credential.AccessToken, request, &assist, r.Now)
		if state != "" {
			out := fail(state, geminiNextStep(state))
			out.Entry.ErrorCode = code
			out.RetryAfter = retry
			return out
		}
		id := assist.project()
		if id == "" {
			id = configured
		}
		scopeKey := readerHash(r.Paths.Cache, "gemini:project", id)
		changed = changed || (meta.ScopeKey != "" && scopeKey != meta.ScopeKey)
		plan := geminiTier(assist.CurrentTier.ID)
		if !geminiProjectID.MatchString(id) || scopeKey == "" || plan == "" || (configured != "" && id != configured) {
			return fail("unavailable", "Gemini project or tier is not supported yet; open Gemini CLI", "schema_changed")
		}
		project = geminiProject{ID: id, Plan: plan, At: r.Now.UTC()}
		meta = readerMetadata{CredentialKey: credentialKey, ScopeKey: scopeKey, VerifiedAt: r.Now.UTC(), Plan: plan}
		creditValues := assist.CurrentTier.Credits
		if assist.PaidTier.Credits != nil {
			creditValues = assist.PaidTier.Credits
		}
		wallet = geminiCredits(creditValues, r.Now)
	}
	var quota geminiQuota
	state, retry, code := geminiJSON(ctx, c, "retrieveUserQuota", credential.AccessToken, map[string]string{"project": project.ID}, &quota, r.Now)
	if state != "" {
		out := fail(state, geminiNextStep(state))
		out.Invalidate = changed
		out.Entry.ErrorCode = code
		out.RetryAfter = retry
		return out
	}
	windows, ok := parseGeminiQuota(quota, r.Now)
	if !ok {
		return readerOutcome{Entry: readerEntry{Status: "unsupported_schema", ErrorCode: "schema_changed", Notice: "This Gemini quota format is not supported yet"}, Invalidate: changed}
	}
	after, statErr := os.Lstat(credentialPath)
	if before == nil || statErr != nil || !after.Mode().IsRegular() || !os.SameFile(before, after) || before.Size() != after.Size() || !before.ModTime().Equal(after.ModTime()) {
		return readerOutcome{Entry: readerEntry{Status: "unavailable", Notice: "Gemini sign-in changed during the read; refresh required"}, Invalidate: true}
	}
	a := &Account{Source: "native:gemini", Via: "native", Plan: meta.Plan, ObservedAt: r.Now.UTC(), Windows: windows, Credits: wallet}
	if subject := geminiSubject(credential.IDToken, r.Now); subject != "" {
		meta.AccountKey = readerHash(r.Paths.Cache, "gemini:account", subject)
		if !IdentityOff() {
			if ref := assignSubscription(r.Paths.Cache, "gemini-cli-account-project", subject+"\x00"+project.ID, r.Now); ref != "" {
				a.Subscription = &Binding{Ref: ref, Status: "verified", Basis: "gemini-cli-local-account-project", ObservedAt: r.Now.UTC()}
			}
		}
	}
	// Publish transient metadata only with a complete consistent reading.
	geminiRemember(projectCacheKey, project, r.Now)
	return readerOutcome{Entry: readerEntry{Status: "ok", Account: a, Metadata: meta}}
}

type geminiAvailableCredit struct {
	Type   string `json:"creditType"`
	Amount string `json:"creditAmount"`
}
type geminiAssist struct {
	Project     json.RawMessage `json:"cloudaicompanionProject"`
	CurrentTier struct {
		ID      string                  `json:"id"`
		Credits []geminiAvailableCredit `json:"availableCredits"`
	} `json:"currentTier"`
	PaidTier struct {
		Credits []geminiAvailableCredit `json:"availableCredits"`
	} `json:"paidTier"`
}

func (a geminiAssist) project() string {
	var id string
	if json.Unmarshal(a.Project, &id) == nil {
		return id
	}
	var object struct {
		ID        string `json:"id"`
		ProjectID string `json:"projectId"`
	}
	if json.Unmarshal(a.Project, &object) != nil {
		return ""
	}
	if object.ID != "" {
		return object.ID
	}
	return object.ProjectID
}
func geminiTier(id string) string {
	switch id {
	case "free-tier":
		return "Gemini Code Assist Free"
	case "legacy-tier":
		return "Gemini Code Assist Legacy"
	case "standard-tier":
		return "Gemini Code Assist Standard"
	}
	return ""
}
func geminiCredits(values []geminiAvailableCredit, now time.Time) *Credits {
	var result *Credits
	for _, v := range values {
		if v.Type != "GOOGLE_ONE_AI" {
			continue
		}
		amount, err := strconv.ParseInt(v.Amount, 10, 64)
		if err != nil || amount < 0 || amount > 1e12 || result != nil {
			return nil
		}
		n := float64(amount)
		result = &Credits{Balance: &n, Unit: "credits", Scope: "google-one-ai", ObservedAt: now.UTC()}
	}
	return result
}

type geminiQuota struct {
	Buckets []struct {
		Remaining *float64 `json:"remainingFraction"`
		Amount    string   `json:"remainingAmount"`
		Reset     string   `json:"resetTime"`
		Model     string   `json:"modelId"`
		TokenType string   `json:"tokenType"`
	} `json:"buckets"`
}

func parseGeminiQuota(q geminiQuota, now time.Time) ([]Window, bool) {
	if q.Buckets == nil || len(q.Buckets) > 128 {
		return nil, false
	}
	ws := []Window{}
	for _, b := range q.Buckets {
		if !geminiIdentifier.MatchString(b.Model) {
			return nil, false
		}
		label := b.Model
		switch b.TokenType {
		case "REQUESTS":
			label += " requests"
		case "TOKENS":
			label += " tokens"
		case "INPUT_TOKENS":
			label += " input tokens"
		case "OUTPUT_TOKENS":
			label += " output tokens"
		case "":
		default:
			return nil, false
		}
		reset := stamp(b.Reset)
		if b.Reset != "" && reset == nil {
			return nil, false
		}
		if reset != nil && !reset.After(now) {
			continue
		}
		w := Window{Kind: "unknown", Limit: label, ResetsAt: reset, ResetMode: "unknown", ObservedAt: now.UTC()}
		if b.Remaining != nil {
			if math.IsNaN(*b.Remaining) || math.IsInf(*b.Remaining, 0) || *b.Remaining < 0 || *b.Remaining > 1 {
				return nil, false
			}
			used := 100 * (1 - *b.Remaining)
			w.UsedPercent = &used
		}
		if b.TokenType == "REQUESTS" && b.Amount != "" {
			amount, err := strconv.ParseInt(b.Amount, 10, 64)
			if err != nil || amount < 0 {
				return nil, false
			}
			w.Requests = &RequestUsage{Remaining: &amount}
		}
		if w.UsedPercent == nil && w.Requests == nil {
			return nil, false
		}
		ws = append(ws, w)
	}
	return ws, true
}

func geminiSubject(token string, now time.Time) string {
	parts := strings.Split(token, ".")
	if len(parts) != 3 || len(token) > 32<<10 {
		return ""
	}
	b, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return ""
	}
	var claims struct {
		Subject string `json:"sub"`
		Issuer  string `json:"iss"`
		Expiry  int64  `json:"exp"`
	}
	if json.Unmarshal(b, &claims) != nil || !geminiIdentifier.MatchString(claims.Subject) || claims.Expiry <= now.Unix() || (claims.Issuer != "accounts.google.com" && claims.Issuer != "https://accounts.google.com") {
		return ""
	}
	return claims.Subject
}

func geminiNextStep(state string) string {
	if state == "expired" || state == "denied" {
		return "Open Gemini CLI to refresh"
	}
	return "Gemini quota temporarily unavailable"
}

func geminiJSON(ctx context.Context, c *http.Client, method, token string, body, out any, now time.Time) (string, time.Time, string) {
	if method != "loadCodeAssist" && method != "retrieveUserQuota" {
		return "unavailable", time.Time{}, "other"
	}
	b, err := json.Marshal(body)
	if err != nil {
		return "unavailable", time.Time{}, "other"
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, geminiHost+"/v1internal:"+method, bytes.NewReader(b))
	if err != nil {
		return "unavailable", time.Time{}, "other"
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "modelplan")
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
	b, err = io.ReadAll(io.LimitReader(resp.Body, nativeMaxBody+1))
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

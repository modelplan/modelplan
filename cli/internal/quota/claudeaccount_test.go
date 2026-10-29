package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/keychain"
)

var claudeTestNow = time.Date(2026, 10, 27, 12, 0, 0, 0, time.UTC)

func claudeTestPaths(t *testing.T) Paths {
	t.Helper()
	isolateHome(t)
	for _, name := range []string{"MODELPLAN_READERS", "MODELPLAN_NATIVE", "ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY"} {
		t.Setenv(name, "")
	}
	p := nativePaths(t)
	root := filepath.Join(t.TempDir(), "claude")
	if err := os.MkdirAll(root, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("CLAUDE_CONFIG_DIR", root)
	accountFile := filepath.Join(root, ".claude.json")
	if err := os.WriteFile(accountFile, []byte(`{"oauthAccount":{"accountUuid":"synthetic-account-001","organizationUuid":"synthetic-org-001"}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	p.ReaderAccess = &ReaderAccess{Grants: map[string]ReaderGrant{"claude": {Generation: "synthetic-grant-1", SavedLogin: true, Profiles: []ReaderProfile{{Root: root, AccountFile: accountFile}}}}}
	writeClaudeCredential(t, root, "synthetic-access-token", claudeTestNow.Add(48*time.Hour))
	return p
}

func writeClaudeCredential(t *testing.T, root, token string, expiry time.Time) {
	t.Helper()
	v := map[string]any{"claudeAiOauth": map[string]any{"accessToken": token, "expiresAt": expiry.UnixMilli(), "scopes": []string{"user:profile"}, "subscriptionType": "max", "refreshToken": "synthetic-refresh-must-never-be-used"}}
	b, _ := json.Marshal(v)
	if err := os.WriteFile(filepath.Join(root, ".credentials.json"), b, 0o600); err != nil {
		t.Fatal(err)
	}
}

func claudeCredentialJSON(t *testing.T, token string, expiry time.Time) []byte {
	t.Helper()
	v := map[string]any{"claudeAiOauth": map[string]any{"accessToken": token, "expiresAt": expiry.UnixMilli(), "scopes": []string{"user:profile"}, "subscriptionType": "max", "refreshToken": "synthetic-refresh-must-never-be-used"}}
	b, _ := json.Marshal(v)
	return b
}

func claudeTestServer(t *testing.T, status *int, paths *[]string) {
	t.Helper()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		*paths = append(*paths, r.URL.Path)
		if r.Method != "GET" || r.Header.Get("Authorization") != "Bearer synthetic-access-token" || r.Header.Get("anthropic-beta") != "oauth-2025-04-20" {
			t.Error("incorrect usage authentication")
		}
		if r.URL.Path == "/api/oauth/usage" && *status != 200 {
			w.Header().Set("Retry-After", "7200")
			w.WriteHeader(*status)
			_, _ = w.Write([]byte("synthetic-secret-error"))
			return
		}
		name := ""
		switch r.URL.Path {
		case "/api/oauth/profile":
			name = "profile.json"
		case "/api/oauth/usage":
			name = "usage.json"
		default:
			t.Error("unexpected endpoint")
			w.WriteHeader(400)
			return
		}
		b, err := os.ReadFile(filepath.Join("testdata", "claude-account", name))
		if err != nil {
			t.Error(err)
			w.WriteHeader(500)
			return
		}
		_, _ = w.Write(b)
	}))
	oldHost, oldClient := claudeOAuthHost, nativeClient
	nativeClient = readerFixtureClient(t, srv, "api.anthropic.com")
	t.Cleanup(func() { srv.Close(); claudeOAuthHost, nativeClient = oldHost, oldClient })
}

func TestClaudeAccountReadBudgetCadenceAndCache(t *testing.T) {
	p := claudeTestPaths(t)
	status := 200
	paths := []string{}
	claudeTestServer(t, &status, &paths)
	if !NativeDue(p, claudeTestNow) {
		t.Fatal("initial read not due")
	}
	if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	if strings.Join(paths, " ") != "/api/oauth/profile /api/oauth/usage" {
		t.Fatal(paths)
	}
	s, err := loadReaderState(p.Cache, "claude")
	if err != nil {
		t.Fatal(err)
	}
	a := s.Entries[0].Account
	if a == nil || a.Plan != "Max" || len(a.Windows) != 5 || a.Subscription == nil || a.Credits != nil {
		t.Fatalf("unexpected initial account: %+v", a)
	}
	if a.Windows[2].Limit != "Opus" || a.Windows[2].Kind != "weekly" || *a.Windows[4].UsedUSD != 12.5 || *a.Windows[4].LimitUSD != 50 {
		t.Fatal("window mapping")
	}
	if NativeDue(p, claudeTestNow.Add(4*time.Minute)) {
		t.Fatal("five minute floor bypassed")
	}
	if err := RefreshNative(context.Background(), p, claudeTestNow.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 2 {
		t.Fatal("early read made requests")
	}
	if err := RefreshNative(context.Background(), p, claudeTestNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if strings.Join(paths[2:], " ") != "/api/oauth/usage" {
		t.Fatal(paths)
	}
	s, _ = loadReaderState(p.Cache, "claude")
	a = s.Entries[0].Account
	if a.Credits != nil {
		t.Fatal("unverified prepaid mapping exposed a balance")
	}
	// A cache projection works after tool files disappear, without a consent
	// callback, HTTP, process launch or refreshed capture timestamp.
	root := p.ReaderAccess.Grants["claude"].Profiles[0].Root
	if err := os.RemoveAll(root); err != nil {
		t.Fatal(err)
	}
	p.ReaderAccess = nil
	r := Report{}
	applyManaged(&r, p, "claude", claudeTestNow.Add(5*time.Hour))
	if len(r.Accounts) != 1 || len(r.Accounts[0].Windows) != 4 || !r.Accounts[0].ObservedAt.Equal(claudeTestNow.Add(5*time.Minute)) || len(paths) != 3 {
		t.Fatal("cache read touched tool or retained reset window")
	}
	assertClaudeCachePrivate(t, p.Cache)
}

func TestClaudeFailuresRetainReadingAndBackoff(t *testing.T) {
	p := claudeTestPaths(t)
	status := 200
	paths := []string{}
	claudeTestServer(t, &status, &paths)
	if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	status = 429
	if err := RefreshNative(context.Background(), p, claudeTestNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "claude")
	if s.Entries[0].Status != "rate-limited" || s.Entries[0].Account == nil || !s.Entries[0].Account.ObservedAt.Equal(claudeTestNow) || !s.NextAttemptAt.Equal(claudeTestNow.Add(125*time.Minute)) {
		t.Fatal("failed read changed capture or ignored Retry-After")
	}
	if NativeDue(p, claudeTestNow.Add(124*time.Minute)) {
		t.Fatal("backoff ignored")
	}
	assertClaudeCachePrivate(t, p.Cache)
}

func TestClaudeAdmissionAndUnsupportedLoginsMakeNoRequests(t *testing.T) {
	for _, mode := range []string{"nil-grant", "passive", "off", "expired", "api-key", "missing-scope", "alternate-host"} {
		t.Run(mode, func(t *testing.T) {
			p := claudeTestPaths(t)
			status := 200
			paths := []string{}
			claudeTestServer(t, &status, &paths)
			g := p.ReaderAccess.Grants["claude"]
			switch mode {
			case "nil-grant":
				p.ReaderAccess = nil
			case "passive", "off":
				t.Setenv("MODELPLAN_READERS", mode)
			case "expired":
				writeClaudeCredential(t, g.Profiles[0].Root, "synthetic-access-token", claudeTestNow.Add(-time.Minute))
			case "api-key":
				t.Setenv("ANTHROPIC_API_KEY", "synthetic-key")
			case "missing-scope":
				if err := os.WriteFile(filepath.Join(g.Profiles[0].Root, ".credentials.json"), []byte(`{"mcpOAuth":{"accessToken":"synthetic-mcp"}}`), 0o600); err != nil {
					t.Fatal(err)
				}
			case "alternate-host":
				t.Setenv("ANTHROPIC_BASE_URL", "https://synthetic.invalid")
			}
			_ = RefreshNative(context.Background(), p, claudeTestNow)
			if len(paths) != 0 {
				t.Fatal("unsupported login made request")
			}
		})
	}
}

func TestClaudeKeychainBlockedStateKeepsCapture(t *testing.T) {
	p := claudeTestPaths(t)
	status := 200
	paths := []string{}
	claudeTestServer(t, &status, &paths)
	g := p.ReaderAccess.Grants["claude"]
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	home, _ := os.UserHomeDir()
	root := filepath.Join(home, ".claude")
	if err := os.MkdirAll(root, 0o700); err != nil {
		t.Fatal(err)
	}
	writeClaudeCredential(t, root, "synthetic-access-token", claudeTestNow.Add(48*time.Hour))
	g.Profiles = []ReaderProfile{{Root: root}}
	g.Keychain, g.KeychainPriorGrant = true, true
	p.ReaderAccess.Grants["claude"] = g
	if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(root, ".credentials.json")); err != nil {
		t.Fatal(err)
	}
	calls := 0
	old := claudeSecurity
	claudeSecurity = func(context.Context, string, ...string) (keychain.ProcessResult, error) {
		calls++
		return keychain.ProcessResult{ExitCode: 128}, nil
	}
	t.Cleanup(func() { claudeSecurity = old })
	if err := RefreshNative(context.Background(), p, claudeTestNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "claude")
	if s.Entries[0].Status != "denied" || s.Entries[0].NextStep != "Allow in Settings" || s.Entries[0].Account == nil || !s.Entries[0].Account.ObservedAt.Equal(claudeTestNow) {
		t.Fatal("Deny lost last good reading")
	}
	if err := RefreshNative(context.Background(), p, claudeTestNow.Add(15*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if calls != 1 || len(paths) != 2 {
		t.Fatal("background re-prompted or made HTTP call")
	}
}

func TestClaudeParserRejectsUnknownShapeAndCurrency(t *testing.T) {
	for _, body := range []string{`{}`, `{"five_hour":{"resets_at":"bad","utilization":1}}`, `{"five_hour":{"utilization":-1}}`, `{"five_hour":{"utilization":"secret"}}`} {
		var raw map[string]json.RawMessage
		_ = json.Unmarshal([]byte(body), &raw)
		if _, ok := parseClaudeUsage(raw, claudeTestNow); ok {
			t.Fatal("unsupported usage accepted")
		}
	}
	var raw map[string]json.RawMessage
	_ = json.Unmarshal([]byte(`{"five_hour":null,"seven_day":null}`), &raw)
	if ws, ok := parseClaudeUsage(raw, claudeTestNow); !ok || len(ws) != 0 {
		t.Fatal("plan without windows guessed a quota")
	}
}

func assertClaudeCachePrivate(t *testing.T, root string) {
	t.Helper()
	_ = filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		b, e := os.ReadFile(path)
		if e != nil {
			return e
		}
		for _, secret := range []string{"synthetic-access-token", "synthetic-refresh", "synthetic-account-001", "synthetic-org-001", "synthetic-secret-error"} {
			if strings.Contains(string(b), secret) {
				t.Fatal("private value persisted")
			}
		}
		return nil
	})
}

func TestClaudeDoesNotForwardCredentialOnRedirect(t *testing.T) {
	isolateHome(t)
	forwarded := false
	target := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { forwarded = true }))
	defer target.Close()
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, target.URL, 302) }))
	defer srv.Close()
	old := claudeOAuthHost
	claudeOAuthHost = srv.URL
	defer func() { claudeOAuthHost = old }()
	var profile claudeOAuthProfile
	state, _, _ := claudeGet(context.Background(), srv.Client(), "/api/oauth/profile", "synthetic-token", &profile, claudeTestNow)
	if forwarded || state == "" {
		t.Fatal("credential followed a redirect")
	}
}

func TestKeychainGrantReadsCredentialWithoutBypassingRemoteBudget(t *testing.T) {
	p := claudeTestPaths(t)
	status := 200
	paths := []string{}
	claudeTestServer(t, &status, &paths)
	g := p.ReaderAccess.Grants["claude"]
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	home, _ := os.UserHomeDir()
	root := filepath.Join(home, ".claude")
	if err := os.MkdirAll(root, 0o700); err != nil {
		t.Fatal(err)
	}
	g.Profiles = []ReaderProfile{{Root: root}}
	g.Keychain, g.KeychainPriorGrant = true, true
	p.ReaderAccess.Grants["claude"] = g
	interactive := []bool{}
	old := claudeSecurity
	t.Cleanup(func() { claudeSecurity = old })
	// The background attempt hits the two-second deadline while the OS prompt is open.
	claudeSecurity = func(ctx context.Context, _ string, _ ...string) (keychain.ProcessResult, error) {
		d, _ := ctx.Deadline()
		interactive = append(interactive, time.Until(d) > keychain.BackgroundTimeout)
		<-ctx.Done()
		return keychain.ProcessResult{}, ctx.Err()
	}
	if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadReaderState(p.Cache, "claude")
	if len(s.Entries) == 0 || s.Entries[0].Status != keychain.ConfirmationNeeded {
		t.Fatal("background timeout was not latched as before", s.Entries)
	}
	// A later background attempt would return the latch without asking again.
	// The grant triggers one interactive credential operation while the shared
	// remote budget stays closed.
	claudeSecurity = func(ctx context.Context, _ string, _ ...string) (keychain.ProcessResult, error) {
		d, _ := ctx.Deadline()
		interactive = append(interactive, time.Until(d) > keychain.BackgroundTimeout)
		return keychain.ProcessResult{Output: claudeCredentialJSON(t, "synthetic-access-token", claudeTestNow.Add(48*time.Hour))}, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
	defer cancel()
	if err := KeychainGrantRead(ctx, p, "claude", claudeTestNow.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	s, _ = loadReaderState(p.Cache, "claude")
	if len(paths) != 0 || len(s.Entries) == 0 || s.Entries[0].Account != nil {
		t.Fatal("Keychain grant bypassed remote budget", paths, s.Entries)
	}
	if len(interactive) != 2 || interactive[0] || !interactive[1] {
		t.Fatal("expected one background then one foreground Keychain attempt", interactive)
	}
	if _, err := os.Stat(filepath.Join(p.Cache, "observed", "keychain", "claude-code.json")); !os.IsNotExist(err) {
		t.Fatal("latched Keychain state survived a successful foreground read")
	}
	// After the backoff expires, a new explicit action reuses exactly one
	// credential result for the budgeted remote operation.
	if err := KeychainGrantRead(ctx, p, "claude", claudeTestNow.Add(11*time.Minute)); err != nil {
		t.Fatal(err)
	}
	s, _ = loadReaderState(p.Cache, "claude")
	if len(paths) == 0 || len(interactive) != 3 || s.Entries[0].Account == nil {
		t.Fatal("due read did not reuse one credential operation", paths, interactive, s.Entries)
	}
	if err := KeychainGrantRead(ctx, p, "codex", claudeTestNow); err == nil {
		t.Fatal("foreground path accepted a provider without a saved-login reader")
	}
	assertClaudeCachePrivate(t, p.Cache)
}

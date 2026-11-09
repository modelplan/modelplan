package quota

import (
	"bytes"
	"context"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"
)

// D99: the model slugs each tool reports. Per tool: success, timeout and malformed replies, and the quota
// reading is the same in every case. Calls go only to the reader's own host.

var grokModelsHandler = func(w http.ResponseWriter, r *http.Request) { http.NotFound(w, r) }
var kimiModelsHandler = func(w http.ResponseWriter, r *http.Request) { http.NotFound(w, r) }

func shortReportedTimeout(t *testing.T) {
	t.Helper()
	old := reportedModelsTimeout
	reportedModelsTimeout = 700 * time.Millisecond
	t.Cleanup(func() { reportedModelsTimeout = old })
}

func TestReportedModelIDsKeepSlugsOnly(t *testing.T) {
	got := reportedModelIDs([]byte(`{"data":[{"id":"m-b"},{"id":"m-a"},{"id":"m-a"},{"id":"someone@example.com"},{"id":"has space"},{"model":"m-c"}],"models":[{"id":"m-d"}]}`))
	if strings.Join(got, ",") != "m-a,m-b,m-c,m-d" {
		t.Fatalf("got %v", got)
	}
	for _, bad := range []string{``, `{`, `null`, `{"data":"x"}`, `42`, `{"data":[1,2]}`} {
		if got := reportedModelIDs([]byte(bad)); len(got) != 0 {
			t.Fatalf("%q gave %v", bad, got)
		}
	}
	if got := reportedModelIDs([]byte(`["a","b"]`)); strings.Join(got, ",") != "a,b" {
		t.Fatal(got)
	}
}

func TestGrokReportedModels(t *testing.T) {
	for _, tc := range []struct {
		name    string
		handler http.HandlerFunc
		want    string
	}{
		{"ok", func(w http.ResponseWriter, r *http.Request) {
			if r.Method != "GET" || r.Header.Get("Authorization") != "Bearer synthetic-grok-access" || r.Header.Get("x-userid") != "synthetic-grok-user" || r.Header.Get("X-XAI-Token-Auth") != "xai-grok-cli" {
				t.Error("models call does not reuse the reader's headers")
			}
			_, _ = w.Write([]byte(`{"data":[{"id":"grok-build-1","owned_by":"private-owner-canary"},{"id":"grok-build-fast"}]}`))
		}, "grok-build-1,grok-build-fast"},
		{"malformed", func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("{")) }, ""},
		{"error", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(500) }, ""},
		{"redirect", func(w http.ResponseWriter, r *http.Request) { http.Redirect(w, r, "http://127.0.0.1:1/x", 302) }, ""},
		{"timeout", func(w http.ResponseWriter, r *http.Request) { time.Sleep(time.Second) }, ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			shortReportedTimeout(t)
			p := grokTestPaths(t)
			mode, hits := "ok", 0
			grokTestServer(t, &mode, &hits)
			old := grokModelsHandler
			grokModelsHandler = tc.handler
			t.Cleanup(func() { grokModelsHandler = old })
			if err := RefreshNative(context.Background(), p, grokNow); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "grok")
			e := s.Entries[0]
			if e.Status != "ok" || hits != 1 || e.Account == nil || len(e.Account.Windows) != 2 {
				t.Fatalf("the quota read is affected: %+v hits=%d", e, hits)
			}
			if got := strings.Join(e.ReportedModels, ","); got != tc.want {
				t.Fatalf("reportedModels = %q", got)
			}
			r := Report{}
			applyManaged(&r, p, "grok", grokNow.Add(time.Minute))
			if len(r.Accounts) != 1 || strings.Join(r.Accounts[0].ReportedModels, ",") != tc.want {
				t.Fatalf("account reportedModels = %v", r.Accounts)
			}
			b, _ := os.ReadFile(readerPath(p.Cache, "grok"))
			if bytes.Contains(b, []byte("private-owner-canary")) {
				t.Fatal("more than slugs persisted")
			}
		})
	}
}

func TestKimiReportedModels(t *testing.T) {
	for _, tc := range []struct {
		name    string
		handler http.HandlerFunc
		want    string
	}{
		{"ok", func(w http.ResponseWriter, r *http.Request) {
			if r.Method != "GET" || !strings.HasPrefix(r.Header.Get("Authorization"), "Bearer ") || r.Header.Get("X-Msh-Device-Id") != "synthetic-device-001" {
				t.Error("models call does not reuse the reader's headers")
			}
			_, _ = w.Write([]byte(`{"data":[{"id":"kimi-for-coding","display_name":"private-name-canary"}]}`))
		}, "kimi-for-coding"},
		{"malformed", func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte("not json")) }, ""},
		{"error", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(403) }, ""},
		{"timeout", func(w http.ResponseWriter, r *http.Request) { time.Sleep(time.Second) }, ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			shortReportedTimeout(t)
			p, token := kimiLoginTestPaths(t)
			mode, hits := "ok", 0
			kimiLoginServer(t, token, &mode, &hits)
			old := kimiModelsHandler
			kimiModelsHandler = tc.handler
			t.Cleanup(func() { kimiModelsHandler = old })
			if err := RefreshNative(context.Background(), p, kimiNow); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "kimi")
			e := s.Entries[0]
			if e.Status != "ok" || hits != 1 || e.Account == nil || len(e.Account.Windows) != 3 {
				t.Fatalf("the quota read is affected: %+v hits=%d", e, hits)
			}
			if got := strings.Join(e.ReportedModels, ","); got != tc.want {
				t.Fatalf("reportedModels = %q", got)
			}
			b, _ := os.ReadFile(readerPath(p.Cache, "kimi"))
			if bytes.Contains(b, []byte("private-name-canary")) {
				t.Fatal("more than slugs persisted")
			}
		})
	}
}

func TestGeminiReportedModelsAreTheQuotaBucketIDs(t *testing.T) {
	p := geminiTestPaths(t)
	mode := "ok"
	paths := []string{}
	geminiServer(t, &mode, &paths)
	if err := RefreshNative(context.Background(), p, geminiNow); err != nil {
		t.Fatal(err)
	}
	if strings.Join(paths, " ") != "/v1internal:loadCodeAssist /v1internal:retrieveUserQuota" {
		t.Fatalf("extra requests: %v", paths)
	}
	s, _ := loadReaderState(p.Cache, "gemini")
	if got := strings.Join(s.Entries[0].ReportedModels, ","); got != "gemini-2.5-flash,gemini-2.5-pro" {
		t.Fatalf("reportedModels = %q", got)
	}
	r := Report{}
	applyManaged(&r, p, "gemini", geminiNow.Add(time.Minute))
	if len(r.Accounts) != 1 || len(r.Accounts[0].ReportedModels) != 2 {
		t.Fatal("not on the account")
	}
	// A malformed quota reply yields no models and no reading.
	mode = "malformed"
	p2 := geminiTestPaths(t)
	if err := RefreshNative(context.Background(), p2, geminiNow); err != nil {
		t.Fatal(err)
	}
	s, _ = loadReaderState(p2.Cache, "gemini")
	if len(s.Entries) != 1 || s.Entries[0].Status == "ok" || len(s.Entries[0].ReportedModels) != 0 {
		t.Fatalf("%+v", s.Entries)
	}
}

func TestAntigravityReportedModelsIncludeModelsWithoutQuota(t *testing.T) {
	isolateHome(t)
	body := antigravityFixture
	desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) { _, _ = w.Write([]byte(body)) })
	ctx := WithAntigravityServer(context.Background(), desc)
	cache := t.TempDir()
	e := collectAntigravity(ctx, nil, cache, now)
	if e.Status != "ok" || len(e.Windows) != 2 {
		t.Fatalf("quota reading changed: %+v", e)
	}
	if got := strings.Join(e.ReportedModels, ","); got != "MISSING,MODEL_CLAUDE,MODEL_GEMINI" {
		t.Fatalf("reportedModels = %q", got)
	}
	r := ReadAntigravityCache(ctx, cache, now.Add(time.Minute))
	if r.Reading == nil || strings.Join(r.Reading.ReportedModels, ",") != "MISSING,MODEL_CLAUDE,MODEL_GEMINI" {
		t.Fatalf("%+v", r.Reading)
	}
	b, _ := os.ReadFile(antigravityStatePath(cache))
	if bytes.Contains(b, []byte("private-label-canary")) || bytes.Contains(b, []byte("private-email-canary")) {
		t.Fatal("more than slugs persisted")
	}
	// Malformed: no models, and the error is the same as before.
	e = parseAntigravity([]byte(`{"userStatus":{"cascadeModelConfigData":{"clientModelConfigs":"x"}}}`), now)
	if e.Status == "ok" || len(e.ReportedModels) != 0 {
		t.Fatal(e)
	}
}

func TestClaudeReportedModelsComeFromTheLocalCacheOnly(t *testing.T) {
	p := claudeTestPaths(t)
	file := p.ReaderAccess.Grants["claude"].Profiles[0].AccountFile
	cfg := `{"oauthAccount":{"accountUuid":"synthetic-account-001","organizationUuid":"synthetic-org-001"},"userID":"private-id-canary","modelAccessCache":[{"apiName":"claude-opus-5-5","entitled":true},{"apiName":"claude-old","entitled":false},{"apiName":"claude-sonnet-5-5","entitled":true},{"apiName":"x@y.com","entitled":true}],"other":{"email":"private-mail-canary"}}`
	if err := os.WriteFile(file, []byte(cfg), 0o600); err != nil {
		t.Fatal(err)
	}
	status := 200
	paths := []string{}
	claudeTestServer(t, &status, &paths) // fails the test on any endpoint but profile and usage (no bootstrap)
	if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	if strings.Join(paths, " ") != "/api/oauth/profile /api/oauth/usage" {
		t.Fatalf("extra requests: %v", paths)
	}
	s, _ := loadReaderState(p.Cache, "claude")
	e := s.Entries[0]
	if e.Status != "ok" || e.Account == nil || len(e.Account.Windows) != 5 {
		t.Fatal("quota read affected")
	}
	if got := strings.Join(e.ReportedModels, ","); got != "claude-opus-5-5,claude-sonnet-5-5" {
		t.Fatalf("reportedModels = %q", got)
	}
	b, _ := os.ReadFile(readerPath(p.Cache, "claude"))
	for _, canary := range []string{"private-id-canary", "private-mail-canary", "synthetic-account-001"} {
		if bytes.Contains(b, []byte(canary)) {
			t.Fatal("more than slugs persisted: " + canary)
		}
	}
	for _, bad := range []string{`{"modelAccessCache":[]}`, `{"modelAccessCache":"x"}`, `{"modelAccessCache":[{"apiName":"a"}]}`, `{`, `[]`, `{"a":1}`} {
		if err := os.WriteFile(file, []byte(bad), 0o600); err != nil {
			t.Fatal(err)
		}
		if got := claudeModelAccess(file); len(got) != 0 {
			t.Fatalf("%q gave %v", bad, got)
		}
	}
	if claudeModelAccess(file+".missing") != nil || claudeModelAccess("") != nil {
		t.Fatal("a missing file must give none")
	}
}

func TestCopilotReportedModels(t *testing.T) {
	// The reply frames after the handshake; models.list is the only addition after account.getQuota.
	frames := func(models string) string {
		s := copilotFrame(`{"id":1,"result":{"protocolVersion":3}}`) + copilotFrame(`{"id":3,"result":{"isAuthenticated":true,"authType":"user"}}`) + copilotFrame(`{"id":4,"result":`+copilotQuota+`}`)
		if models != "" {
			s += copilotFrame(models)
		}
		return s
	}
	for _, tc := range []struct{ name, models, want string }{
		{"ok", `{"id":5,"result":{"models":[{"id":"gpt-5.1","name":"private-name-canary","billing":{"multiplier":1}},{"id":"claude-sonnet-5-5"}]}}`, "claude-sonnet-5-5,gpt-5.1"},
		{"malformed", `{"id":5,"result":"x"}`, ""},
		{"error", `{"id":5,"error":{"code":-32601}}`, ""},
		{"none", "", ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			shortReportedTimeout(t)
			var calls bytes.Buffer
			raw, models, err := copilotRPC(strings.NewReader(frames(tc.models)), &calls, true)
			if err != nil || len(raw) == 0 {
				t.Fatalf("quota read affected: %v", err)
			}
			if strings.Join(models, ",") != tc.want {
				t.Fatalf("models = %v", models)
			}
			if n := strings.Count(calls.String(), `"method":"models.list"`); n != 1 {
				t.Fatalf("models.list asked %d times: %s", n, calls.String())
			}
			for _, banned := range []string{"session.", "account.getUser", "login"} {
				if strings.Contains(calls.String(), banned) {
					t.Fatal("allowlist widened: " + banned)
				}
			}
		})
	}
	// The quota-only entry point asks nothing more.
	var calls bytes.Buffer
	if _, err := copilotQuotaRPC(strings.NewReader(frames("")), &calls); err != nil || strings.Contains(calls.String(), "models.list") {
		t.Fatal("quota-only read asked for models")
	}
}

func TestCopilotModelListTimeoutNeverFailsTheQuotaRead(t *testing.T) {
	shortReportedTimeout(t)
	isolateHome(t)
	bin, _ := fakeCopilot(t)
	t.Setenv("MODELPLAN_COPILOT", bin)
	t.Setenv("MODELPLAN_TEST_COPILOT_MODELS", "hang")
	start := time.Now()
	e := fetchCopilot(context.Background(), nil, "local", "", now)
	if e.Status != "ok" || len(e.Windows) != 2 || len(e.ReportedModels) != 0 {
		t.Fatalf("%+v", e)
	}
	if time.Since(start) > 5*time.Second {
		t.Fatal("the model list cap did not hold")
	}
}

func TestCopilotReportedModelsThroughTheProcessAndCache(t *testing.T) {
	isolateHome(t)
	bin, log := fakeCopilot(t)
	t.Setenv("MODELPLAN_COPILOT", bin)
	t.Setenv("MODELPLAN_TEST_COPILOT_MODELS", `{"models":[{"id":"gpt-5.1"},{"id":"some@mail.example"}]}`)
	p := nativePaths(t)
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "copilot", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if err := RefreshNative(context.Background(), p, now); err != nil {
		t.Fatal(err)
	}
	calls, _ := os.ReadFile(log)
	if bytes.Count(calls, []byte(`"method":"models.list"`)) != 1 || bytes.Contains(calls, []byte("session.")) {
		t.Fatal(string(calls))
	}
	r := Read(p, now)
	for _, a := range r.Accounts {
		if a.Source == "native:copilot" {
			if strings.Join(a.ReportedModels, ",") != "gpt-5.1" || len(a.Windows) != 2 {
				t.Fatalf("%+v", a)
			}
			return
		}
	}
	t.Fatal("no copilot account")
}

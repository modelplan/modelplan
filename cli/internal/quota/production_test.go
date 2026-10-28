// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/keychain"
)

// Setup helpers below create handwritten logins and inject local transports.
// Their test-only Paths/grants are discarded. Every request and projection in
// this test uses the exact ProductionPaths constructor called by the CLI/App.
var productionManagedTests = map[string]func(*testing.T) (time.Time, func() int){
	"claude": func(t *testing.T) (time.Time, func() int) {
		_ = claudeTestPaths(t)
		status, paths := 200, []string{}
		claudeTestServer(t, &status, &paths)
		return claudeTestNow, func() int { return len(paths) }
	},
	"cursor": func(t *testing.T) (time.Time, func() int) {
		_, token := cursorAdmittedPaths(t)
		mode, paths := "ok", []string{}
		cursorPeriodServer(t, token, &mode, &paths)
		return cursorNow, func() int { return len(paths) }
	},
	"gemini": func(t *testing.T) (time.Time, func() int) {
		_ = geminiTestPaths(t)
		mode, paths := "ok", []string{}
		geminiServer(t, &mode, &paths)
		return geminiNow, func() int { return len(paths) }
	},
	"grok": func(t *testing.T) (time.Time, func() int) {
		_ = grokTestPaths(t)
		mode, hits := "ok", 0
		grokTestServer(t, &mode, &hits)
		return grokNow, func() int { return hits }
	},
	"kimi": func(t *testing.T) (time.Time, func() int) {
		_, token := kimiLoginTestPaths(t)
		mode, hits := "ok", 0
		kimiLoginServer(t, token, &mode, &hits)
		return kimiNow, func() int { return hits }
	},
}

func productionConsent(t *testing.T, id string, on bool) {
	t.Helper()
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, id, on, "native:"+id, BackendNative, time.Now()) }); err != nil {
		t.Fatal(err)
	}
}

func TestProductionManagedAdmission(t *testing.T) {
	for provider, setup := range productionManagedTests {
		t.Run(provider, func(t *testing.T) {
			at, hits := setup(t)
			t.Setenv("MODELPLAN_READERS", "")
			cache := t.TempDir()
			paths := func() Paths { return ProductionPaths(cache, "1.0.0") }
			if NativeDue(paths(), at) {
				t.Fatal("reader due before consent")
			}
			_ = RefreshNative(context.Background(), paths(), at)
			if hits() != 0 {
				t.Fatal("request before consent")
			}
			productionConsent(t, provider, true)
			p := paths()
			g, ok := p.ReaderAccess.Grants[provider]
			if !ok || !g.SavedLogin || g.Interactive || len(g.Profiles) == 0 || g.Generation == "synthetic-grant-001" {
				t.Fatal("production grant missing", g)
			}
			if !NativeDue(p, at) {
				t.Fatal("consented login never due")
			}
			if err := RefreshNative(context.Background(), p, at); err != nil {
				t.Fatal(err)
			}
			called := hits()
			if called == 0 {
				t.Fatal("no admitted request")
			}
			s, err := loadReaderState(cache, provider)
			if err != nil || len(s.Entries) != 1 || s.Entries[0].Status != "ok" || s.Entries[0].Account == nil {
				t.Fatalf("no real reader capture: %+v %v", s, err)
			}
			report := ReadPermitted(paths(), at)
			found := false
			for _, source := range report.Sources {
				if source.Source == "native:"+provider && source.Status == "ok" {
					found = true
				}
			}
			if !found || hits() != called {
				t.Fatal("cache-only production projection missing or made a request", report.Sources)
			}
			t.Setenv("MODELPLAN_READERS", "off")
			if NativeDue(paths(), at.Add(time.Hour)) {
				t.Fatal("off admitted reader")
			}
			_ = RefreshNative(context.Background(), paths(), at.Add(time.Hour))
			if hits() != called {
				t.Fatal("off made request")
			}
			t.Setenv("MODELPLAN_READERS", "")
			productionConsent(t, provider, false)
			if g.StillValid() {
				t.Fatal("old grant survived revocation")
			}
			_ = RefreshNative(context.Background(), paths(), at.Add(time.Hour))
			if hits() != called {
				t.Fatal("revoked reader made request")
			}
			report = ReadPermitted(paths(), at)
			for _, source := range report.Sources {
				if source.Source == "native:"+provider && source.Status == "ok" {
					t.Fatal("revoked cache exposed")
				}
			}
		})
	}
}

func TestProductionKeychainPolicy(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	home, _ := os.UserHomeDir()
	if err := os.MkdirAll(filepath.Join(home, ".claude"), 0700); err != nil {
		t.Fatal(err)
	}
	productionConsent(t, "claude", true)
	p := ProductionPaths(t.TempDir(), "1.0.0")
	g := p.ReaderAccess.Grants["claude"]
	if !g.Keychain || !g.KeychainPriorGrant || g.Interactive {
		t.Fatal("invalid background Keychain policy")
	}
	if !InteractiveReaders(p).ReaderAccess.Grants["claude"].Interactive || p.ReaderAccess.Grants["claude"].Interactive {
		t.Fatal("interactive policy leaked into background")
	}
	if err := consent.Deny(consent.Path(), "claude", "keychain"); err != nil {
		t.Fatal(err)
	}
	p = ProductionPaths(p.Cache, "1.0.0")
	if p.ReaderAccess.Grants["claude"].Keychain || InteractiveReaders(p).ReaderAccess.Grants["claude"].Interactive {
		t.Fatal("persisted Deny re-enabled")
	}
}

func TestProductionUnsetClaudeKeychainNamesCauseAndSettingsAction(t *testing.T) {
	_ = claudeTestPaths(t)
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	home, _ := os.UserHomeDir()
	root := filepath.Join(home, ".claude")
	if err := os.MkdirAll(root, 0700); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		if err := consent.Set(s, "claude", true, "native:claude", "native", claudeTestNow); err != nil {
			return err
		}
		r := s.Tools["claude"]
		consent.SetKeychain(&r, "")
		s.Tools["claude"] = r
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	status, requests := 200, []string{}
	claudeTestServer(t, &status, &requests)
	old := claudeSecurity
	claudeSecurity = func(context.Context, string, ...string) (keychain.ProcessResult, error) {
		t.Fatal("unset Keychain choice invoked Keychain")
		return keychain.ProcessResult{}, nil
	}
	t.Cleanup(func() { claudeSecurity = old })
	p := ProductionPaths(t.TempDir(), "1.0.0")
	if grant := p.ReaderAccess.Grants["claude"]; grant.Keychain || grant.KeychainConsent != "unset" {
		t.Fatal("production discarded the unset cause", grant)
	}
	if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	s, err := loadReaderState(p.Cache, "claude")
	if err != nil || len(s.Entries) != 1 || s.Entries[0].Status != "consent_required" || s.Entries[0].Notice != consent.ClaudeKeychainUnsetNotice || s.Entries[0].NextStep != "Allow Keychain for Claude Code in Settings" {
		t.Fatal("missing Keychain choice blamed the saved login", s, err)
	}
	r := ReadPermitted(p, claudeTestNow)
	found := false
	for _, source := range r.Sources {
		if source.Source == "native:claude" && source.Status == "consent_required" && source.Reason == consent.ClaudeKeychainNextStep {
			found = true
		}
	}
	if !found || len(requests) != 0 {
		t.Fatal("cached readback lost next step or made provider calls", r, requests)
	}
	// File-based Claude logins do not need Keychain: their read must still work.
	writeClaudeCredential(t, root, "synthetic-access-token", claudeTestNow.Add(48*time.Hour))
	if err := RefreshNative(context.Background(), p, claudeTestNow.Add(10*time.Minute)); err != nil {
		t.Fatal(err)
	}
	s, err = loadReaderState(p.Cache, "claude")
	if err != nil || len(s.Entries) != 1 || s.Entries[0].Status != "ok" || s.Entries[0].Notice != "" || s.Entries[0].NextStep != "" || len(requests) != 2 {
		t.Fatal("unset Keychain choice blocked a file-based login", s, err, requests)
	}
}

var productionLegacyTests = map[string]func(*testing.T) (time.Time, func() int){
	"copilot": func(t *testing.T) (time.Time, func() int) {
		bin, log := fakeCopilot(t)
		t.Setenv("MODELPLAN_COPILOT", bin)
		return now, func() int { b, _ := os.ReadFile(log); return len(b) }
	},
	"kiro": func(t *testing.T) (time.Time, func() int) {
		bin, log := fakeKiro(t, kiroUsage)
		t.Setenv("MODELPLAN_KIRO", bin)
		return now, func() int { b, _ := os.ReadFile(log); return len(b) }
	},
	"antigravity": func(t *testing.T) (time.Time, func() int) {
		hits := 0
		desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) { hits++; _, _ = w.Write([]byte(antigravityFixture)) })
		old := antigravityCommand
		t.Cleanup(func() { antigravityCommand = old })
		antigravityCommand = func(context.Context, string, ...string) ([]byte, error) {
			return []byte(fmt.Sprintf("%d %d language_server /app/language_server --app_data_dir antigravity --csrf_token %s --extension_server_port %d\n", desc.PID, os.Getuid(), desc.CSRF, desc.Port)), nil
		}
		return now, func() int { return hits }
	},
	"zai": func(t *testing.T) (time.Time, func() int) {
		seen, cleanup := zaiServer(t)
		t.Cleanup(cleanup)
		t.Setenv("Z_AI_API_KEY", "test-key")
		return zaiNow, func() int { return len(*seen) }
	},
	"minimax": func(t *testing.T) (time.Time, func() int) {
		hits := 0
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { hits++; _, _ = w.Write([]byte(minimaxModern)) }))
		old, client := minimaxHosts, nativeClient
		t.Cleanup(func() { srv.Close(); minimaxHosts, nativeClient = old, client })
		minimaxHosts = map[string]string{"international": srv.URL, "china": srv.URL}
		nativeClient = srv.Client()
		t.Setenv("MINIMAX_CODING_API_KEY", "synthetic-key")
		return minimaxNow, func() int { return hits }
	},
	"opencodego": func(t *testing.T) (time.Time, func() int) {
		hits := 0
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			hits++
			_, _ = w.Write([]byte(`{"usage":{"rolling":{"usagePercent":25,"resetInSec":3600}}}`))
		}))
		old, client := opencodegoHosts, nativeClient
		t.Cleanup(func() { srv.Close(); opencodegoHosts, nativeClient = old, client })
		opencodegoHosts = map[string]string{"global": srv.URL}
		nativeClient = srv.Client()
		t.Setenv("OPENCODE_API_KEY", "synthetic-key")
		return now, func() int { return hits }
	},
}

func TestProductionNativeRegistryHasAdmissionCoverage(t *testing.T) {
	for id, n := range nativeReaders {
		if n.Managed != nil {
			if productionManagedTests[id] == nil {
				t.Error("no production managed test", id)
			}
		} else if productionLegacyTests[id] == nil {
			t.Error("no production legacy test", id)
		}
	}
}

func TestProductionLegacyAdmission(t *testing.T) {
	for provider, setup := range productionLegacyTests {
		t.Run(provider, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_READERS", "")
			t.Setenv("MODELPLAN_NATIVE", "")
			at, hits := setup(t)
			cache := t.TempDir()
			paths := func() Paths { return ProductionPaths(cache, "1.0.0") }
			_ = RefreshNative(context.Background(), paths(), at)
			if hits() != 0 {
				t.Fatal("request before consent")
			}
			productionConsent(t, provider, true)
			if !NativeDue(paths(), at) {
				t.Fatal("consented reader not due")
			}
			if err := RefreshNative(context.Background(), paths(), at); err != nil {
				t.Fatal(err)
			}
			called := hits()
			if called == 0 {
				t.Fatal("reader never dispatched")
			}
			r := ReadPermitted(paths(), at)
			found := false
			for _, s := range r.Sources {
				if s.Source == "native:"+provider && s.Status == "ok" {
					found = true
				}
			}
			if !found || hits() != called {
				t.Fatal("cache-only state missing or made request", r.Sources)
			}
			for _, mode := range []string{"off", "passive"} {
				t.Setenv("MODELPLAN_READERS", mode)
				// Saved-login/runtime imports stay off in passive; explicit environment-key
				// routes retain their existing passive policy and are covered separately.
				if mode == "passive" && nativeReaders[provider].KeyEnv != "" {
					continue
				}
				_ = RefreshNative(context.Background(), paths(), at.Add(time.Hour))
				if hits() != called {
					t.Fatal("privacy mode made request", mode)
				}
			}
			t.Setenv("MODELPLAN_READERS", "")
			productionConsent(t, provider, false)
			_ = RefreshNative(context.Background(), paths(), at.Add(time.Hour))
			if hits() != called {
				t.Fatal("revoked reader made request")
			}
		})
	}
}

func TestProductionConfiguredGLMSource(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	root := filepath.Join(home, ".claude")
	if err := os.MkdirAll(root, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "settings.json"), []byte(`{"env":{"ANTHROPIC_BASE_URL":"https://api.z.ai/api/anthropic","ANTHROPIC_AUTH_TOKEN":"test-key"}}`), 0600); err != nil {
		t.Fatal(err)
	}
	seen, cleanup := zaiServer(t)
	t.Cleanup(cleanup)
	productionConsent(t, "zai", true)
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		r := s.Tools["zai"]
		r.Profiles = []string{"claude-code"}
		s.Tools["zai"] = r
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	p := ProductionPaths(t.TempDir(), "1.0.0")
	if err := RefreshNative(context.Background(), p, zaiNow); err != nil {
		t.Fatal(err)
	}
	if len(*seen) != 1 {
		t.Fatal("selected configured source not dispatched", len(*seen))
	}
	r := ReadPermitted(ProductionPaths(p.Cache, "1.0.0"), zaiNow)
	found := false
	for _, s := range r.Sources {
		if s.Source == "native:zai" && s.Status == "ok" {
			found = true
		}
	}
	if !found {
		t.Fatal("GLM production cache missing", r.Sources)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		record := s.Tools["zai"]
		record.Region = "bigmodel-cn"
		s.Tools["zai"] = record
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	mismatch := ProductionPaths(t.TempDir(), "1.0.0")
	_ = RefreshNative(context.Background(), mismatch, zaiNow)
	if len(*seen) != 1 {
		t.Fatal("configured credentials sent outside selected region")
	}
	productionConsent(t, "zai", false)
	_ = RefreshNative(context.Background(), ProductionPaths(p.Cache, "1.0.0"), zaiNow.Add(time.Hour))
	if len(*seen) != 1 {
		t.Fatal("revoked configured source requested")
	}
}

func TestProductionRouteRestrictions(t *testing.T) {
	for _, tc := range []struct {
		name, mode, privacy, backend, reader string
		off, symlink                         bool
		want                                 bool
	}{
		{name: "explicit automatic", mode: "automatic", want: true},
		{name: "passive override", mode: "passive"},
		{name: "saved passive cannot be elevated", privacy: "passive", mode: "automatic"},
		{name: "native off", off: true},
		{name: "helper cannot grant native", backend: "codexbar", reader: "codexbar:claude"},
		{name: "root symlink", symlink: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_NATIVE", "")
			t.Setenv("MODELPLAN_READERS", tc.mode)
			t.Setenv("CLAUDE_CONFIG_DIR", "")
			if tc.off {
				t.Setenv("MODELPLAN_NATIVE", "off")
			}
			home, _ := os.UserHomeDir()
			root := filepath.Join(home, ".claude")
			if tc.symlink {
				if err := os.Symlink(t.TempDir(), root); err != nil {
					t.Fatal(err)
				}
			} else if err := os.MkdirAll(root, 0700); err != nil {
				t.Fatal(err)
			}
			productionConsent(t, "claude", true)
			if err := consent.Change(consent.Path(), func(s *consent.State) error {
				if tc.privacy != "" {
					s.Privacy = tc.privacy
				}
				r := s.Tools["claude"]
				if tc.backend != "" {
					r.Backend = tc.backend
					r.ReaderID = tc.reader
				}
				s.Tools["claude"] = r
				return nil
			}); err != nil {
				t.Fatal(err)
			}
			p := ProductionPaths(t.TempDir(), "1.0.0")
			_, admitted := p.ReaderAccess.Grants["claude"]
			if admitted != tc.want {
				t.Fatal("unexpected admission", admitted)
			}
		})
	}
}

type productionTransport func(*http.Request) (*http.Response, error)

func (f productionTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestProductionRevocationDuringManagedRead(t *testing.T) {
	_ = claudeTestPaths(t)
	status, paths := 200, []string{}
	claudeTestServer(t, &status, &paths)
	productionConsent(t, "claude", true)
	p := ProductionPaths(t.TempDir(), "1.0.0")
	client := *nativeClient
	transport := client.Transport
	client.Transport = productionTransport(func(r *http.Request) (*http.Response, error) {
		response, err := transport.RoundTrip(r)
		if r.URL.Path == "/api/oauth/usage" {
			productionConsent(t, "claude", false)
		}
		return response, err
	})
	old := nativeClient
	nativeClient = &client
	t.Cleanup(func() { nativeClient = old })
	if err := RefreshNative(context.Background(), p, claudeTestNow); err == nil {
		t.Fatal("revoked read published")
	}
	state, err := loadReaderState(p.Cache, "claude")
	if err != nil {
		t.Fatal(err)
	}
	for _, entry := range state.Entries {
		if entry.Account != nil {
			t.Fatal("revoked account persisted")
		}
	}
	if err := ForgetTool(ProductionPaths(p.Cache, "1.0.0"), "claude"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(readerPath(p.Cache, "claude")); !os.IsNotExist(err) {
		t.Fatal("Forget left managed reading", err)
	}
}

func TestProductionBackgroundKeychainReusesGrantAndPreservesDeny(t *testing.T) {
	_ = claudeTestPaths(t)
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	home, _ := os.UserHomeDir()
	root := filepath.Join(home, ".claude")
	if err := os.MkdirAll(root, 0700); err != nil {
		t.Fatal(err)
	}
	writeClaudeCredential(t, root, "synthetic-access-token", claudeTestNow.Add(48*time.Hour))
	credential, err := os.ReadFile(filepath.Join(root, ".credentials.json"))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(filepath.Join(root, ".credentials.json")); err != nil {
		t.Fatal(err)
	}
	status, paths := 200, []string{}
	claudeTestServer(t, &status, &paths)
	calls, deny := 0, false
	old := claudeSecurity
	t.Cleanup(func() { claudeSecurity = old })
	claudeSecurity = func(ctx context.Context, bin string, args ...string) (keychain.ProcessResult, error) {
		calls++
		deadline, ok := ctx.Deadline()
		if !ok || time.Until(deadline) > keychain.BackgroundTimeout+100*time.Millisecond {
			t.Error("background Keychain deadline not bounded")
		}
		if bin != "/usr/bin/security" {
			t.Error("unexpected process")
		}
		if deny {
			return keychain.ProcessResult{ExitCode: 128}, nil
		}
		return keychain.ProcessResult{Output: credential, ExitCode: 0}, nil
	}
	productionConsent(t, "claude", true)
	cache := t.TempDir()
	pathsFor := func() Paths { return ProductionPaths(cache, "1.0.0") }
	if err := RefreshNative(context.Background(), pathsFor(), claudeTestNow); err != nil {
		t.Fatal(err)
	}
	if calls != 1 || len(paths) != 2 {
		t.Fatal("production Keychain grant was not reused", calls, paths)
	}
	deny = true
	if err := RefreshNative(context.Background(), pathsFor(), claudeTestNow.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if calls != 2 {
		t.Fatal("Deny process fixture not reached", calls)
	}
	if err := RefreshNative(context.Background(), pathsFor(), claudeTestNow.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if calls != 2 {
		t.Fatal("persisted Deny retried")
	}
	productionConsent(t, "claude", false)
	if err := ForgetTool(pathsFor(), "claude"); err != nil {
		t.Fatal(err)
	}
	productionConsent(t, "claude", true)
	_ = RefreshNative(context.Background(), pathsFor(), claudeTestNow.Add(2*time.Hour))
	if calls != 2 {
		t.Fatal("Forget/reconnect retried persisted Deny")
	}
}

func TestProductionCatalogueDoesNotGrantDisabledOrHelperRoutes(t *testing.T) {
	for _, tc := range []struct {
		name, preferred, reader, min, access string
		want                                 bool
	}{
		{"native", "native", "native:claude", "0.0.0", "", true},
		{"off", "off", "native:claude", "0.0.0", "", false},
		{"not read", "codexbar", "codexbar:claude", "0.0.0", "not-read", false},
		{"unaudited helper", "codexbar", "codexbar:claude", "0.0.0", "standard", false},
		{"advanced helper", "codexbar", "codexbar:claude", "0.0.0", "browser-session", false},
		{"requires update", "native", "native:claude", "99.0.0", "", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("MODELPLAN_READERS", "")
			t.Setenv("MODELPLAN_NATIVE", "")
			home, _ := os.UserHomeDir()
			if err := os.MkdirAll(filepath.Join(home, ".claude"), 0700); err != nil {
				t.Fatal(err)
			}
			productionConsent(t, "claude", true)
			entry := detect.Entry{ProviderID: "claude", ReaderID: tc.reader, Preferred: tc.preferred, MinCLI: tc.min}
			entry.CodexBar.AccessClass = tc.access
			old := loadReaderCatalogue
			loadReaderCatalogue = func(string) *detect.Catalogue { return &detect.Catalogue{Detectors: []detect.Entry{entry}} }
			t.Cleanup(func() { loadReaderCatalogue = old })
			p := ProductionPaths(t.TempDir(), "1.0.0")
			_, ok := p.ReaderAccess.Grants["claude"]
			if ok != tc.want {
				t.Fatal("unexpected catalogue admission", ok)
			}
		})
	}
}

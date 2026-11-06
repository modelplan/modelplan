// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// G3-21 (owner report, build 541b32b9): ZCode (GLM Coding Plan) installed and used, never
// detected or read. Synthetic provider files only; the key is a canary.

func writeZCodeProviders(t *testing.T, home, body string) {
	t.Helper()
	dir := filepath.Join(home, ".zcode", "v2")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "provider_config.json"), []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
}

const zcodeTemplateProvider = `{"schemaVersion":1,"config":{"providerConfigRules":{"providerRules":[
 {"providerId":"other","templateId":null,"enabled":true,"config":{"access":{"type":"api-key","apiKey":"other-canary"},"api":{"type":"openai-chat-completions","baseUrl":"https://api.example.test/v1"}}},
 {"providerId":"glm-plan","templateId":"zai-api","enabled":true,"config":{"access":{"type":"zhipu-coding-plan-api-key","apiKey":"zcode-key-canary"}}}]},
 "modelConfigRules":{"providerModelRules":[],"manualProviderModelRules":[]},
 "defaultModelSelection":{"providerId":"glm-plan","modelId":"glm-5"}}}`

func TestG321ZCodeSelectedCodingPlanKeyOnly(t *testing.T) {
	for _, tc := range []struct {
		name, body, region, key string
	}{
		{"template coding plan", zcodeTemplateProvider, "global", "zcode-key-canary"},
		{"bigmodel api key", `{"schemaVersion":1,"config":{"providerConfigRules":{"providerRules":[{"providerId":"bm","config":{"access":{"type":"api-key","apiKey":"bm-canary"},"api":{"baseUrl":"https://open.bigmodel.cn/api/coding/paas/v4"}}}]},"defaultModelSelection":{"providerId":"bm"}}}`, "bigmodel-cn", "bm-canary"},
		{"account login", `{"schemaVersion":1,"config":{"providerConfigRules":{"providerRules":[]},"defaultModelSelection":{"providerId":"account:zai-individual-coding-plan"}}}`, "", ""},
		{"selected foreign endpoint", `{"schemaVersion":1,"config":{"providerConfigRules":{"providerRules":[{"providerId":"x","config":{"access":{"type":"api-key","apiKey":"x-canary"},"api":{"baseUrl":"https://api.example.test/v1"}}}]},"defaultModelSelection":{"providerId":"x"}}}`, "", ""},
		{"standard (non coding plan) template", `{"schemaVersion":1,"config":{"providerConfigRules":{"providerRules":[{"providerId":"s","templateId":"zai-standard-api","config":{"access":{"type":"api-key","apiKey":"s-canary"}}}]},"defaultModelSelection":{"providerId":"s"}}}`, "", ""},
		{"disabled", strings.Replace(zcodeTemplateProvider, `"templateId":"zai-api","enabled":true`, `"templateId":"zai-api","enabled":false`, 1), "", ""},
		{"no selection", `{"schemaVersion":1,"config":{"providerConfigRules":{"providerRules":[{"providerId":"glm-plan","templateId":"zai-api","config":{"access":{"type":"zhipu-coding-plan-api-key","apiKey":"k"}}}]}}}`, "", ""},
		{"unknown schema", strings.Replace(zcodeTemplateProvider, `"schemaVersion":1`, `"schemaVersion":2`, 1), "", ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			region, key, state := zaiConfiguredKey(ZaiConfigSource{Tool: "zcode", SettingsPath: zaiConfigTestFile(t, tc.body)})
			if region != tc.region || key != tc.key || (tc.key == "") != (state != "") {
				t.Fatalf("region=%q key-set=%t state=%q", region, key != "", state)
			}
		})
	}
}

// Through the production constructor on a fresh profile (no consent file): the ZCode
// Coding Plan reading flows into the report without a consent click, and only to Z.ai's own
// quota endpoint with the selected provider's key.
func TestG321FreshProfileReadsZCodeCodingPlanByDefault(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.Host != "api.z.ai" || r.URL.Path != "/api/monitor/usage/quota/limit" || r.Header.Get("Authorization") != "zcode-key-canary" {
			t.Errorf("unexpected request host=%s path=%s", r.Host, r.URL.Path)
		}
		_, _ = w.Write([]byte(`{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25,"nextResetTime":1792152000000}]}}`))
	}))
	defer server.Close()
	oldClient := nativeClient
	t.Cleanup(func() { nativeClient = oldClient })
	nativeClient = readerFixtureClient(t, server, "api.z.ai", "open.bigmodel.cn")
	if _, err := os.Stat(consent.Path()); !os.IsNotExist(err) {
		t.Fatal("fixture must start without consent decisions")
	}
	cache := t.TempDir()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if g, ok := p.ReaderAccessGrant("zai"); !ok || g.ConfigSource == nil || g.ConfigSource.Tool != "zcode" {
		t.Fatal("ZCode's Coding Plan route is not admitted by default")
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now); err != nil {
		t.Fatalf("default ZCode refresh: %v", err)
	}
	if calls.Load() != 1 {
		t.Fatalf("quota endpoint calls = %d", calls.Load())
	}
	report := ReadPermitted(ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), now)
	found := false
	for _, a := range report.Accounts {
		if a.Source == "native:zai" && len(a.Windows) > 0 && a.Windows[0].UsedPercent != nil {
			found = true
		}
	}
	if !found {
		for _, a := range report.Accounts {
			t.Logf("account source=%s windows=%d", a.Source, len(a.Windows))
		}
		t.Fatalf("no ZCode reading in the report: %+v", report.Sources)
	}
	for _, f := range []string{zaiConfigStatePath(cache), nativePath(cache)} {
		if b, err := os.ReadFile(f); err == nil && strings.Contains(string(b), "canary") {
			t.Fatalf("key persisted in %s", f)
		}
	}
}

// A user who turned GLM off, or chose another GLM source, is never read through ZCode.
func TestG321ExplicitGLMDecisionWins(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		s.Tools["zai"] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	if _, ok := p.ReaderAccessGrant("zai"); ok {
		t.Fatal("a GLM denial was overridden by the ZCode default")
	}
	t.Setenv("MODELPLAN_READERS", "off")
	if _, ok := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture()).ReaderAccessGrant("zai"); ok {
		t.Fatal("readers off still admitted ZCode")
	}
}

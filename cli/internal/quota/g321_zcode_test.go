// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

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
			// The working signal binds ZCode's turns to this account; it needs no second key read.
			if ref := ZCodeSubscription(cache, consent.Capture(), now); ref == "" || a.Subscription == nil || a.Subscription.Ref != ref {
				t.Fatalf("ZCode account ref = %q, binding = %+v", ref, a.Subscription)
			}
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

func TestZCodeQuotaRetainsAdmittedWindowsThroughTemporaryFailure(t *testing.T) {
	for _, entered := range []bool{false, true} {
		name := "provider file"
		if entered {
			name = "entered key"
		}
		t.Run(name, func(t *testing.T) {
			isolateHome(t)
			home, _ := os.UserHomeDir()
			writeZCodeProviders(t, home, zcodeTemplateProvider)
			cache := t.TempDir()
			paths := func() Paths { return ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()) }
			if entered {
				if err := SetManualKey(cache, "zai", fakeZaiKey, "global"); err != nil {
					t.Fatal(err)
				}
			}
			reset := now.Add(time.Hour)
			var calls atomic.Int32
			server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				key := "zcode-key-canary"
				if entered {
					key = "Bearer " + fakeZaiKey
				}
				if r.Header.Get("Authorization") != key {
					t.Error("unexpected credential source")
				}
				if calls.Add(1) > 1 {
					w.WriteHeader(http.StatusServiceUnavailable)
					return
				}
				fmt.Fprintf(w, `{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25,"nextResetTime":%d}]}}`, reset.UnixMilli())
			}))
			defer server.Close()
			useClient(t, server, "api.z.ai")
			reportAccount := func(report Report) *Account {
				for _, account := range report.Accounts {
					if account.Source == "native:zai" {
						return &account
					}
				}
				return nil
			}
			p := paths()
			refresh := func(at time.Time) {
				t.Helper()
				if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, at); err != nil {
					t.Fatal(err)
				}
			}
			refresh(now)
			fresh := reportAccount(ReadPermitted(paths(), now))
			if fresh == nil || fresh.Stale || len(fresh.Windows) != 1 {
				t.Fatalf("fresh reading: %+v", fresh)
			}
			failedAt := now.Add(NativeEvery)
			refresh(failedAt)
			retained := ReadPermitted(paths(), failedAt)
			account := reportAccount(retained)
			if account == nil || !account.Stale || !account.ObservedAt.Equal(fresh.ObservedAt) || len(account.Windows) != 1 {
				t.Fatalf("retained reading: %+v, sources: %+v", account, retained.Sources)
			}
			for _, source := range retained.Sources {
				if source.Source == "native:zai" && source.ErrorCode != "http_5xx" {
					t.Fatalf("temporary failure hidden: %+v", source)
				}
			}
			if account := reportAccount(ReadPermitted(paths(), reset)); account != nil {
				t.Fatalf("expired window retained: %+v", account)
			}
			if entered {
				if err := SetManualKey(cache, "zai", fakeOtherKey, "global"); err != nil {
					t.Fatal(err)
				}
			} else {
				writeZCodeProviders(t, home, strings.Replace(zcodeTemplateProvider, "zcode-key-canary", "replacement-key", 1))
				if ref := ZCodeSubscription(cache, consent.Capture(), failedAt); ref != "" {
					t.Fatal("replaced provider file retained the old activity binding")
				}
			}
			for _, current := range []Paths{p, paths()} {
				if account := reportAccount(ReadPermitted(current, failedAt)); account != nil {
					t.Fatalf("old credential reading after replacement: %+v", account)
				}
			}
			if calls.Load() != 2 {
				t.Fatalf("passive reads must not reach the endpoint: %d calls", calls.Load())
			}
		})
	}
}

func TestZCodeProviderReplacementWithPreservedMetadataInvalidatesQuotaAndActivity(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	cache := t.TempDir()
	paths := func() Paths { return ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()) }
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		want := "zcode-key-canary"
		if calls.Add(1) == 2 {
			want = "zcode-key-change"
		}
		if r.Header.Get("Authorization") != want {
			t.Error("quota request used the wrong synthetic credential")
		}
		fmt.Fprintf(w, `{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25,"nextResetTime":%d}]}}`, now.Add(time.Hour).UnixMilli())
	}))
	defer server.Close()
	useClient(t, server, "api.z.ai")
	original := paths()
	read := func(p Paths, at time.Time) {
		t.Helper()
		if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, at); err != nil {
			t.Fatal(err)
		}
	}
	read(original, now)
	oldRef := ZCodeSubscription(cache, consent.Capture(), now)
	if oldRef == "" || zcodeAccount(ReadPermitted(original, now)) == nil {
		t.Fatal("fixture did not establish a quota reading and activity binding")
	}

	file := ZCodeProviderConfig(home)
	opened, err := os.Open(file)
	if err != nil {
		t.Fatal(err)
	}
	before, err := opened.Stat()
	opened.Close()
	if err != nil {
		t.Fatal(err)
	}
	replacement := file + ".replacement"
	body := strings.Replace(zcodeTemplateProvider, "zcode-key-canary", "zcode-key-change", 1)
	if err := os.WriteFile(replacement, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(replacement, before.ModTime(), before.ModTime()); err != nil {
		t.Fatal(err)
	}
	if err := os.Rename(replacement, file); err != nil {
		t.Fatal(err)
	}
	after, err := os.Stat(file)
	if err != nil {
		t.Fatal(err)
	}
	if os.SameFile(before, after) || after.Size() != before.Size() || !after.ModTime().Equal(before.ModTime()) {
		t.Fatal("fixture must replace the inode while preserving size and mtime")
	}

	at := now.Add(time.Minute)
	replaced := paths()
	for _, current := range []Paths{original, replaced} {
		if a := zcodeAccount(ReadPermitted(current, at)); a != nil {
			t.Error("provider replacement left its previous quota eligible")
		}
	}
	if ref := ZCodeSubscription(cache, consent.Capture(), at); ref != "" {
		t.Error("provider replacement left its previous activity binding eligible")
	}
	if calls.Load() != 1 {
		t.Fatalf("passive projection made a request: %d total", calls.Load())
	}

	next := now.Add(NativeEvery)
	read(replaced, next)
	ref := ZCodeSubscription(cache, consent.Capture(), next)
	a := zcodeAccount(ReadPermitted(paths(), next))
	if calls.Load() != 2 || ref == "" || ref == oldRef || a == nil || a.Subscription == nil ||
		a.Subscription.Ref != ref || !a.ObservedAt.Equal(next) {
		t.Fatalf("replacement quota and binding were not established by the scheduled read: %d requests", calls.Load())
	}
}

func TestZCodeMembershipSurvivesPersistedFailedAndEmptyReads(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	if err := SetManualKey(cache, "zai", fakeZaiKey, "global"); err != nil {
		t.Fatal(err)
	}
	paths := func() Paths { return ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()) }
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "Bearer "+fakeZaiKey {
			t.Error("unexpected credential source")
		}
		switch calls.Add(1) {
		case 1:
			fmt.Fprint(w, zaiOKBody)
		case 2:
			w.WriteHeader(http.StatusUnauthorized)
		case 3:
			fmt.Fprint(w, `{"success":true,"code":200,"data":{"limits":[]}}`)
		default:
			t.Error("unexpected extra network request")
		}
	}))
	defer server.Close()
	useClient(t, server, "api.z.ai")
	if ReadPermitted(paths(), now).ZaiSubscriptionEstablished {
		t.Fatal("an entered key did not establish any quota yet")
	}
	for i, at := range []time.Time{now, now.Add(NativeEvery), now.Add(NativeEvery + nativeRetryAfter)} {
		if err := ExecuteScopeRefresh(context.Background(), paths(), consent.ScopeZaiAccountUsageAPIKey, at); err != nil {
			t.Fatal(err)
		}
		report := ReadPermitted(paths(), at)
		if !report.ZaiSubscriptionEstablished || ((i == 0) != (zcodeAccount(report) != nil)) {
			t.Fatalf("attempt %d: membership=%t, has quota=%t", i+1, report.ZaiSubscriptionEstablished, zcodeAccount(report) != nil)
		}
	}
	if calls.Load() != 3 {
		t.Fatalf("want exactly three scheduled reads, got %d", calls.Load())
	}
}

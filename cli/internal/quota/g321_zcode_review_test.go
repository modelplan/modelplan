// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// Regressions from the MACREV-B review of #603 (macrevb-603-1..3), synthetic only.

// macrevb-603-2: replacing the selected ZCode key after a refusal reads again.
func TestG321ReviewRecoveryAfterZCodeKeyChange(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if strings.Contains(r.Header.Get("Authorization"), "zcode-key-canary") {
			w.WriteHeader(401)
			return
		}
		_, _ = w.Write([]byte(`{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25}]}}`))
	}))
	defer server.Close()
	prior := nativeClient
	t.Cleanup(func() { nativeClient = prior })
	nativeClient = readerFixtureClient(t, server, "api.z.ai", "open.bigmodel.cn")
	cache := t.TempDir()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now); err != nil {
		t.Fatal(err)
	}
	if loadZaiConfigState(cache).Availability != "expired_login" {
		t.Fatal("fixture did not establish auth refusal")
	}
	writeZCodeProviders(t, home, strings.ReplaceAll(zcodeTemplateProvider, "zcode-key-canary", "replacement-canary"))
	p = ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now.Add(2*time.Hour)); err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 2 || loadZaiConfigState(cache).Availability != "ok" {
		t.Fatalf("recovery requests=%d availability=%s", calls.Load(), loadZaiConfigState(cache).Availability)
	}
}

// macrevb-603-3: a GLM source already chosen in connections.json wins over ZCode's default.
func TestG321ReviewExistingGLMSelectionWins(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	t.Setenv("MACREVB_GLM_KEY", "chosen-key-canary")
	var calls atomic.Int32
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.Host != "open.bigmodel.cn" || r.Header.Get("Authorization") != "Bearer chosen-key-canary" {
			t.Error("configured GLM source ignored: wrong host or credential")
		}
		_, _ = w.Write([]byte(`{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25}]}}`))
	}))
	defer server.Close()
	prior := nativeClient
	t.Cleanup(func() { nativeClient = prior })
	nativeClient = readerFixtureClient(t, server, "api.z.ai", "open.bigmodel.cn")
	cache := t.TempDir()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "zai", Backend: BackendNative, Enabled: true, Region: "bigmodel-cn", KeyEnv: "MACREVB_GLM_KEY"}); err != nil {
		t.Fatal(err)
	}
	p = ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := RefreshNative(context.Background(), p, now); err != nil {
		t.Fatal(err)
	}
	if calls.Load() != 1 {
		t.Fatalf("requests=%d", calls.Load())
	}
}

// macrevb-603-1: ZCode's key goes as the complete Authorization value, as ZCode sends it.
func TestG321ReviewZCodeAuthMatchesOfficialContract(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") != "zcode-key-canary" {
			w.WriteHeader(401)
			return
		}
		_, _ = w.Write([]byte(`{"success":true,"code":200,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25}]}}`))
	}))
	defer server.Close()
	prior := nativeClient
	t.Cleanup(func() { nativeClient = prior })
	nativeClient = readerFixtureClient(t, server, "api.z.ai", "open.bigmodel.cn")
	cache := t.TempDir()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now); err != nil {
		t.Fatal(err)
	}
	if loadZaiConfigState(cache).Availability != "ok" {
		t.Fatal("documented raw-key auth did not produce a reading")
	}
}

// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// macrev2-1162-1. Invariant: with saved-login access Allowed but the separate Keychain choice Unset
// or Denied, ModelPlan opens or parses no private ZCode file and runs no Keychain operation, for a
// marked store, a markerless Keychain-bound store and a 3.11-3.18 (enc:v1) store alike. Every entry
// point is driven: route discovery, the ordinary refresh, the scope refresh, the report and the
// diagnostics, and the reader itself.
func TestMacrev1162NoZCodeFileOpenBeforeKeychainChoice(t *testing.T) {
	stores := map[string]func(t *testing.T, home string) (dir, encoded string){
		"marked-os": func(t *testing.T, home string) (string, string) {
			key, encoded := zcodeTestKey(t)
			return writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key), encoded
		},
		"markerless-os": func(t *testing.T, home string) (string, string) {
			key, encoded := zcodeTestKey(t)
			dir := writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
			if err := os.Remove(filepath.Join(dir, "credential-source")); err != nil {
				t.Fatal(err)
			}
			return dir, encoded
		},
		"markerless-v1": func(t *testing.T, home string) (string, string) {
			return writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}), ""
		},
	}
	for name, write := range stores {
		for _, choice := range []struct{ grant, pending, code string }{{"", "unset", "keychain_unset"}, {"deny", "denied", "keychain_denied"}} {
			t.Run(name+"/"+choice.pending, func(t *testing.T) {
				isolateHome(t)
				t.Setenv("Z_AI_API_KEY", "")
				home, _ := os.UserHomeDir()
				dir, encoded := write(t, home)
				z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai", "open.bigmodel.cn", "zcode.z.ai")
				var opens atomic.Int32
				old := zcodeLoginRead
				t.Cleanup(func() { zcodeLoginRead = old })
				zcodeLoginRead = func(path string) ([]byte, error) {
					if strings.HasPrefix(path, dir) {
						opens.Add(1)
					}
					return old(path)
				}
				fake := &fakeKeychain{value: encoded}
				grantZCodeLogin(t)
				if choice.grant != "" {
					grantZCodeKeychain(t, choice.grant)
				}
				now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
				cache := t.TempDir()
				p := WithZCodeKeychain(ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), fake.key)
				if _, ok := p.ReaderAccessGrant("zai"); ok || p.ZCodeKeychainPending != choice.pending {
					t.Fatalf("route admitted=%t pending=%q, want no route and %q", ok, p.ZCodeKeychainPending, choice.pending)
				}
				_ = RefreshNative(context.Background(), p, now)
				_ = RefreshNativeProviders(context.Background(), p, now, []string{"zai"})
				_ = ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now)
				r, s, diags := zcodeReport(t, cache, now)
				if s.ErrorCode != choice.code || zcodeAccount(r) != nil {
					t.Fatalf("source %+v, want %s and no reading", s, choice.code)
				}
				// The reader itself refuses before any open, whatever reaches it.
				for _, consentValue := range []string{"", "unset", "denied"} {
					if _, code := readZCodeLogin(context.Background(), dir, &ZCodeKeychain{Consent: consentValue, Key: fake.key}, now); !strings.HasPrefix(code, "keychain_") {
						t.Fatalf("reader with choice %q returned %q", consentValue, code)
					}
				}
				if _, code := readZCodeLogin(context.Background(), dir, nil, now); code != "keychain_unset" {
					t.Fatalf("reader without a Keychain capability returned %q", code)
				}
				if opens.Load() != 0 || fake.calls.Load() != 0 || z.calls.Load() != 0 {
					t.Fatalf("before Allow: %d ZCode file opens, %d Keychain operations, %d requests", opens.Load(), fake.calls.Load(), z.calls.Load())
				}
				assertNoZCodeSecret(t, cache, r, diags)
			})
		}
	}
}

// The legacy 3.11-3.18 store still reads once both choices are Allow, with no Keychain operation.
func TestMacrev1162LegacyStoreReadsAfterKeychainAllowWithoutKeychainOperation(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	fake := &fakeKeychain{}
	grantZCodeKeychain(t, "allow")
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	p := WithZCodeKeychain(ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), fake.key)
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	if fake.calls.Load() != 0 || z.calls.Load() != 1 {
		t.Fatalf("keychain %d, requests %d; want 0 and 1", fake.calls.Load(), z.calls.Load())
	}
	if got := (<-z.seen).Header.Get("Authorization"); got != "Bearer "+zcodeAccountCanary {
		t.Fatal("legacy store did not send its own account key")
	}
}

// macrev2-1162-2. Invariant: once GLM API-key access is Denied, a retained pasted key never reaches
// transport under any admission. The independently allowed saved login refreshes through the
// ordinary refresh, the scope refresh and the provider refresh; only its own credential is sent,
// and the reading is published under the saved-login scope.
func TestMacrev1162DeniedPastedKeyNeverSentBySavedLoginRefresh(t *testing.T) {
	const pasted = "macrev2-pasted-key-canary-1162"
	for _, entry := range []string{"native", "providers", "scope"} {
		t.Run(entry, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("Z_AI_API_KEY", "")
			home, _ := os.UserHomeDir()
			writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
			z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai", "open.bigmodel.cn", "zcode.z.ai")
			cache := t.TempDir()
			if err := SetManualKey(cache, "zai", pasted, "global"); err != nil {
				t.Fatal(err)
			}
			grantZCodeKeychain(t, "allow")
			samplingDenyZCodeKey(t)
			if !ManualKeyPresent(cache, "zai") {
				t.Fatal("fixture: the pasted key is meant to be retained after Deny")
			}
			now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
			p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
			if !zcodeLoginRoute(p, "zai") {
				t.Fatal("saved login not selected after API-key Deny")
			}
			if pastedGLMKeyRoute(p) {
				t.Fatal("denied pasted key still counts as a route")
			}
			switch entry {
			case "native":
				_ = RefreshNative(context.Background(), p, now)
			case "providers":
				_ = RefreshNativeProviders(context.Background(), p, now, []string{"zai"})
			case "scope":
				if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
					t.Fatal(err)
				}
				if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now); err == nil {
					t.Fatal("denied API-key scope refresh ran")
				}
			}
			close(z.seen)
			sent := 0
			for req := range z.seen {
				sent++
				if strings.Contains(req.Header.Get("Authorization"), pasted) || strings.Contains(req.URL.String(), pasted) {
					t.Fatal("sent the retained pasted key after API-key Deny")
				}
				if req.Header.Get("Authorization") != "Bearer "+zcodeAccountCanary {
					t.Fatal("request did not carry the saved-login credential")
				}
			}
			if sent != 1 {
				t.Fatalf("requests = %d, want the one saved-login read", sent)
			}
			for _, e := range loadNative(cache).Providers {
				if e.Provider == "zai" && (e.ManualKeyGeneration != 0 || e.SubscriptionRef != "") {
					t.Fatalf("reading attributed to the pasted key: %+v", e)
				}
			}
			published := false
			for _, e := range loadNative(cache).Providers {
				if e.Provider == "zai" && e.Status == "ok" {
					published = e.Admission != nil && e.Admission.Scope == consent.ScopeZaiAccountUsageSavedLogin
				}
			}
			if !published {
				t.Fatal("reading not published under the saved-login scope")
			}
		})
	}
}

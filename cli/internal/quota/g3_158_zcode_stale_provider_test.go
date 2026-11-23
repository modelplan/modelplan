// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// G3-158 follow-up (owner's Mac, ZCode 3.19.1): ~/.zcode/v2 holds the QR sign-in files
// (setting.json, config.json, credentials.json) and an old 206-byte provider_config.json from
// 09-19 that selects no key. The provider-file key route ran first, found no key and reported
// unsupported_login, so the sign-in route (D369) was never offered.

// Stale provider files as an old ZCode left them: no rule selected, or an account selection.
var zcodeStaleProviderFiles = map[string]string{
	"no_selection":      `{"schemaVersion":1,"config":{"providerConfigRules":{"providerRules":[]}}}`,
	"account_selection": `{"schemaVersion":1,"config":{"providerConfigRules":{"providerRules":[]},"defaultModelSelection":{"providerId":"account:zai"}}}`,
}

func TestG3158StaleKeylessProviderFileFallsThroughToSignIn(t *testing.T) {
	for name, body := range zcodeStaleProviderFiles {
		t.Run(name, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("Z_AI_API_KEY", "")
			home, _ := os.UserHomeDir()
			writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
			writeZCodeProviders(t, home, body)
			z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
			now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
			cache := t.TempDir()

			// Before consent: the row asks for the sign-in's consent, not "unsupported".
			p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
			if !p.ZCodeLoginConsent {
				t.Fatal("a keyless provider file hid the QR sign-in")
			}
			r, s, _ := zcodeReport(t, cache, now)
			if s.ErrorCode != "consent_required" || zcodeAccount(r) != nil {
				t.Fatalf("source %+v, want consent_required", s)
			}

			// After consent: the sign-in route reads the quota.
			grantZCodeLogin(t)
			p = ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
			if g, ok := p.ReaderAccessGrant("zai"); !ok || g.ConfigSource == nil || g.ConfigSource.Tool != zcodeLoginTool {
				t.Fatalf("sign-in route not admitted after consent: %+v", g.ConfigSource)
			}
			if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
				t.Fatalf("refresh: %v", err)
			}
			r, s, diags := zcodeReport(t, cache, now)
			if a := zcodeAccount(r); a == nil || len(a.Windows) == 0 || *a.Windows[0].UsedPercent != 40 || z.calls.Load() != 1 {
				t.Fatalf("no reading after consent: source %+v calls %d", s, z.calls.Load())
			}
			assertNoZCodeSecret(t, cache, r, diags)
		})
	}
}

// The Keychain-bound store (ZCode 3.19+) that G3-158 reported as unsupported is read since D380;
// see d380_zcode_keychain_test.go.

func TestD380DeniedKeyIgnoresStaleProviderFile(t *testing.T) {
	for _, keychain := range []bool{false, true} {
		name := "legacy"
		if keychain {
			name = "keychain"
		}
		t.Run(name, func(t *testing.T) {
			isolateHome(t)
			t.Setenv("Z_AI_API_KEY", "synthetic-unadmitted-key")
			home, _ := os.UserHomeDir()
			fixture := zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}
			if keychain {
				key, _ := zcodeTestKey(t)
				writeZCodeKeychainLogin(t, home, fixture, key)
			} else {
				writeZCodeLogin(t, home, fixture)
			}
			writeZCodeProviders(t, home, zcodeStaleProviderFiles["no_selection"])
			grantZCodeLogin(t)
			state, err := consent.EnsureStore(consent.Path())
			if err != nil {
				t.Fatal(err)
			}
			_, err = consent.ApplyGrant(consent.Path(), consent.Grant{
				RequestID: "d380-deny-api", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation,
				ConsentTextVersion: consent.TextVersion, Deny: []string{consent.ScopeZaiAccountUsageAPIKey},
			}, consent.GrantHooks{})
			if err != nil {
				t.Fatal(err)
			}
			p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
			zcodeKeylessMu.Lock()
			_, probed := zcodeKeylessMemo[ZCodeProviderConfig(home)]
			zcodeKeylessMu.Unlock()
			if probed {
				t.Fatal("denied provider file was classified")
			}
			if keychain {
				if p.ZCodeKeychainPending != "unset" {
					t.Fatal("allowed QR sign-in did not reach its own Keychain choice")
				}
				return
			}
			g, ok := p.ReaderAccessGrant("zai")
			if !ok || g.ConfigSource == nil || g.ConfigSource.SettingsPath != ZCodeLoginDir(home) ||
				g.ConfigSource.Tool != zcodeLoginTool {
				t.Fatal("denied key suppressed the independently admitted QR route")
			}
			z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
			now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
			if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil || z.calls.Load() != 1 {
				t.Fatalf("admitted QR refresh did not send one request: %v", err)
			}
		})
	}
}

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

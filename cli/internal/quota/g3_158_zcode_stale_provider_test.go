// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
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

			// An admitted key read classifies the old file under the reader lock; route
			// discovery itself cannot open a file that may contain a credential.
			p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
			_ = RefreshNativeProviders(context.Background(), p, now, []string{"zai"})
			if z.calls.Load() != 0 {
				t.Fatal("keyless provider unexpectedly sent a request")
			}
			// Before login consent: the row asks for consent, not "unsupported".
			p = ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
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

// ZCode 3.19 keeps its credential key in the macOS Keychain: credential-source says "os" and the
// store's entries are enc:v2. ModelPlan does not read another app's Keychain item (D230/D232), so
// that sign-in is not offered (no consent asked for a read that cannot work), and a store with v2
// entries is unsupported, never "sign in again" and never answered from the plaintext mirror.
func TestG3158KeychainBoundZCodeStoreIsUnsupported(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	writeZCodeProviders(t, home, zcodeStaleProviderFiles["no_selection"])
	if err := os.WriteFile(filepath.Join(dir, "credential-source"), []byte("os"), 0o600); err != nil {
		t.Fatal(err)
	}
	if detect.ZCodeLoginPresent(home) {
		t.Fatal("a Keychain-bound ZCode store listed as a readable sign-in")
	}
	cache := t.TempDir()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if p.ZCodeLoginConsent {
		t.Fatal("consent asked for a sign-in ModelPlan cannot read")
	}
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai", "open.bigmodel.cn", "zcode.z.ai")
	_ = RefreshNativeProviders(context.Background(), p, now, []string{"zai"})
	_, s, _ := zcodeReport(t, cache, now)
	if z.calls.Load() != 0 {
		t.Fatalf("%d requests", z.calls.Load())
	}
	if s.ErrorCode != "unsupported_login" {
		t.Fatalf("source %+v, want unsupported_login", s)
	}

	// Read time: a store whose entries are enc:v2 (Keychain-keyed) is unsupported even with a
	// plaintext mirror present, and nothing is sent.
	if err := os.Remove(filepath.Join(dir, "credential-source")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "credentials.json"), []byte(`{"oauth:zai:user_info":"enc:v2:os:aaaa.bbbb.cccc","zcodejwttoken":"enc:v2:os:aaaa.bbbb.cccc"}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "config.json"), []byte(`{"provider":{"builtin:zai-coding-plan":{"enabled":true,"options":{"apiKey":"mirror-canary"}}}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, code := readZCodeLogin(dir, time.Now()); code != "unsupported_login" {
		t.Fatalf("v2 store code %q, want unsupported_login", code)
	}
}

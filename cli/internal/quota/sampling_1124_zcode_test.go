// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Post-merge sampling 11-24 (#1182 finding 1): a refused saved-login scope is never offered
// again. With the key scope undecided (default allowed), no usable key and the QR sign-in
// present, denying saved-login shows the denied state, not consent_required.
func TestSampling1124DeniedSavedLoginShowsDeniedNotConsentPrompt(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai", "open.bigmodel.cn", "zcode.z.ai")
	s, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	r, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "sampling-1124-deny-login", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Deny: []string{consent.ScopeZaiAccountUsageSavedLogin}}, consent.GrantHooks{Cleanup: func(string, bool) error { return nil }})
	if err != nil || r.Code != "ok" {
		t.Fatalf("deny saved login: %+v %v", r, err)
	}
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if zcodeLoginRoute(p, "zai") {
		t.Fatal("a denied saved-login scope was admitted")
	}
	if p.ZCodeLoginConsent {
		t.Fatal("a denied saved-login scope asks for consent again")
	}
	if !p.ZCodeLoginDenied {
		t.Fatal("the denied saved-login state is not reported")
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err == nil {
		t.Fatal("a denied saved-login refresh ran")
	}
	_ = RefreshNativeProviders(context.Background(), p, now, []string{"zai"})
	report, src, diags := zcodeReport(t, cache, now)
	if src.ErrorCode == "consent_required" || src.Reason == "consent_required" {
		t.Fatalf("source %+v offers consent for a denied scope", src)
	}
	if src.ErrorCode != "consent_denied" {
		t.Fatalf("source %+v, want consent_denied", src)
	}
	for _, d := range diags {
		if d.Provider == "zai" && d.State != "unavailable:denied" {
			t.Fatalf("diagnostic %+v, want unavailable:denied", d)
		}
	}
	if a := zcodeAccount(report); a != nil {
		t.Fatalf("data shown for a denied scope: %+v", a)
	}
	if z.calls.Load() != 0 {
		t.Fatalf("%d requests under a denied scope", z.calls.Load())
	}
}

// Post-merge sampling 11-24 (#1182 finding 2): zcodeKeylessMemo is memory only, so after each
// engine start discovery picks the key route. The api_key refresh that classifies the file as
// keyless and moves the route to the saved login must defer (reader busy, quick retry), not
// fail into the 10-minute backoff. It still sends nothing.
func TestSampling1124KeylessFirstStartDefersKeyScope(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	writeZCodeProviders(t, home, zcodeStaleProviderFiles["no_selection"])
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeLogin(t)
	cache := t.TempDir()
	now := time.Now()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if zcodeLoginRoute(p, "zai") {
		t.Fatal("fixture: discovery already chose the saved login")
	}
	plan, err := PlanScopeRefresh(p, consent.ScopeZaiAccountUsageAPIKey, now)
	if err != nil || !plan.Admitted {
		t.Fatalf("fixture: key plan %+v %v", plan, err)
	}
	err = ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now)
	if !errors.Is(err, consent.ErrReaderBusy) {
		t.Fatalf("key-scope refresh after the route moved: %v, want reader busy", err)
	}
	if z.calls.Load() != 0 {
		t.Fatal("key-scoped refresh sent the saved login")
	}
	p = ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if plan, err := PlanScopeRefresh(p, consent.ScopeZaiAccountUsageAPIKey, now); err != nil || plan.Admitted {
		t.Fatalf("key scope still planned after the route moved: %+v %v", plan, err)
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	if z.calls.Load() != 1 {
		t.Fatalf("saved-login quota calls = %d", z.calls.Load())
	}
}

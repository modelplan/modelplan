// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestSampling1122ZCodeRefreshRespectsSelectedScope(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true, jwt: zcodeTestJWT(time.Now().Add(time.Hour))})
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeLogin(t)
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	plan, err := PlanScopeRefresh(p, consent.ScopeZaiAccountUsageAPIKey, now)
	if err != nil {
		t.Fatal(err)
	}
	if plan.Admitted {
		t.Error("API-key plan admitted a saved-login route")
	}
	_ = ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now)
	if z.calls.Load() != 0 {
		t.Fatalf("API-key request sent the login credential (%d calls)", z.calls.Load())
	}
	plan, err = PlanScopeRefresh(p, consent.ScopeZaiAccountUsageSavedLogin, now)
	if err != nil || !plan.Admitted {
		t.Fatalf("saved-login plan: %+v %v", plan, err)
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	if z.calls.Load() != 1 {
		t.Fatalf("saved-login requests = %d", z.calls.Load())
	}
}

func TestSampling1122KeyRouteRejectsLoginScopedRefresh(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeLogin(t)
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	plan, err := PlanScopeRefresh(p, consent.ScopeZaiAccountUsageSavedLogin, now)
	if err != nil {
		t.Fatal(err)
	}
	if plan.Admitted {
		t.Error("login plan admitted a key route")
	}
	_ = ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now)
	if z.calls.Load() != 0 {
		t.Fatalf("login request sent the API key (%d calls)", z.calls.Load())
	}
	plan, err = PlanScopeRefresh(p, consent.ScopeZaiAccountUsageAPIKey, now)
	if err != nil || !plan.Admitted {
		t.Fatalf("key plan: %+v %v", plan, err)
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now); err != nil {
		t.Fatal(err)
	}
	if z.calls.Load() != 1 {
		t.Fatalf("key requests = %d", z.calls.Load())
	}
}

func TestSampling1122ChangedLoginHidesPriorQuotaBeforeRefresh(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true, jwt: zcodeTestJWT(time.Now().Add(time.Hour))})
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeLogin(t)
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	paths := func() Paths { return ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()) }
	if err := ExecuteScopeRefresh(context.Background(), paths(), consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	if a := zcodeAccount(ReadPermitted(paths(), now)); a == nil || len(a.Windows) == 0 {
		t.Fatalf("fixture has no quota: %+v", a)
	}
	if err := os.WriteFile(filepath.Join(dir, "credentials.json"), []byte(`{"replacement":"new-account"}`), 0600); err != nil {
		t.Fatal(err)
	}
	if a := zcodeAccount(ReadPermitted(paths(), now.Add(time.Minute))); a != nil && len(a.Windows) > 0 {
		t.Fatalf("previous login quota remains: %+v", a)
	}
	if z.calls.Load() != 1 {
		t.Fatalf("unexpected refresh: %d", z.calls.Load())
	}
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true, jwt: zcodeTestJWT(time.Now().Add(time.Hour))})
	if err := ExecuteScopeRefresh(context.Background(), paths(), consent.ScopeZaiAccountUsageSavedLogin, now.Add(20*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if a := zcodeAccount(ReadPermitted(paths(), now.Add(20*time.Minute))); a == nil || len(a.Windows) == 0 || z.calls.Load() != 2 {
		t.Fatalf("new login did not publish a new reading: %+v, calls=%d", a, z.calls.Load())
	}
}

func TestSampling1122ForgetLoginErasesBothCachesAndKeepsBudget(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeLogin(t)
	cache := t.TempDir()
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	before := loadZaiConfigState(cache)
	if before.Good == nil || before.NextAt.IsZero() {
		t.Fatalf("bad fixture: %+v", before)
	}
	s := consent.Capture().State()
	receipt, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "s1122-forget", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Forget: []string{consent.ScopeZaiAccountUsageSavedLogin}}, consent.GrantHooks{Cleanup: func(scope string, forget bool) error { return EraseScope(Paths{Cache: cache}, scope, forget) }})
	if err != nil || receipt.Code != "ok" {
		t.Fatalf("forget: %+v %v", receipt, err)
	}
	after := loadZaiConfigState(cache)
	if after.Good != nil || !after.NextAt.Equal(before.NextAt) {
		t.Fatalf("typed cache or budget: %+v", after)
	}
	native := loadNative(cache)
	if native != nil {
		for _, e := range native.Providers {
			if e.Provider == "zai" && (len(e.Windows) > 0 || e.Admission != nil || e.Plan != "") {
				t.Fatalf("login data left in native cache: %+v", e)
			}
		}
	}
}

func TestSampling1122ForgetLoginPreservesKeyReading(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeLogin(t)
	cache := t.TempDir()
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now); err != nil {
		t.Fatal(err)
	}
	before := loadZaiConfigState(cache)
	if before.Good == nil || before.Good.Admission == nil || before.Good.Admission.Scope != consent.ScopeZaiAccountUsageAPIKey {
		t.Fatalf("bad key fixture: %+v", before)
	}
	s := consent.Capture().State()
	receipt, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "s1122-forget-key", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Forget: []string{consent.ScopeZaiAccountUsageSavedLogin}}, consent.GrantHooks{Cleanup: func(scope string, forget bool) error { return EraseScope(Paths{Cache: cache}, scope, forget) }})
	if err != nil || receipt.Code != "ok" {
		t.Fatalf("forget: %+v %v", receipt, err)
	}
	after := loadZaiConfigState(cache)
	if after.Good == nil || !after.NextAt.Equal(before.NextAt) {
		t.Fatalf("key typed reading lost: %+v", after)
	}
	native := loadNative(cache)
	if native == nil {
		t.Fatal("native key reading lost")
	}
	found := false
	for _, e := range native.Providers {
		if e.Provider == "zai" && e.Admission != nil && e.Admission.Scope == consent.ScopeZaiAccountUsageAPIKey && len(e.Windows) > 0 {
			found = true
		}
	}
	if !found {
		t.Fatal("native key reading lost")
	}
}

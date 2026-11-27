// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestSampling1122ZCodeRefreshRespectsSelectedScope(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true, jwt: zcodeTestJWT(time.Now().Add(time.Hour))})
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
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
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
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

func TestSampling1122ForgetZaiScopeErasesBothCachesAndKeepsBudget(t *testing.T) {
	for _, scope := range []string{consent.ScopeZaiAccountUsageSavedLogin, consent.ScopeZaiAccountUsageAPIKey} {
		t.Run(scope, func(t *testing.T) { testSampling1122ForgetZaiScope(t, scope) })
	}
}

func testSampling1122ForgetZaiScope(t *testing.T, scope string) {
	t.Helper()
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	if scope == consent.ScopeZaiAccountUsageAPIKey {
		writeZCodeProviders(t, home, zcodeTemplateProvider)
	}
	newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
	cache := t.TempDir()
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := ExecuteScopeRefresh(context.Background(), p, scope, now); err != nil {
		t.Fatal(err)
	}
	before := loadZaiConfigState(cache)
	if before.Good == nil || before.Good.Admission == nil || before.Good.Admission.Scope != scope || before.NextAt.IsZero() {
		t.Fatalf("bad fixture: %+v", before)
	}
	next, err := loadReaderAttempt(cache, "zai")
	if err != nil || !next.After(now) {
		t.Fatalf("bad shared-budget fixture: %v, %v", next, err)
	}
	s := consent.Capture().State()
	receipt, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "s1122-forget", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Forget: []string{scope}}, consent.GrantHooks{Cleanup: func(scope string, forget bool) error { return EraseScope(Paths{Cache: cache}, scope, forget) }})
	if err != nil || receipt.Code != "ok" {
		t.Fatalf("forget: %+v %v", receipt, err)
	}
	after := loadZaiConfigState(cache)
	if after.Good != nil || !after.NextAt.Equal(before.NextAt) {
		t.Fatalf("typed cache or budget: %+v", after)
	}
	if after, err := loadReaderAttempt(cache, "zai"); err != nil || !after.Equal(next) {
		t.Fatalf("shared request deadline changed: %v, %v", after, err)
	}
	native := loadNative(cache)
	if native != nil {
		for _, e := range native.Providers {
			if e.Provider == "zai" && (len(e.Windows) > 0 || e.Admission != nil || e.Plan != "") {
				t.Fatalf("forgotten data left in native cache: %+v", e)
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
	p = ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if a := zcodeAccount(ReadPermitted(p, now)); a == nil || len(a.Windows) == 0 {
		t.Fatalf("key reading was not projected after forgetting the login: %+v", a)
	}
}

func TestSampling1122ForgetKeyPreservesLoginReading(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
	cache := t.TempDir()
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	paths := func() Paths { return ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()) }
	if err := ExecuteScopeRefresh(context.Background(), paths(), consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	before := loadZaiConfigState(cache)
	if before.Good == nil || before.NextAt.IsZero() {
		t.Fatalf("bad fixture: %+v", before)
	}
	s := consent.Capture().State()
	receipt, err := consent.ApplyGrant(consent.Path(), consent.Grant{
		RequestID: "sampling-forget-api-key", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation,
		ConsentTextVersion: consent.TextVersion, Forget: []string{consent.ScopeZaiAccountUsageAPIKey},
	}, consent.GrantHooks{Cleanup: func(scope string, forget bool) error { return EraseScope(Paths{Cache: cache}, scope, forget) }})
	if err != nil || receipt.Code != "ok" {
		t.Fatalf("forget: %+v %v", receipt, err)
	}
	after := loadZaiConfigState(cache)
	if after.Good == nil || !after.Good.ObservedAt.Equal(before.Good.ObservedAt) || after.GoodGeneration != before.GoodGeneration || !after.NextAt.Equal(before.NextAt) {
		t.Errorf("saved-login capture or budget changed: %+v", after)
	}
	if a := zcodeAccount(ReadPermitted(paths(), now)); a == nil || len(a.Windows) == 0 || !a.ObservedAt.Equal(before.Good.ObservedAt) {
		t.Errorf("saved-login projection was lost: %+v", a)
	}
	if z.calls.Load() != 1 {
		t.Fatalf("forget or projection made an extra request: %d", z.calls.Load())
	}
}

func TestSampling1122LoginSelectionChangeHidesPriorQuota(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	paths := func() Paths { return ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()) }
	p := paths()
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	if a := zcodeAccount(ReadPermitted(p, now)); a == nil || len(a.Windows) == 0 {
		t.Fatalf("fixture has no quota: %+v", a)
	}
	// Only the selection changes. The registry and credential store still describe the previous login.
	if err := os.WriteFile(filepath.Join(dir, "setting.json"), []byte(`{"providerFamilyDomain":"zai","providerFamilyConnectionSelections":{"zai":{"kind":"start-plan"}}}`), 0600); err != nil {
		t.Fatal(err)
	}
	for _, selected := range []Paths{p, paths()} {
		if a := zcodeAccount(ReadPermitted(selected, now.Add(time.Minute))); a != nil && len(a.Windows) > 0 {
			t.Errorf("previous selection's quota remains: %+v", a)
		}
	}
	if z.calls.Load() != 1 {
		t.Fatalf("cache projection made an extra request: %d", z.calls.Load())
	}
}

func TestSampling1122LoginReplacementBetweenCachePublications(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	fixture := zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}
	writeZCodeLogin(t, home, fixture)
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai", "open.bigmodel.cn")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	paths := func() Paths { return ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()) }
	if err := ExecuteScopeRefresh(context.Background(), paths(), consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	if a := zcodeAccount(ReadPermitted(paths(), now)); a == nil || len(a.Windows) == 0 {
		t.Fatalf("fixture has no quota: %+v", a)
	}

	fixture.family = "bigmodel"
	writeZCodeLogin(t, home, fixture)
	next := now.Add(20 * time.Minute)
	p := paths()
	g := p.ReaderAccess.Grants["zai"]
	publish := g.Publish
	interleaved := false
	g.Publish = func(write func() error) error {
		if err := publish(write); err != nil {
			return err
		}
		if typed := loadZaiConfigState(cache); !interleaved && typed.Good != nil && typed.Good.ObservedAt.Equal(next) {
			interleaved = true
			if a := zcodeAccount(ReadPermitted(paths(), next)); a != nil && len(a.Windows) > 0 {
				t.Errorf("earlier login was visible between cache writes: %+v", a)
			}
		}
		return nil
	}
	p.ReaderAccess.Grants["zai"] = g
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, next); err != nil {
		t.Fatal(err)
	}
	if !interleaved || z.calls.Load() != 2 {
		t.Fatalf("fixture missed the publish interleave: seen=%t, quota requests=%d", interleaved, z.calls.Load())
	}
	if a := zcodeAccount(ReadPermitted(paths(), next)); a == nil || len(a.Windows) == 0 || !a.ObservedAt.Equal(next) {
		t.Fatalf("replacement quota missing after both writes: %+v", a)
	}
}

func samplingDenyZCodeKey(t *testing.T) {
	t.Helper()
	s := consent.Capture().State()
	r, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "sampling-deny-key", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Deny: []string{consent.ScopeZaiAccountUsageAPIKey}}, consent.GrantHooks{Cleanup: func(string, bool) error { return nil }})
	if err != nil || r.Code != "ok" {
		t.Fatalf("deny key: %+v %v", r, err)
	}
}

func TestSampling1122RouteDiscoveryNeverOpensProviderAfterRevocation(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	writeZCodeProviders(t, home, zcodeStaleProviderFiles["no_selection"])
	grantZCodeLogin(t)
	captured := consent.Capture()
	old := zcodeProviderRead
	defer func() { zcodeProviderRead = old }()
	opens := 0
	zcodeProviderRead = func(path string) ([]byte, error) { opens++; return old(path) }
	_ = ProductionPathsWithAdmission(t.TempDir(), "1.0.0", captured)
	if opens != 0 {
		t.Fatalf("route discovery opened provider credentials %d times", opens)
	}
	samplingDenyZCodeKey(t)
	_ = ProductionPathsWithAdmission(t.TempDir(), "1.0.0", captured)
	if opens != 0 {
		t.Fatalf("stale discovery opened provider credentials %d times", opens)
	}
}

func TestSampling1122DeniedKeyStillAdmitsSavedLogin(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "synthetic-denied-environment-key")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	writeZCodeProviders(t, home, zcodeStaleProviderFiles["no_selection"])
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
	samplingDenyZCodeKey(t)
	old := zcodeProviderRead
	defer func() { zcodeProviderRead = old }()
	opens := 0
	zcodeProviderRead = func(path string) ([]byte, error) { opens++; return old(path) }
	p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	selections, err := Selections(p)
	if err != nil {
		t.Fatal(err)
	}
	for _, selection := range selections {
		if selection.Provider == "zai" && (selection.KeyEnv != "" || selection.KeySet) {
			t.Fatal("saved-login selection used a denied environment key")
		}
	}
	now := time.Now()
	keyPlan, err := PlanScopeRefresh(p, consent.ScopeZaiAccountUsageAPIKey, now)
	if err != nil || keyPlan.Admitted {
		t.Fatalf("denied key plan: %+v %v", keyPlan, err)
	}
	loginPlan, err := PlanScopeRefresh(p, consent.ScopeZaiAccountUsageSavedLogin, now)
	if err != nil || !loginPlan.Admitted {
		t.Fatalf("saved-login plan: %+v %v", loginPlan, err)
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now); err == nil {
		t.Fatal("denied API-key refresh succeeded")
	}
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatalf("saved login refresh: %v", err)
	}
	if opens != 0 || z.calls.Load() != 1 {
		t.Fatalf("provider opens %d, quota calls %d; want 0 and 1", opens, z.calls.Load())
	}
	if got := (<-z.seen).Header.Get("Authorization"); got != "Bearer "+zcodeAccountCanary {
		t.Fatal("saved-login refresh did not use the saved-login route")
	}
}

// A keyless file is classified only by an admitted refresh. The next plan can
// then select the independent saved-login scope without reading during discovery.
func TestSampling1122KeylessRouteResolvesUnderReaderLock(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	writeZCodeProviders(t, home, zcodeStaleProviderFiles["no_selection"])
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow") // D380: both choices; every store waits for the Keychain one
	cache := t.TempDir()
	now := time.Now()
	paths := func() Paths { return ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()) }
	p := paths()
	_ = ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageAPIKey, now)
	if z.calls.Load() != 0 {
		t.Fatal("key-scoped refresh sent the saved login")
	}
	p = paths()
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	if z.calls.Load() != 1 {
		t.Fatalf("saved-login quota calls = %d", z.calls.Load())
	}
}

package quota

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Review macrev2-1284 (owner build-6 #1). Invariant: a retained ZCode reading is dropped only when
// the signed-in account changes.

func review1284JWT(sub string, exp time.Time) string {
	enc := base64.RawURLEncoding.EncodeToString
	payload, _ := json.Marshal(map[string]any{"exp": exp.Unix(), "sub": sub})
	return enc([]byte(`{"alg":"none","typ":"JWT"}`)) + "." + enc(payload) + ".c2lnLWNhbmFyeQ"
}

func review1284Edit(t *testing.T, dir, name string, edit func(map[string]any)) {
	t.Helper()
	path := filepath.Join(dir, name)
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var doc map[string]any
	if err := json.Unmarshal(b, &doc); err != nil {
		t.Fatal(err)
	}
	edit(doc)
	out, _ := json.Marshal(doc)
	if err := os.WriteFile(path, out, 0o600); err != nil {
		t.Fatal(err)
	}
}

func review1284Shown(t *testing.T, cache string, at time.Time) bool {
	t.Helper()
	r, _, _ := zcodeReport(t, cache, at)
	a := zcodeAccount(r)
	return a != nil && len(a.Windows) > 0
}

// macrev2-1284-1: an inactive provider entry changing, the same profile resealed with a fresh nonce
// and a provider file caught mid-write all keep the last good reading, with no extra fetch.
func TestReview1284SameAccountKeepsReading(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow")
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	if err := ExecuteScopeRefresh(context.Background(), ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	if !review1284Shown(t, cache, now) {
		t.Fatal("fixture has no reading")
	}
	at := now
	steps := []struct {
		name string
		do   func()
	}{
		{"inactive provider entry changed", func() {
			review1284Edit(t, dir, "config.json", func(m map[string]any) {
				m["provider"].(map[string]any)["builtin:zai-start-plan"] = map[string]any{"enabled": false, "options": map[string]any{"apiKey": "other"}}
			})
		}},
		{"inactive provider entry changed again", func() {
			review1284Edit(t, dir, "config.json", func(m map[string]any) {
				m["provider"].(map[string]any)["builtin:zai-start-plan"] = map[string]any{"enabled": true, "systemDisabledReason": "x"}
			})
		}},
		{"same profile resealed", func() {
			review1284Edit(t, dir, "credentials.json", func(m map[string]any) {
				profile, _ := json.Marshal(map[string]any{"user_id": zcodeIdentityCanary})
				m["oauth:zai:user_info"] = zcodeTestEncrypt(t, string(profile), zcodeTestSecret)
			})
		}},
		{"provider file mid-write", func() {
			if err := os.WriteFile(filepath.Join(dir, "config.json"), []byte(`{"provider":{"builtin:zai-cod`), 0o600); err != nil {
				t.Fatal(err)
			}
		}},
		{"credential file mid-write", func() {
			if err := os.WriteFile(filepath.Join(dir, "credentials.json"), []byte(`{"oauth:zai:us`), 0o600); err != nil {
				t.Fatal(err)
			}
		}},
	}
	for _, step := range steps {
		step.do()
		at = at.Add(time.Minute)
		if !review1284Shown(t, cache, at) {
			t.Fatalf("%s: the reading was dropped", step.name)
		}
	}
	if z.calls.Load() != 1 {
		t.Fatalf("extra fetch: %d", z.calls.Load())
	}
}

// macrev2-1284-2: on a Start Plan sign-in named only by its JWT, a different subject hides the
// previous account's reading at once; a refreshed token with the same subject keeps it.
func TestReview1284StartPlanSubject(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "start-plan", jwt: review1284JWT("subject-a", time.Now().Add(time.Hour))})
	review1284Edit(t, dir, "credentials.json", func(m map[string]any) { delete(m, "oauth:zai:user_info") })
	body := `{"code":200,"data":{"plans":[{"name":"ZCode Start Plan","status":"active","plan_id":"p1","entitlements":[{"entitlement_id":"e1","period":"daily"}]}],
	 "balances":[{"entitlement_id":"e1","plan_id":"p1","show_name":"GLM-5.3","total_units":1000,"used_units":250,"remaining_units":750,"expires_at":` + jsonInt(time.Now().Add(6*time.Hour).Unix()) + `}]}}`
	z := newZCodeServer(t, body, 200, "zcode.z.ai")
	grantZCodeKeychain(t, "allow")
	now := time.Now().UTC()
	cache := t.TempDir()
	if err := ExecuteScopeRefresh(context.Background(), ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	if !review1284Shown(t, cache, now) {
		t.Fatal("fixture has no reading")
	}
	setToken := func(sub string, exp time.Time) {
		review1284Edit(t, dir, "credentials.json", func(m map[string]any) {
			m["zcodejwttoken"] = zcodeTestEncrypt(t, review1284JWT(sub, exp), zcodeTestSecret)
		})
	}
	setToken("subject-a", time.Now().Add(3*time.Hour))
	if !review1284Shown(t, cache, now.Add(time.Minute)) {
		t.Fatal("a refreshed token for the same subject dropped the reading")
	}
	setToken("subject-b", time.Now().Add(3*time.Hour))
	if review1284Shown(t, cache, now.Add(2*time.Minute)) {
		t.Fatal("the previous account's reading is shown for a different subject")
	}
	if z.calls.Load() != 1 {
		t.Fatalf("extra fetch: %d", z.calls.Load())
	}
	assertNoZCodeSecret(t, cache)
}

// A Keychain-bound (enc:v2:os) store opens only inside a read. The read records which account its
// sealed values name, so later projections keep the reading through rewrites that keep them; a
// reseal the projection cannot open holds the reading back until a read settles it, and that read
// files the result under the same account.
func TestReview1284KeychainStoreResolvedByRead(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	key, encoded := zcodeTestKey(t)
	dir := writeZCodeKeychainLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true}, key)
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow")
	fake := &fakeKeychain{value: encoded}
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	refresh := func(at time.Time) {
		t.Helper()
		p := WithZCodeKeychain(ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()), fake.key)
		if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, at); err != nil {
			t.Fatal(err)
		}
	}
	refresh(now)
	if !review1284Shown(t, cache, now) {
		t.Fatal("first read not shown (unresolved generation not settled by the read)")
	}
	later := time.Now().Add(time.Hour)
	for _, name := range []string{"setting.json", "config.json", "credentials.json", "telemetry-state.json"} {
		_ = os.Chtimes(filepath.Join(dir, name), later, later)
	}
	if !review1284Shown(t, cache, now.Add(time.Minute)) {
		t.Fatal("a touch dropped the reading")
	}
	review1284Edit(t, dir, "credentials.json", func(m map[string]any) {
		profile, _ := json.Marshal(map[string]any{"user_id": zcodeIdentityCanary})
		m["oauth:zai:user_info"] = zcodeTestEncryptV2(t, string(profile), key)
	})
	if review1284Shown(t, cache, now.Add(2*time.Minute)) {
		t.Fatal("an unopened reseal was trusted as the same account")
	}
	refresh(now.Add(20 * time.Minute))
	if !review1284Shown(t, cache, now.Add(21*time.Minute)) || z.calls.Load() != 2 {
		t.Fatalf("the settling read did not restore the reading (calls %d)", z.calls.Load())
	}
	assertNoD380Secret(t, cache, encoded)
}

// macrev2-1284-4: without the installation key (its creation lock is held) no generation is emitted
// or remembered; once the key exists, two installations get distinct keyed generations.
func TestReview1284NoUnkeyedGeneration(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true})
	grantZCodeKeychain(t, "allow")
	caches := []string{t.TempDir(), t.TempDir()}
	for _, cache := range caches {
		lock := filepath.Join(cache, "observed", "subscriptions.lock")
		if err := os.MkdirAll(filepath.Dir(lock), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(lock, nil, 0o600); err != nil {
			t.Fatal(err)
		}
		if s := zcodeLoginStamp(cache, dir); s != "" {
			t.Fatalf("stamp without the installation key: %q", s)
		}
		if _, ok := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()).ReaderAccessGrant("zai"); ok {
			t.Fatal("route admitted with an unkeyed generation")
		}
		if _, err := os.Stat(zcodeStampPath(cache)); !os.IsNotExist(err) {
			t.Fatal("something was remembered without the key")
		}
		_ = os.Remove(lock)
	}
	a, b := zcodeLoginStamp(caches[0], dir), zcodeLoginStamp(caches[1], dir)
	if a == "" || b == "" || a == b {
		t.Fatalf("keyed generations %q %q", a, b)
	}
}

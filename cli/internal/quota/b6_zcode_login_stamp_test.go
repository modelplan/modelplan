package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Owner build-6 #1: ZCode rewrites telemetry-state.json (and other state) all the time while it
// runs. A reading is dropped only when the signed-in account changes, so none of these rewrites
// may take the last good reading away.
func TestB6ZCodeStateRewritesKeepTheReading(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true, deviceMid: true, jwt: zcodeTestJWT(time.Now().Add(time.Hour))})
	z := newZCodeServer(t, zcodeQuotaBody, 200, "api.z.ai")
	grantZCodeKeychain(t, "allow")
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	paths := func() Paths { return ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture()) }
	if err := ExecuteScopeRefresh(context.Background(), paths(), consent.ScopeZaiAccountUsageSavedLogin, now); err != nil {
		t.Fatal(err)
	}
	reading := func(step string, at time.Time) {
		t.Helper()
		r, s, _ := zcodeReport(t, cache, at)
		if a := zcodeAccount(r); a == nil || len(a.Windows) == 0 {
			t.Fatalf("%s: the reading was dropped: source %+v", step, s)
		}
	}
	reading("first read", now)
	before := zcodeLoginStamp(cache, dir)
	later := time.Now().Add(time.Hour)
	touch := func(name string) {
		t.Helper()
		later = later.Add(time.Second)
		if err := os.Chtimes(filepath.Join(dir, name), later, later); err != nil {
			t.Fatal(err)
		}
	}
	rewrite := func(name string, edit func(map[string]any)) {
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
		touch(name)
	}
	at := now
	for _, step := range []struct {
		name string
		do   func()
	}{
		{"telemetry-state.json touched", func() { touch("telemetry-state.json") }},
		{"telemetry-state.json rewritten", func() {
			rewrite("telemetry-state.json", func(m map[string]any) { m["lastFlushAt"] = later.UnixMilli(); m["events"] = 42 })
		}},
		{"telemetry-state.json removed", func() { _ = os.Remove(filepath.Join(dir, "telemetry-state.json")) }},
		{"setting.json touched", func() { touch("setting.json") }},
		{"setting.json unrelated preference", func() {
			rewrite("setting.json", func(m map[string]any) { m["windowBounds"] = map[string]any{"w": 1200} })
		}},
		{"config.json touched", func() { touch("config.json") }},
		{"credentials.json token refreshed", func() {
			rewrite("credentials.json", func(m map[string]any) {
				m["zcodejwttoken"] = zcodeTestEncrypt(t, zcodeTestJWT(time.Now().Add(2*time.Hour)), zcodeTestSecret)
			})
		}},
	} {
		step.do()
		at = at.Add(time.Minute)
		if got := zcodeLoginStamp(cache, dir); got != before {
			t.Fatalf("%s changed the sign-in generation", step.name)
		}
		reading(step.name, at)
	}
	if z.calls.Load() != 1 {
		t.Fatalf("cache projection made extra requests: %d", z.calls.Load())
	}
	// A different signed-in account still invalidates the reading at once.
	rewrite("setting.json", func(m map[string]any) {
		m["providerFamilyConnectionSelections"] = map[string]any{"zai": map[string]any{"kind": "start-plan"}}
	})
	if zcodeLoginStamp(cache, dir) == before {
		t.Fatal("a changed selection kept the generation")
	}
	if a := zcodeAccount(ReadPermitted(paths(), at.Add(time.Minute))); a != nil && len(a.Windows) > 0 {
		t.Fatalf("previous account's quota remains: %+v", a)
	}
	assertNoZCodeSecret(t, cache)
}

// The generation is a keyed hash: no credential, identity or file content appears in it.
func TestB6ZCodeLoginStampCarriesNoSecret(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	dir := writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: "individual-coding-plan", accountKey: true, deviceMid: true, jwt: zcodeTestJWT(time.Now().Add(time.Hour))})
	cache := t.TempDir()
	stamp := zcodeLoginStamp(cache, dir)
	if len(stamp) != 64 {
		t.Fatalf("stamp %q is not a hash", stamp)
	}
	assertNoZCodeSecret(t, cache, stamp)
	other := t.TempDir()
	if zcodeLoginStamp(other, dir) == stamp {
		t.Fatal("stamp is not keyed by the installation")
	}
}

// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"sync"
	"testing"
	"time"
)

// Synthetic keys only. Never a real one.
const (
	fakeZaiKey   = "fake-zai-key-0001"
	fakeOtherKey = "fake-other-key-0002"
	fakeGoKey    = "fake-opencode-key-0003"
)

const zaiOKBody = `{"code":200,"success":true,"data":{"planName":"GLM Coding Pro","limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":61}]}}`
const goOKBody = `{"usage":{"rolling":{"usagePercent":12,"resetInSec":600},"weekly":{"usagePercent":40,"resetInSec":86400}}}`

type keyServer struct {
	mu   sync.Mutex
	auth []string
	body string // 200 body; empty with status set answers the status alone
	code int
	// bodyFor, when set, answers per Authorization header (a refused detected key, a working manual key).
	bodyFor map[string]string
}

func (k *keyServer) serve(t *testing.T) *httptest.Server {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		k.mu.Lock()
		k.auth = append(k.auth, r.Header.Get("Authorization"))
		k.mu.Unlock()
		if b, ok := k.bodyFor[r.Header.Get("Authorization")]; ok {
			w.Write([]byte(b))
			return
		}
		if k.code != 0 && k.code != 200 {
			w.WriteHeader(k.code)
			return
		}
		w.Write([]byte(k.body))
	}))
	t.Cleanup(srv.Close)
	return srv
}

func (k *keyServer) seen() []string {
	k.mu.Lock()
	defer k.mu.Unlock()
	return append([]string(nil), k.auth...)
}

func useClient(t *testing.T, srv *httptest.Server, hosts ...string) {
	old := nativeClient
	nativeClient = readerFixtureClient(t, srv, hosts...)
	t.Cleanup(func() { nativeClient = old })
}

func TestManualKeyFileIs0600AndHoldsOneEntryPerProvider(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "support")
	if err := SetManualKey(dir, "zai", "  "+fakeZaiKey+"\n", "china"); err != nil {
		t.Fatal(err)
	}
	if err := SetManualKey(dir, "opencodego", fakeGoKey, ""); err != nil {
		t.Fatal(err)
	}
	fi, err := os.Stat(ManualKeyPath(dir))
	if err != nil || fi.Mode().Perm() != 0o600 {
		t.Fatalf("file mode = %v, %v", fi, err)
	}
	if k, ok := loadManualKey(dir, "zai"); !ok || k.Key != fakeZaiKey || k.Region != "china" {
		t.Fatalf("zai entry = %+v %v", k, ok)
	}
	if k, ok := loadManualKey(dir, "opencodego"); !ok || k.Key != fakeGoKey || k.Region != "" {
		t.Fatalf("go entry = %+v %v", k, ok)
	}
	entries, _ := os.ReadDir(dir)
	if len(entries) != 2 { // the key file and observed/ (key generations)
		t.Fatalf("temporary files left behind: %v", entries)
	}
	if err := RemoveManualKey(dir, "zai"); err != nil || ManualKeyPresent(dir, "zai") || !ManualKeyPresent(dir, "opencodego") {
		t.Fatal("remove must drop only zai")
	}
	if err := RemoveManualKey(dir, "opencodego"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(ManualKeyPath(dir)); !os.IsNotExist(err) {
		t.Fatal("an empty set removes the file")
	}
	if err := RemoveManualKey(dir, "zai"); err != nil {
		t.Fatal("removing an absent key succeeds")
	}
}

func TestManualKeyRejectsBadInputWithoutEchoingIt(t *testing.T) {
	dir := t.TempDir()
	for _, c := range []struct{ provider, key, region string }{
		{"zai", "has space inside", "global"}, {"zai", "ctl\x01char", "global"}, {"zai", "", "global"},
		{"zai", fakeZaiKey, "mars"}, {"cursor", fakeZaiKey, ""}, {"zai", strings.Repeat("a", 5000), "global"},
	} {
		err := SetManualKey(dir, c.provider, c.key, c.region)
		if err == nil {
			t.Fatalf("accepted %+v", c)
		}
		if c.key != "" && strings.Contains(err.Error(), c.key) {
			t.Fatal("the error carries the key")
		}
	}
	if _, err := os.Stat(ManualKeyPath(dir)); !os.IsNotExist(err) {
		t.Fatal("nothing may be written")
	}
}

func TestManualKeyFileWithLooseModeIsNotTrusted(t *testing.T) {
	dir := t.TempDir()
	if err := SetManualKey(dir, "zai", fakeZaiKey, "global"); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(ManualKeyPath(dir), 0o644); err != nil {
		t.Fatal(err)
	}
	if ManualKeyPresent(dir, "zai") {
		t.Fatal("a group- or world-readable key file must not be used")
	}
	// A save or removal never replaces it: it may hold the other provider's key.
	if err := SetManualKey(dir, "zai", fakeZaiKey, "global"); !errors.Is(err, ErrManualKeyFileUnsafe) {
		t.Fatalf("set over a loose file = %v", err)
	}
	if err := RemoveManualKey(dir, "zai"); !errors.Is(err, ErrManualKeyFileUnsafe) {
		t.Fatalf("remove over a loose file = %v", err)
	}
	if fi, _ := os.Stat(ManualKeyPath(dir)); fi.Mode().Perm() != 0o644 {
		t.Fatal("the unsafe file must be left untouched")
	}
	// The user fixes the mode; then writes work again.
	if err := os.Chmod(ManualKeyPath(dir), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := SetManualKey(dir, "zai", fakeZaiKey, "global"); err != nil || !ManualKeyPresent(dir, "zai") {
		t.Fatal("not usable after the mode is fixed")
	}
}

func TestManualKeyZaiRegionRouting(t *testing.T) {
	isolateHome(t)
	for _, c := range []struct{ region, host, other string }{{"global", "api.z.ai", "open.bigmodel.cn"}, {"china", "open.bigmodel.cn", "api.z.ai"}} {
		ks := &keyServer{body: zaiOKBody}
		srv := ks.serve(t)
		useClient(t, srv, c.host)
		if got := TestManualKey(context.Background(), nil, "zai", fakeZaiKey, c.region, time.Now()); got != ManualKeyOK {
			t.Fatalf("%s: %s", c.region, got)
		}
		if a := ks.seen(); len(a) != 1 || a[0] != "Bearer "+fakeZaiKey {
			t.Fatalf("%s: requests %v", c.region, a)
		}
		// The other region's host is not allowed by the fixture, so a request there would fail
		// the call: the key went to exactly the chosen region's host.
		useClient(t, srv, c.other)
		if got := TestManualKey(context.Background(), nil, "zai", fakeZaiKey, c.region, time.Now()); got == ManualKeyOK {
			t.Fatalf("%s: the key reached the other region", c.region)
		}
	}
}

func TestManualKeyOutcomes(t *testing.T) {
	isolateHome(t)
	for _, c := range []struct {
		name, provider, host, body string
		code                       int
		want                       string
	}{
		{"zai ok", "zai", "api.z.ai", zaiOKBody, 200, ManualKeyOK},
		{"zai wrong-shape key", "zai", "api.z.ai", "", 401, ManualKeyRefused},
		{"zai unknown key", "zai", "api.z.ai", `{"code":1000,"success":false,"msg":"身份验证失败"}`, 200, ManualKeyRefused},
		{"zai lapsed plan", "zai", "api.z.ai", `{"code":500,"success":false,"msg":"当前用户不存在coding plan"}`, 200, ManualKeyPlanLapsed},
		// main (ff9947be6): any monitor-envelope body code 500 is a key without a Coding Plan.
		{"zai other 500", "zai", "api.z.ai", `{"code":500,"success":false,"msg":"internal error"}`, 200, ManualKeyPlanLapsed},
		{"zai http 500", "zai", "api.z.ai", "", 500, ManualKeyFailed},
		{"go ok", "opencodego", "opencode.ai", goOKBody, 200, ManualKeyOK},
		{"go refused", "opencodego", "opencode.ai", "", 401, ManualKeyRefused},
		{"go no go plan", "opencodego", "opencode.ai", "", 403, ManualKeyPlanLapsed},
	} {
		t.Run(c.name, func(t *testing.T) {
			ks := &keyServer{body: c.body, code: c.code}
			useClient(t, ks.serve(t), c.host)
			if got := TestManualKey(context.Background(), nil, c.provider, fakeZaiKey, "global", time.Now()); got != c.want {
				t.Fatalf("outcome = %s, want %s", got, c.want)
			}
		})
	}
	if got := TestManualKey(context.Background(), nil, "zai", "   ", "global", time.Now()); got != ManualKeyNoKey {
		t.Fatalf("empty = %s", got)
	}
	if got := TestManualKey(context.Background(), nil, "zai", "bad key", "global", time.Now()); got != ManualKeyNotAccepted {
		t.Fatalf("malformed = %s", got)
	}
	if got := TestStoredManualKey(context.Background(), nil, t.TempDir(), "zai", time.Now()); got != ManualKeyNoKey {
		t.Fatalf("no stored key = %s", got)
	}
}

func refreshWith(t *testing.T, p Paths, provider string) (Report, string) {
	t.Helper()
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: provider, Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	if err := RefreshNative(context.Background(), p, now); err != nil {
		t.Fatal(err)
	}
	r := Read(p, now)
	b, _ := json.Marshal(r)
	cache, _ := os.ReadFile(nativePath(p.Cache))
	return r, string(b) + string(cache)
}

// D90, owner decision 2026-11-14: the entered key wins over a detected one and is the only key sent. One row;
// when a different key is also detected ManualKeyOtherKeyFound says so (a boolean, never the key);
// the same key detected and entered is simply one row without the flag.
func TestEnteredKeyWinsAndADifferentDetectedKeyIsFlagged(t *testing.T) {
	for _, c := range []struct {
		name, env string
		other     bool
	}{
		{"different detected key", fakeOtherKey, true},
		{"same key detected and entered", fakeZaiKey, false},
		{"nothing detected", "", false},
	} {
		t.Run(c.name, func(t *testing.T) {
			isolateHome(t)
			ks := &keyServer{body: zaiOKBody}
			useClient(t, ks.serve(t), "api.z.ai", "open.bigmodel.cn")
			p := nativePaths(t)
			t.Setenv("Z_AI_API_KEY", c.env)
			if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "china"); err != nil {
				t.Fatal(err)
			}
			r, out := refreshWith(t, p, "zai")
			if a := ks.seen(); len(a) != 1 || a[0] != "Bearer "+fakeZaiKey {
				t.Fatalf("only the entered key is sent: %v", a)
			}
			if got := ManualKeyOtherKeyFound(p.Cache, "zai"); got != c.other {
				t.Fatalf("OtherKeyFound = %v, want %v", got, c.other)
			}
			n := 0
			for _, s := range r.Sources {
				if s.Source == "native:zai" {
					n++
				}
			}
			if n != 1 {
				t.Fatalf("one GLM row, got %d: %+v", n, r.Sources)
			}
			for _, key := range []string{fakeZaiKey, fakeOtherKey} {
				if strings.Contains(out, key) {
					t.Fatal("a key reached the cache or the report")
				}
			}
		})
	}
	// A refused entered key is not replaced by the detected one (the entered key stays the only source).
	isolateHome(t)
	ks := &keyServer{body: zaiOKBody, bodyFor: map[string]string{"Bearer " + fakeZaiKey: `{"code":1001,"success":false}`}}
	useClient(t, ks.serve(t), "api.z.ai", "open.bigmodel.cn")
	p := nativePaths(t)
	t.Setenv("Z_AI_API_KEY", fakeOtherKey)
	if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "china"); err != nil {
		t.Fatal(err)
	}
	refreshWith(t, p, "zai")
	if a := ks.seen(); len(a) != 1 || a[0] != "Bearer "+fakeZaiKey {
		t.Fatalf("a refused entered key is reported, not swapped: %v", a)
	}
	// Removing the entered key goes back to the detected one, and the flag goes with it.
	if err := RemoveManualKey(p.Cache, "zai"); err != nil {
		t.Fatal(err)
	}
	if ManualKeyOtherKeyFound(p.Cache, "zai") {
		t.Fatal("no entered key, no flag")
	}
	ks2 := &keyServer{body: zaiOKBody}
	useClient(t, ks2.serve(t), "api.z.ai")
	if err := RefreshNative(context.Background(), p, time.Now().Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if a := ks2.seen(); len(a) != 1 || a[0] != "Bearer "+fakeOtherKey {
		t.Fatalf("detected key after removal: %v", a)
	}
}

// macrevd-795-1: the "another key" answer follows the key saved now, not a flag from an older reading.
// Detected B read first; save A -> shown at once; save B (the detected key) -> gone at once; a reading with A
// and then B detected again keeps it right; remove -> gone; the detected key going away -> gone at the next reading.
func TestOtherKeyFoundFollowsTheSavedKey(t *testing.T) {
	isolateHome(t)
	ks := &keyServer{body: zaiOKBody}
	useClient(t, ks.serve(t), "api.z.ai", "open.bigmodel.cn")
	p := nativePaths(t)
	t.Setenv("Z_AI_API_KEY", fakeOtherKey) // detected B
	now := time.Now()
	refreshWith(t, p, "zai")
	if ManualKeyOtherKeyFound(p.Cache, "zai") {
		t.Fatal("no entered key, no line")
	}
	if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil { // A
		t.Fatal(err)
	}
	if !ManualKeyOtherKeyFound(p.Cache, "zai") {
		t.Fatal("A saved while B is detected: the line shows at once")
	}
	if err := SetManualKey(p.Cache, "zai", fakeOtherKey, "global"); err != nil { // the detected key itself
		t.Fatal(err)
	}
	if ManualKeyOtherKeyFound(p.Cache, "zai") {
		t.Fatal("the saved key is the detected one: no line, without waiting for a reading")
	}
	if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
		t.Fatal(err)
	}
	if err := RefreshNative(context.Background(), p, now.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if !ManualKeyOtherKeyFound(p.Cache, "zai") {
		t.Fatal("after a reading with A, B is still detected")
	}
	t.Setenv("Z_AI_API_KEY", "")
	if err := RefreshNative(context.Background(), p, now.Add(2*time.Hour)); err != nil {
		t.Fatal(err)
	}
	if ManualKeyOtherKeyFound(p.Cache, "zai") {
		t.Fatal("no detected key any more: no line")
	}
	t.Setenv("Z_AI_API_KEY", fakeOtherKey)
	if err := RefreshNative(context.Background(), p, now.Add(3*time.Hour)); err != nil {
		t.Fatal(err)
	}
	if err := RemoveManualKey(p.Cache, "zai"); err != nil {
		t.Fatal(err)
	}
	if ManualKeyOtherKeyFound(p.Cache, "zai") {
		t.Fatal("removed: no line")
	}
	b, _ := os.ReadFile(nativePath(p.Cache))
	m, _ := os.ReadFile(subscriptionsPath(p.Cache))
	for _, key := range []string{fakeZaiKey, fakeOtherKey} {
		if strings.Contains(string(b)+string(m), key) {
			t.Fatal("a key reached the cache or the identity map")
		}
	}
}

func TestZaiLapsedPlanAndRefusedKeyDifferInTheReport(t *testing.T) {
	for _, c := range []struct{ body, reason string }{
		{`{"code":500,"success":false,"msg":"当前用户不存在coding plan"}`, "no_plan"},
		{`{"code":1000,"success":false}`, "http_401"},
	} {
		isolateHome(t)
		ks := &keyServer{body: c.body}
		useClient(t, ks.serve(t), "api.z.ai")
		p := nativePaths(t)
		if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
			t.Fatal(err)
		}
		r, out := refreshWith(t, p, "zai")
		found := false
		for _, s := range r.Sources {
			if s.Source == "native:zai" && s.Status == "unavailable" && s.Reason == c.reason {
				found = true
			}
		}
		if !found || strings.Contains(out, fakeZaiKey) {
			t.Fatalf("want reason %s: %+v", c.reason, r.Sources)
		}
	}
}

// openCodeSavedLogin seeds OpenCode's own key store with a synthetic opencode-go credential and an unrelated one:
// auth.json plus a WAL-mode opencode.db with its sidecars. It returns a function that lists every file and its
// bytes, to prove the store is left exactly as it was.
func openCodeSavedLogin(t *testing.T) func() map[string]string {
	t.Helper()
	dir := filepath.Join(t.TempDir(), "xdg")
	store := filepath.Join(dir, "opencode")
	if err := os.MkdirAll(store, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_DATA_HOME", dir)
	auth := `{"opencode-go":{"type":"api","key":"` + fakeGoKey + `"},"other":{"type":"api","key":"fake-unrelated-key"}}`
	if err := os.WriteFile(filepath.Join(store, "auth.json"), []byte(auth), 0o600); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(store, "opencode.db")
	db, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{`CREATE TABLE credential (integration_id TEXT, value TEXT, active INTEGER)`,
		`INSERT INTO credential VALUES ('opencode-go', '{"type":"key","key":"` + fakeGoKey + `"}', 1)`,
		`INSERT INTO credential VALUES ('other-provider', '{"type":"key","key":"fake-unrelated-key"}', 1)`} {
		if _, err := db.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	db.Close()
	if err := os.WriteFile(path+"-wal", nil, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path+"-shm", make([]byte, 32<<10), 0o600); err != nil {
		t.Fatal(err)
	}
	return func() map[string]string {
		out := map[string]string{}
		entries, _ := os.ReadDir(store)
		for _, e := range entries {
			b, _ := os.ReadFile(filepath.Join(store, e.Name()))
			out[e.Name()] = string(b)
		}
		return out
	}
}

// D90 + D230 (owner 2026-11-14): the key the user entered first, then OPENCODE_API_KEY. OpenCode's own saved login is never read,
// copied or sent (detection only checks that it exists), whatever else is or is not set (macrev2-795-10).
func TestOpenCodeGoSourceOrder(t *testing.T) {
	for _, c := range []struct {
		name        string
		manual, env bool
		want        []string
	}{
		{"manual beats env", true, true, []string{"Bearer " + fakeZaiKey}},
		{"manual when no env", true, false, []string{"Bearer " + fakeZaiKey}},
		{"saved login alone sends nothing", false, false, nil},
	} {
		t.Run(c.name, func(t *testing.T) {
			isolateHome(t)
			ks := &keyServer{body: goOKBody}
			useClient(t, ks.serve(t), "opencode.ai")
			p := nativePaths(t)
			t.Setenv("OPENCODE_API_KEY", "")
			files := openCodeSavedLogin(t)
			before := files()
			if c.env {
				t.Setenv("OPENCODE_API_KEY", fakeOtherKey)
			}
			if c.manual {
				if err := SetManualKey(p.Cache, "opencodego", fakeZaiKey, ""); err != nil {
					t.Fatal(err)
				}
			}
			tmp := t.TempDir()
			t.Setenv("TMPDIR", tmp)
			out := ""
			if c.want == nil {
				// No key at all: the refresh has nothing to read (its error is expected); only what it touched matters.
				if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "opencodego", Backend: BackendNative, Enabled: true}); err != nil {
					t.Fatal(err)
				}
				_ = RefreshNative(context.Background(), p, time.Now())
				cache, _ := os.ReadFile(nativePath(p.Cache))
				out = string(cache)
			} else {
				_, out = refreshWith(t, p, "opencodego")
			}
			if got := ks.seen(); !reflect.DeepEqual(got, c.want) {
				t.Fatalf("requests = %v, want %v", got, c.want)
			}
			for _, key := range []string{fakeZaiKey, fakeOtherKey, fakeGoKey} {
				if strings.Contains(out, key) {
					t.Fatal("a key reached the cache or the report")
				}
			}
			if after := files(); !reflect.DeepEqual(before, after) {
				t.Fatal("OpenCode's key store changed")
			}
			if entries, _ := os.ReadDir(tmp); len(entries) != 0 {
				t.Fatalf("ModelPlan wrote %d temporary files while reading", len(entries))
			}
		})
	}
}

func TestRelayBaseURLKeyIsNeverSent(t *testing.T) {
	isolateHome(t)
	ks := &keyServer{body: zaiOKBody}
	srv := ks.serve(t)
	useClient(t, srv, "api.z.ai", "open.bigmodel.cn")
	const relayKey = "fake-relay-token-0004"
	for _, base := range []string{"https://relay.example.test/api/anthropic", "https://api.z.ai/api/paas/v4", "https://api.z.ai.evil.test/api/anthropic"} {
		settings := filepath.Join(t.TempDir(), "settings.json")
		body := `{"env":{"ANTHROPIC_BASE_URL":"` + base + `","ANTHROPIC_AUTH_TOKEN":"` + relayKey + `"}}`
		if err := os.WriteFile(settings, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		ctx := context.WithValue(context.Background(), zaiConfigSourceKey{}, ZaiConfigSource{Tool: "claude-code", SettingsPath: settings})
		e, key := fetchZaiConfigKey(ctx, nativeClient, time.Now())
		if e.Status == "ok" || e.ErrorCode != "region_refused" || key != "" {
			t.Fatalf("%s: %+v key=%q", base, e, key)
		}
		if strings.Contains(e.Error, relayKey) || strings.Contains(e.Error, "relay.example") {
			t.Fatal("the error echoes the key or the address")
		}
	}
	if got := ks.seen(); len(got) != 0 {
		t.Fatalf("a relay key was sent: %v", got)
	}
}

// macrev2-795-11 / glm-795-6: an unsafe saved-key file fails the provider closed; a detected key is not used.
func TestUnsafeSavedKeyFileFailsRefreshClosedWithoutAnyRequest(t *testing.T) {
	isolateHome(t)
	ks := &keyServer{body: zaiOKBody}
	useClient(t, ks.serve(t), "api.z.ai", "open.bigmodel.cn")
	p := nativePaths(t)
	t.Setenv("Z_AI_API_KEY", fakeOtherKey)
	if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(filepath.Join(p.Cache, manualKeyFileName), 0o644); err != nil {
		t.Fatal(err)
	}
	refreshWith(t, p, "zai")
	if a := ks.seen(); len(a) != 0 {
		t.Fatalf("an unsafe saved-key file must send no request with either key: %v", a)
	}
}

// macrevd-795-2 / glm-795-9: the saved-key file check applies only to providers that have a manual key.
func TestUnsafeSavedKeyFileDoesNotAffectProvidersWithoutManualKeys(t *testing.T) {
	dir := t.TempDir()
	if err := SetManualKey(dir, "zai", fakeZaiKey, "global"); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(ManualKeyPath(dir), 0o644); err != nil {
		t.Fatal(err)
	}
	if _, _, err := loadManualKeyChecked(dir, "minimax"); err != nil {
		t.Fatalf("a provider without manual keys must ignore the file: %v", err)
	}
	if _, _, err := loadManualKeyChecked(dir, "zai"); err == nil {
		t.Fatal("zai must still fail closed on an unsafe file")
	}
}

// Post-merge #795 (2): replacing or removing an OpenCode Go key drops its cached reading (it was read with the previous
// key, possibly another account); other providers' readings stay.
func TestReplacingOrRemovingAKeyDropsOnlyThatProvidersCachedReading(t *testing.T) {
	dir := t.TempDir()
	write := func() {
		s := &nativeSnap{SchemaVersion: 1, ObservedAt: time.Now().UTC(), Providers: []codexbarEntry{
			{Provider: "opencodego", Status: "ok", ObservedAt: time.Now().UTC()},
			{Provider: "zai", Status: "ok", ObservedAt: time.Now().UTC()},
		}}
		b, _ := json.Marshal(s)
		if err := os.MkdirAll(filepath.Dir(nativePath(dir)), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(nativePath(dir), b, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	providers := func() map[string]bool {
		out := map[string]bool{}
		if s := loadNative(dir); s != nil {
			for _, e := range s.Providers {
				out[e.Provider] = true
			}
		}
		return out
	}
	write()
	if err := SetManualKey(dir, "opencodego", fakeGoKey, ""); err != nil {
		t.Fatal(err)
	}
	if got := providers(); got["opencodego"] || !got["zai"] {
		t.Fatalf("saving a key must drop only that provider's cached reading: %v", got)
	}
	write()
	if err := RemoveManualKey(dir, "opencodego"); err != nil {
		t.Fatal(err)
	}
	if got := providers(); got["opencodego"] || !got["zai"] {
		t.Fatalf("removing a key must drop only that provider's cached reading: %v", got)
	}
}

// macrev2-993-1 / macrevb-993-1: a read that was already in flight with the old key must not leave its (previous
// account's) reading cached after the key is replaced or removed, with or without a cache present before.
func TestInFlightReadWithTheOldKeyIsNotCachedAfterTheKeyChanges(t *testing.T) {
	for _, change := range []string{"replace", "remove"} {
		for _, seeded := range []bool{true, false} {
			t.Run(change+"/seeded="+map[bool]string{true: "yes", false: "no"}[seeded], func(t *testing.T) {
				isolateHome(t)
				arrived, release := make(chan struct{}, 1), make(chan struct{})
				var once sync.Once
				srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					once.Do(func() { arrived <- struct{}{}; <-release })
					w.Write([]byte(goOKBody))
				}))
				t.Cleanup(srv.Close)
				useClient(t, srv, "opencode.ai")
				p := nativePaths(t)
				if err := SetManualKey(p.Cache, "opencodego", fakeGoKey, ""); err != nil {
					t.Fatal(err)
				}
				if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "opencodego", Backend: BackendNative, Enabled: true}); err != nil {
					t.Fatal(err)
				}
				if seeded {
					s := &nativeSnap{SchemaVersion: 1, ObservedAt: time.Now().UTC(), Providers: []codexbarEntry{{Provider: "opencodego", Status: "ok", ObservedAt: time.Now().UTC()}}}
					b, _ := json.Marshal(s)
					if err := os.MkdirAll(filepath.Dir(nativePath(p.Cache)), 0o700); err != nil {
						t.Fatal(err)
					}
					if err := os.WriteFile(nativePath(p.Cache), b, 0o600); err != nil {
						t.Fatal(err)
					}
				}
				done := make(chan error, 1)
				go func() { done <- RefreshNative(context.Background(), p, time.Now().Add(time.Hour)) }()
				select {
				case <-arrived:
				case <-time.After(10 * time.Second):
					t.Fatal("the read did not start")
				}
				var err error
				if change == "replace" {
					err = SetManualKey(p.Cache, "opencodego", "fake-opencode-key-0009", "")
				} else {
					err = RemoveManualKey(p.Cache, "opencodego")
				}
				if err != nil {
					t.Fatal(err)
				}
				close(release)
				if err := <-done; err != nil {
					t.Fatal(err)
				}
				if s := loadNative(p.Cache); s != nil {
					for _, e := range s.Providers {
						if e.Provider == "opencodego" {
							t.Fatalf("the old key's reading stayed cached after the key %sd: %+v", change, e)
						}
					}
				}
			})
		}
	}
}

// macrev2-993-1 (third round): OpenCode Go is read and finished, a later provider (GLM) is still held, the OpenCode Go key
// changes, then the whole snapshot is published. The finished OpenCode Go reading belongs to the old key and must not be
// published; GLM's, whose key did not change, is.
func TestFinishedReadIsNotPublishedWhenItsKeyChangesWhileALaterProviderIsHeld(t *testing.T) {
	isolateHome(t)
	arrived, release := make(chan struct{}, 1), make(chan struct{})
	var once sync.Once
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Authorization") == "Bearer "+fakeZaiKey {
			once.Do(func() { arrived <- struct{}{}; <-release })
			w.Write([]byte(zaiOKBody))
			return
		}
		w.Write([]byte(goOKBody))
	}))
	t.Cleanup(srv.Close)
	useClient(t, srv, "opencode.ai", "api.z.ai", "open.bigmodel.cn")
	p := nativePaths(t)
	if err := SetManualKey(p.Cache, "opencodego", fakeGoKey, ""); err != nil {
		t.Fatal(err)
	}
	if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
		t.Fatal(err)
	}
	for _, provider := range []string{"opencodego", "zai"} {
		if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: provider, Backend: BackendNative, Enabled: true}); err != nil {
			t.Fatal(err)
		}
	}
	done := make(chan error, 1)
	go func() { done <- RefreshNative(context.Background(), p, time.Now().Add(time.Hour)) }()
	select {
	case <-arrived:
	case <-time.After(10 * time.Second):
		t.Fatal("the held read did not start")
	}
	if err := SetManualKey(p.Cache, "opencodego", "fake-opencode-key-0009", ""); err != nil {
		t.Fatal(err)
	}
	close(release)
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	got := map[string]bool{}
	if s := loadNative(p.Cache); s != nil {
		for _, e := range s.Providers {
			got[e.Provider] = true
		}
	}
	if got["opencodego"] {
		t.Fatal("the old key's finished OpenCode Go reading was published after its key changed")
	}
	if !got["zai"] {
		t.Fatalf("GLM's reading (its key unchanged) should still be published: %v", got)
	}
}

func cachedProviders(t *testing.T, cache string) map[string]bool {
	t.Helper()
	got := map[string]bool{}
	if s := loadNative(cache); s != nil {
		for _, e := range s.Providers {
			got[e.Provider] = true
		}
	}
	return got
}

// macrev2-993-1 (reproduction 1): a reading carried over from the cache (not due) by a refresh that is still waiting for a
// later provider must not be written back after the key was replaced or removed.
func TestCarriedCachedReadingIsNotWrittenBackAfterTheKeyChanges(t *testing.T) {
	for _, change := range []string{"replace", "remove"} {
		t.Run(change, func(t *testing.T) {
			isolateHome(t)
			arrived, release := make(chan struct{}, 1), make(chan struct{})
			var once sync.Once
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				if r.Header.Get("Authorization") == "Bearer "+fakeZaiKey {
					once.Do(func() { arrived <- struct{}{}; <-release })
					w.Write([]byte(zaiOKBody))
					return
				}
				w.Write([]byte(goOKBody))
			}))
			t.Cleanup(srv.Close)
			useClient(t, srv, "opencode.ai", "api.z.ai", "open.bigmodel.cn")
			p := nativePaths(t)
			if err := SetManualKey(p.Cache, "opencodego", fakeGoKey, ""); err != nil {
				t.Fatal(err)
			}
			if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "opencodego", Backend: BackendNative, Enabled: true}); err != nil {
				t.Fatal(err)
			}
			now := time.Now()
			if err := RefreshNative(context.Background(), p, now); err != nil {
				t.Fatal(err)
			}
			if !cachedProviders(t, p.Cache)["opencodego"] {
				t.Fatal("the first refresh did not cache OpenCode Go")
			}
			if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
				t.Fatal(err)
			}
			if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "zai", Backend: BackendNative, Enabled: true}); err != nil {
				t.Fatal(err)
			}
			done := make(chan error, 1)
			go func() { done <- RefreshNative(context.Background(), p, now.Add(time.Minute)) }() // OpenCode Go is not due: carried
			select {
			case <-arrived:
			case <-time.After(10 * time.Second):
				t.Fatal("the held read did not start")
			}
			var err error
			if change == "replace" {
				err = SetManualKey(p.Cache, "opencodego", "fake-opencode-key-0009", "")
			} else {
				err = RemoveManualKey(p.Cache, "opencodego")
			}
			if err != nil {
				t.Fatal(err)
			}
			close(release)
			if err := <-done; err != nil {
				t.Fatal(err)
			}
			if cachedProviders(t, p.Cache)["opencodego"] {
				t.Fatalf("the carried reading of the old key was written back after the key %sd", change)
			}
		})
	}
}

// macrev2-993-1 (reproduction 2): the key changes after the publish compared the generations but before it wrote. Save
// waits for that one write (it never waits for a network read) and its invalidation then removes the written reading.
func TestKeyChangeBetweenThePublishCheckAndTheWriteLeavesNoOldReading(t *testing.T) {
	for _, change := range []string{"replace", "remove"} {
		t.Run(change, func(t *testing.T) {
			isolateHome(t)
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write([]byte(goOKBody)) }))
			t.Cleanup(srv.Close)
			useClient(t, srv, "opencode.ai")
			p := nativePaths(t)
			if err := SetManualKey(p.Cache, "opencodego", fakeGoKey, ""); err != nil {
				t.Fatal(err)
			}
			if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "opencodego", Backend: BackendNative, Enabled: true}); err != nil {
				t.Fatal(err)
			}
			saved := make(chan error, 1)
			nativePublishHook = func() {
				go func() {
					if change == "replace" {
						saved <- SetManualKey(p.Cache, "opencodego", "fake-opencode-key-0009", "")
					} else {
						saved <- RemoveManualKey(p.Cache, "opencodego")
					}
				}()
				select {
				case err := <-saved:
					saved <- err
					t.Error("the key change did not wait for the snapshot write")
				case <-time.After(300 * time.Millisecond):
				}
			}
			t.Cleanup(func() { nativePublishHook = nil })
			if err := RefreshNative(context.Background(), p, time.Now()); err != nil {
				t.Fatal(err)
			}
			if err := <-saved; err != nil {
				t.Fatal(err)
			}
			if cachedProviders(t, p.Cache)["opencodego"] {
				t.Fatalf("the old key's reading stayed cached after the key %sd between the check and the write", change)
			}
		})
	}
}

// macrev2-993-1 (last ordering): a refresh that begins while Save is between removing the cache and bumping the
// generation must not carry the old OpenCode Go reading and write it back. The refresh takes its snapshot under the
// same lock Save holds, so it sees the state before or after the change, never a mix.
func TestRefreshBeginningInTheMiddleOfAKeyChangeDoesNotWriteTheOldReadingBack(t *testing.T) {
	isolateHome(t)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.Write([]byte(goOKBody)) }))
	t.Cleanup(srv.Close)
	useClient(t, srv, "opencode.ai")
	p := nativePaths(t)
	if err := SetManualKey(p.Cache, "opencodego", fakeGoKey, ""); err != nil {
		t.Fatal(err)
	}
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "opencodego", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	if err := RefreshNative(context.Background(), p, now); err != nil {
		t.Fatal(err)
	}
	if !cachedProviders(t, p.Cache)["opencodego"] {
		t.Fatal("the first refresh did not cache OpenCode Go")
	}
	refreshed := make(chan error, 1)
	manualKeyChangeHook = func() {
		go func() { refreshed <- RefreshNative(context.Background(), p, now.Add(time.Minute)) }() // not due: it carries the cache
		time.Sleep(300 * time.Millisecond)
	}
	t.Cleanup(func() { manualKeyChangeHook = nil })
	if err := SetManualKey(p.Cache, "opencodego", "fake-opencode-key-0009", ""); err != nil {
		t.Fatal(err)
	}
	if err := <-refreshed; err != nil {
		t.Fatal(err)
	}
	if cachedProviders(t, p.Cache)["opencodego"] {
		t.Fatal("the old key's reading was carried and written back by a refresh that began in the middle of the key change")
	}
}

// After a key replace or remove the reference-only entry has no observation time and no reading: it is "not read yet",
// never "stale" (an age check on a zero ObservedAt), and it keeps its request deadline.
func TestGLMReferenceOnlyEntryIsNotReadYetNotStale(t *testing.T) {
	for _, change := range []string{"replace", "remove"} {
		t.Run(change, func(t *testing.T) {
			isolateHome(t)
			ks := &keyServer{body: zaiOKBody}
			useClient(t, ks.serve(t), "api.z.ai")
			p := nativePaths(t)
			t.Setenv("Z_AI_API_KEY", fakeOtherKey)
			if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
				t.Fatal(err)
			}
			refreshWith(t, p, "zai")
			var err error
			if change == "replace" {
				err = SetManualKey(p.Cache, "zai", "replacement-key", "global")
			} else {
				err = RemoveManualKey(p.Cache, "zai")
			}
			if err != nil {
				t.Fatal(err)
			}
			entry := loadNative(p.Cache).Providers[0]
			if !entry.ObservedAt.IsZero() || entry.NativeNextAttemptAt == nil {
				t.Fatalf("fixture is not a reference-only entry with a deadline: %+v", entry)
			}
			var r Report
			applyNative(&r, p, entry.NativeNextAttemptAt.Add(-time.Minute))
			for _, s := range r.Sources {
				if s.Source != "native:zai" {
					continue
				}
				if s.Status == "stale" || s.ErrorCode == "stale_reading" || s.Status != "missing" || s.Reason != "not read yet" {
					t.Fatalf("reference-only entry reported as %+v", s)
				}
				if loadNative(p.Cache).Providers[0].NativeNextAttemptAt == nil {
					t.Fatal("request deadline lost")
				}
				return
			}
			t.Fatalf("no native:zai source in %+v", r.Sources)
		})
	}
}

func TestGLMKeyChangeClearsReadingKeepsDetectedReference(t *testing.T) {
	for _, change := range []string{"replace", "remove"} {
		t.Run(change, func(t *testing.T) {
			isolateHome(t)
			ks := &keyServer{body: zaiOKBody}
			useClient(t, ks.serve(t), "api.z.ai")
			p := nativePaths(t)
			t.Setenv("Z_AI_API_KEY", fakeOtherKey)
			if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
				t.Fatal(err)
			}
			refreshWith(t, p, "zai")
			before := loadNative(p.Cache).Providers[0]
			if before.Status != "ok" || before.DetectedKeyRef == "" {
				t.Fatalf("missing fixture: %+v", before)
			}
			var err error
			if change == "replace" {
				err = SetManualKey(p.Cache, "zai", "replacement-key", "global")
			} else {
				err = RemoveManualKey(p.Cache, "zai")
			}
			if err != nil {
				t.Fatal(err)
			}
			entries := loadNative(p.Cache).Providers
			if len(entries) != 1 || entries[0].DetectedKeyRef != before.DetectedKeyRef || entries[0].Status == "ok" || len(entries[0].Windows) != 0 || entries[0].SubscriptionRef != "" {
				t.Fatalf("stale reading or missing detected reference: %+v", entries)
			}
			if change == "replace" && !ManualKeyOtherKeyFound(p.Cache, "zai") {
				t.Fatal("lost other-key indication")
			}
		})
	}
}

func TestGLMKeyChangePreservesLegacyDeadline(t *testing.T) {
	for _, status := range []string{"ok", "error"} {
		for _, change := range []string{"replace", "remove"} {
			t.Run(status+"/"+change, func(t *testing.T) {
				isolateHome(t)
				ks := &keyServer{body: zaiOKBody}
				useClient(t, ks.serve(t), "api.z.ai")
				p := nativePaths(t)
				t.Setenv("Z_AI_API_KEY", fakeOtherKey)
				if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
					t.Fatal(err)
				}
				if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "zai", Backend: BackendNative, Enabled: true}); err != nil {
					t.Fatal(err)
				}
				at := time.Now().UTC().Truncate(time.Second)
				old := codexbarEntry{Provider: "zai", Status: status, ObservedAt: at, DetectedKeyRef: "detected-ref"}
				data, _ := json.Marshal(nativeSnap{SchemaVersion: 1, Providers: []codexbarEntry{old}})
				if err := os.WriteFile(nativePath(p.Cache), data, 0600); err != nil {
					t.Fatal(err)
				}
				wait := NativeEvery
				if status != "ok" {
					wait = nativeRetryAfter
				}
				if change == "replace" {
					if err := SetManualKey(p.Cache, "zai", "replacement-key", "global"); err != nil {
						t.Fatal(err)
					}
				} else if err := RemoveManualKey(p.Cache, "zai"); err != nil {
					t.Fatal(err)
				}
				before := at.Add(wait - time.Second)
				if NativeDue(p, before) {
					t.Fatal("key change erased the legacy deadline")
				}
				if err := RefreshNative(context.Background(), p, before); err != nil {
					t.Fatal(err)
				}
				if len(ks.seen()) != 0 {
					t.Fatal("request before the original deadline")
				}
				if err := RefreshNative(context.Background(), p, at.Add(wait)); err != nil {
					t.Fatal(err)
				}
				if len(ks.seen()) != 1 {
					t.Fatal("read did not resume at the original deadline")
				}
			})
		}
	}
}

func TestGLMKeyChangeDuringRefreshKeepsDetectedReference(t *testing.T) {
	for _, change := range []string{"replace", "remove"} {
		t.Run(change, func(t *testing.T) {
			isolateHome(t)
			arrived, release := make(chan struct{}, 1), make(chan struct{})
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				arrived <- struct{}{}
				<-release
				w.Write([]byte(zaiOKBody))
			}))
			t.Cleanup(srv.Close)
			useClient(t, srv, "api.z.ai")
			p := nativePaths(t)
			if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
				t.Fatal(err)
			}
			if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "zai", Backend: BackendNative, Enabled: true}); err != nil {
				t.Fatal(err)
			}
			seed := &nativeSnap{SchemaVersion: 1, Providers: []codexbarEntry{{Provider: "zai", Status: "ok", DetectedKeyRef: "detected-ref"}}}
			b, _ := json.Marshal(seed)
			if err := os.MkdirAll(filepath.Dir(nativePath(p.Cache)), 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(nativePath(p.Cache), b, 0600); err != nil {
				t.Fatal(err)
			}
			done := make(chan error, 1)
			go func() { done <- RefreshNative(context.Background(), p, time.Now().Add(time.Hour)) }()
			select {
			case <-arrived:
			case <-time.After(10 * time.Second):
				t.Fatal("refresh did not start")
			}
			var err error
			if change == "replace" {
				err = SetManualKey(p.Cache, "zai", "replacement-key", "global")
			} else {
				err = RemoveManualKey(p.Cache, "zai")
			}
			if err != nil {
				close(release)
				t.Fatal(err)
			}
			close(release)
			if err := <-done; err != nil {
				t.Fatal(err)
			}
			entries := loadNative(p.Cache).Providers
			if len(entries) != 1 || entries[0].DetectedKeyRef != "detected-ref" || entries[0].Status == "ok" {
				t.Fatalf("stale reading or lost reference: %+v", entries)
			}

		})
	}
}

func TestGLMKeyChangeCacheFailureKeepsCredential(t *testing.T) {
	for _, change := range []string{"replace", "remove"} {
		t.Run(change, func(t *testing.T) {
			isolateHome(t)
			arrived, release := make(chan struct{}, 1), make(chan struct{})
			released := false
			defer func() {
				writeGLMNativeCache = writeAtomic
				if !released {
					close(release)
				}
			}()
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				arrived <- struct{}{}
				<-release
				w.Write([]byte(goOKBody))
			}))
			t.Cleanup(srv.Close)
			useClient(t, srv, "opencode.ai")
			p := nativePaths(t)
			if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
				t.Fatal(err)
			}
			if err := SetManualKey(p.Cache, "opencodego", fakeGoKey, ""); err != nil {
				t.Fatal(err)
			}
			if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "opencodego", Backend: BackendNative, Enabled: true}); err != nil {
				t.Fatal(err)
			}
			if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "zai", Backend: BackendNative, Enabled: true}); err != nil {
				t.Fatal(err)
			}
			used := 61.0
			at := time.Now().UTC()
			seed := nativeSnap{SchemaVersion: 1, Providers: []codexbarEntry{{Provider: "zai", Source: "api", Plan: "Synthetic old account", Status: "ok", ObservedAt: at, DetectedKeyRef: "detected-ref", SubscriptionRef: "0123456789abcdef", ManualKeyGeneration: manualKeyGenerations(p.Cache)["zai"], Windows: []Window{{Kind: "five_hour", UsedPercent: &used, ObservedAt: at}}}}}
			b, _ := json.Marshal(seed)
			if err := writeAtomic(nativePath(p.Cache), b); err != nil {
				t.Fatal(err)
			}
			visible := false
			for _, a := range Read(p, time.Now()).Accounts {
				if a.Source == "native:zai" {
					visible = true
				}
			}
			if !visible {
				t.Fatal("old GLM reading not visible in fixture")
			}
			done := make(chan error, 1)
			go func() {
				done <- RefreshNativeProviders(context.Background(), p, time.Now().Add(time.Hour), []string{"opencodego"})
			}()
			select {
			case <-arrived:
			case <-time.After(10 * time.Second):
				t.Fatal("old read did not start")
			}
			before := manualKeyGenerations(p.Cache)["zai"]
			writeGLMNativeCache = func(string, []byte) error { return errors.New("synthetic cache write failure") }
			var err error
			if change == "replace" {
				err = SetManualKey(p.Cache, "zai", "replacement-key", "global")
			} else {
				err = RemoveManualKey(p.Cache, "zai")
			}
			writeGLMNativeCache = writeAtomic
			if err == nil {
				t.Fatal("fault was not exercised")
			}
			keys, keyErr := loadManualKeys(p.Cache)
			if keyErr != nil {
				t.Fatal(keyErr)
			}
			if got, ok := keys["zai"]; !ok || got.Key != fakeZaiKey {
				t.Fatal("failed cache clear changed the stored GLM credential")
			}
			after := manualKeyGenerations(p.Cache)["zai"]
			close(release)
			released = true
			select {
			case err := <-done:
				if err != nil {
					t.Fatal(err)
				}
			case <-time.After(10 * time.Second):
				t.Fatal("old read did not finish")
			}
			if after != before {
				t.Fatalf("failed clear changed generation: %d -> %d", before, after)
			}
			entry := loadNative(p.Cache).Providers
			found := false
			for _, e := range entry {
				if e.Provider == "zai" {
					found = true
					if e.DetectedKeyRef != "detected-ref" || e.Status != "ok" {
						t.Fatalf("prior key reading/reference not retained: %+v", e)
					}
				}
			}
			if !found {
				t.Fatal("prior key reading missing")
			}
			visibleAfter := false
			for _, a := range Read(p, time.Now()).Accounts {
				if a.Source == "native:zai" {
					visibleAfter = true
				}
			}
			if !visibleAfter {
				t.Fatal("prior credential's reading is no longer projected")
			}

		})
	}
}

// T5 (post-merge sampling 11-17): a GLM key save or remove rewrites native.json from a copy it read
// earlier. A Forget cleanup that filters native.json in between must not be undone by that write:
// the erased reading (GLM's own detected-key reference, or another tool's whole reading) stays gone.
func TestGLMKeyChangeDoesNotRestoreReadingsAForgetErased(t *testing.T) {
	for _, forgotten := range []string{"zai", "opencodego"} {
		for _, change := range []string{"replace", "remove"} {
			t.Run(forgotten+"/"+change, func(t *testing.T) {
				isolateHome(t)
				p := nativePaths(t)
				if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "global"); err != nil {
					t.Fatal(err)
				}
				used := 40.0
				at := time.Now().UTC()
				seed := nativeSnap{SchemaVersion: 1, ObservedAt: at, Providers: []codexbarEntry{
					{Provider: "zai", Status: "ok", ObservedAt: at, DetectedKeyRef: "detected-ref"},
					{Provider: "opencodego", Status: "ok", ObservedAt: at, Plan: "Synthetic Go", Windows: []Window{{Kind: "weekly", UsedPercent: &used, ObservedAt: at}}},
				}}
				b, _ := json.Marshal(seed)
				if err := os.MkdirAll(filepath.Dir(nativePath(p.Cache)), 0o700); err != nil {
					t.Fatal(err)
				}
				if err := writeAtomic(nativePath(p.Cache), b); err != nil {
					t.Fatal(err)
				}
				// The key change has read native.json and is about to write its copy back. A real Forget
				// cleanup starts now (retrying while the readings are busy, as the app does) and gets a
				// fair chance to finish before the write.
				forgetDone := make(chan error, 1)
				started := false
				writeGLMNativeCache = func(path string, data []byte) error {
					if !started {
						started = true
						go func() {
							deadline := time.Now().Add(10 * time.Second)
							for {
								err := ForgetTool(p, forgotten)
								if err == nil || time.Now().After(deadline) {
									forgetDone <- err
									return
								}
								time.Sleep(10 * time.Millisecond)
							}
						}()
						select {
						case err := <-forgetDone:
							forgetDone <- err
						case <-time.After(300 * time.Millisecond):
						}
					}
					return writeAtomic(path, data)
				}
				defer func() { writeGLMNativeCache = writeAtomic }()
				var err error
				if change == "replace" {
					err = SetManualKey(p.Cache, "zai", "replacement-key", "global")
				} else {
					err = RemoveManualKey(p.Cache, "zai")
				}
				if err != nil {
					t.Fatal(err)
				}
				if !started {
					t.Fatal("key change did not rewrite native.json")
				}
				select {
				case err := <-forgetDone:
					if err != nil {
						t.Fatalf("forget: %v", err)
					}
				case <-time.After(15 * time.Second):
					t.Fatal("forget did not finish")
				}
				s := loadNative(p.Cache)
				if s == nil {
					return
				}
				for _, e := range s.Providers {
					if e.Provider == forgotten {
						t.Fatalf("key change wrote back a reading Forget erased: %+v", e)
					}
				}
			})
		}
	}
}

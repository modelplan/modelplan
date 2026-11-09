// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
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
}

func (k *keyServer) serve(t *testing.T) *httptest.Server {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		k.mu.Lock()
		k.auth = append(k.auth, r.Header.Get("Authorization"))
		k.mu.Unlock()
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
	if len(entries) != 1 {
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
	// A new save replaces it and restores 0600.
	if err := SetManualKey(dir, "zai", fakeZaiKey, "global"); err != nil {
		t.Fatal(err)
	}
	if fi, _ := os.Stat(ManualKeyPath(dir)); fi.Mode().Perm() != 0o600 || !ManualKeyPresent(dir, "zai") {
		t.Fatal("not restored")
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
		{"zai other 500", "zai", "api.z.ai", `{"code":500,"success":false,"msg":"internal error"}`, 200, ManualKeyFailed},
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

func TestManualKeyIsTheFirstSourceForZai(t *testing.T) {
	isolateHome(t)
	ks := &keyServer{body: zaiOKBody}
	useClient(t, ks.serve(t), "open.bigmodel.cn")
	p := nativePaths(t)
	t.Setenv("Z_AI_API_KEY", fakeOtherKey)
	if err := SetManualKey(p.Cache, "zai", fakeZaiKey, "china"); err != nil {
		t.Fatal(err)
	}
	_, out := refreshWith(t, p, "zai")
	if a := ks.seen(); len(a) != 1 || a[0] != "Bearer "+fakeZaiKey {
		t.Fatalf("the manual key must win over the environment: %v", a)
	}
	for _, key := range []string{fakeZaiKey, fakeOtherKey} {
		if strings.Contains(out, key) {
			t.Fatal("a key reached the cache or the report")
		}
	}
	// Removing it falls back to the environment (global host).
	if err := RemoveManualKey(p.Cache, "zai"); err != nil {
		t.Fatal(err)
	}
	ks2 := &keyServer{body: zaiOKBody}
	useClient(t, ks2.serve(t), "api.z.ai")
	if err := RefreshNative(context.Background(), p, time.Now().Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	if a := ks2.seen(); len(a) != 1 || a[0] != "Bearer "+fakeOtherKey {
		t.Fatalf("environment fallback: %v", a)
	}
}

func TestZaiLapsedPlanAndRefusedKeyDifferInTheReport(t *testing.T) {
	for _, c := range []struct{ body, reason string }{
		{`{"code":500,"success":false,"msg":"当前用户不存在coding plan"}`, "http_403"},
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

func TestOpenCodeGoSourceOrder(t *testing.T) {
	login := func(t *testing.T) {
		dir := filepath.Join(t.TempDir(), "xdg")
		if err := os.MkdirAll(filepath.Join(dir, "opencode"), 0o700); err != nil {
			t.Fatal(err)
		}
		t.Setenv("XDG_DATA_HOME", dir)
		auth := `{"opencode-go":{"type":"api","key":"` + fakeGoKey + `"},"other":{"type":"api","key":"fake-unrelated-key"}}`
		if err := os.WriteFile(filepath.Join(dir, "opencode", "auth.json"), []byte(auth), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	run := func(t *testing.T, manual, env, withLogin bool) []string {
		isolateHome(t)
		ks := &keyServer{body: goOKBody}
		useClient(t, ks.serve(t), "opencode.ai")
		p := nativePaths(t)
		t.Setenv("OPENCODE_API_KEY", "")
		if withLogin {
			login(t)
		}
		if env {
			t.Setenv("OPENCODE_API_KEY", fakeOtherKey)
		}
		if manual {
			if err := SetManualKey(p.Cache, "opencodego", fakeZaiKey, ""); err != nil {
				t.Fatal(err)
			}
		}
		_, out := refreshWith(t, p, "opencodego")
		for _, key := range []string{fakeZaiKey, fakeOtherKey, fakeGoKey} {
			if strings.Contains(out, key) {
				t.Fatal("a key reached the cache or the report")
			}
		}
		return ks.seen()
	}
	for _, c := range []struct {
		name               string
		manual, env, login bool
		want               string
	}{
		{"manual beats env and login", true, true, true, fakeZaiKey},
		{"env beats login", false, true, true, fakeOtherKey},
		{"login last", false, false, true, fakeGoKey},
	} {
		t.Run(c.name, func(t *testing.T) {
			if got := run(t, c.manual, c.env, c.login); len(got) != 1 || got[0] != "Bearer "+c.want {
				t.Fatalf("requests = %v", got)
			}
		})
	}
	t.Run("no source at all sends nothing", func(t *testing.T) {
		isolateHome(t)
		ks := &keyServer{body: goOKBody}
		useClient(t, ks.serve(t), "opencode.ai")
		p := nativePaths(t)
		t.Setenv("OPENCODE_API_KEY", "")
		if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "opencodego", Backend: BackendNative, Enabled: true}); err != nil {
			t.Fatal(err)
		}
		_ = RefreshNative(context.Background(), p, time.Now())
		if got := ks.seen(); len(got) != 0 {
			t.Fatalf("requests = %v", got)
		}
	})
}

func TestOpenCodeLoginV2SQLite(t *testing.T) {
	isolateHome(t)
	dir := filepath.Join(t.TempDir(), "xdg")
	if err := os.MkdirAll(filepath.Join(dir, "opencode"), 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_DATA_HOME", dir)
	db, err := sql.Open("sqlite", filepath.Join(dir, "opencode", "opencode.db"))
	if err != nil {
		t.Fatal(err)
	}
	for _, q := range []string{
		`CREATE TABLE credential (integration_id TEXT, value TEXT, active INTEGER)`,
		`INSERT INTO credential VALUES ('opencode', '{"type":"key","key":"fake-generic-key"}', 1)`,
		`INSERT INTO credential VALUES ('opencode-go', '{"type":"key","key":"` + fakeGoKey + `"}', 1)`,
		`INSERT INTO credential VALUES ('opencode-go', '{"type":"key","key":"fake-inactive-key"}', 0)`,
	} {
		if _, err := db.Exec(q); err != nil {
			t.Fatal(err)
		}
	}
	db.Close()
	now := time.Now()
	if k, code := opencodeLoginKey(context.Background(), now); k != fakeGoKey || code != "" {
		t.Fatalf("v2 login = %q %q", k, code)
	}
	// Two active rows for the same integration are ambiguous.
	db, _ = sql.Open("sqlite", filepath.Join(dir, "opencode", "opencode.db"))
	db.Exec(`INSERT INTO credential VALUES ('opencode-go', '{"type":"key","key":"fake-second-key"}', 1)`)
	db.Close()
	if k, code := opencodeLoginKey(context.Background(), now); k != "" || code != "unsupported_login" {
		t.Fatalf("ambiguous = %q %q", k, code)
	}
	// An expired OAuth token is refused.
	db, _ = sql.Open("sqlite", filepath.Join(dir, "opencode", "opencode.db"))
	db.Exec(`DELETE FROM credential`)
	db.Exec(`INSERT INTO credential VALUES ('opencode-go', '{"type":"oauth","access":"fake-access","expires":1000}', 1)`)
	db.Close()
	if k, code := opencodeLoginKey(context.Background(), now); k != "" || code != "unsupported_login" {
		t.Fatalf("expired = %q %q", k, code)
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

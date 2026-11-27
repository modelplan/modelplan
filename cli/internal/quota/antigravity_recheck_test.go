package quota

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// Owner build-6 report 2026-11-27 item #13: "not running" is re-checked quickly and never backs off.
func TestAntigravityNotRunningRechecksWithoutBackoff(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	old := antigravityCommand
	t.Cleanup(func() { antigravityCommand = old })
	calls := 0
	antigravityCommand = func(context.Context, string, ...string) ([]byte, error) { calls++; return nil, nil }
	ctx := WithAntigravityAccess(context.Background(), AntigravityAccess{Allowed: true})
	t0 := now
	for i := 0; i < 6; i++ { // many misses in a row: still no growing wait
		at := t0.Add(time.Duration(i) * 2 * antigravityRecheck)
		collectAntigravity(ctx, nil, cache, at)
	}
	if calls != 6 {
		t.Fatalf("each re-check after %v must probe again: %d probes", antigravityRecheck, calls)
	}
	s := loadAntigravityState(cache)
	if s.Failures != 0 || s.Availability != "not_detected" || s.NextAt.Sub(s.AttemptAt) != antigravityRecheck {
		t.Fatalf("not running is not a failure: %+v", s)
	}
	// Inside the short gate nothing is probed.
	collectAntigravity(ctx, nil, cache, t0.Add(10*antigravityRecheck+antigravityRecheck/2))
	if calls != 6 {
		t.Fatalf("probed inside the gate: %d", calls)
	}
}

func TestAntigravityRetryBypassesNotRunningGate(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	old := antigravityCommand
	t.Cleanup(func() { antigravityCommand = old })
	calls := 0
	antigravityCommand = func(context.Context, string, ...string) ([]byte, error) { calls++; return nil, nil }
	a := WithAntigravityAccess(context.Background(), AntigravityAccess{Allowed: true, LoginGeneration: strings.Repeat("a", 64)})
	b := WithAntigravityAccess(context.Background(), AntigravityAccess{Allowed: true, LoginGeneration: strings.Repeat("b", 64)})
	collectAntigravity(a, nil, cache, now)
	collectAntigravity(a, nil, cache, now.Add(time.Second))
	if calls != 1 {
		t.Fatal("gate", calls)
	}
	collectAntigravity(b, nil, cache, now.Add(2*time.Second))
	if calls != 2 {
		t.Fatal("Settings Retry must not wait for the re-check", calls)
	}
}

func TestAntigravityServersTolerateAppPathAndLogUnmatched(t *testing.T) {
	uid := os.Getuid()
	good := "--app_data_dir antigravity --extension_server_port 4242 --csrf_token tok-123"
	raw := fmt.Sprintf("11 %d /Applications/Antigravity.app/Contents/Resources/app/extensions/antigravity/bin/language_server_macos_arm /Applications/Antigravity.app/Contents/Resources/app/extensions/antigravity/bin/language_server_macos_arm %s\n"+
		"12 %d Antigravity /Users/x/Downloads/Antigravity.app/Contents/MacOS/language_server %s\n"+
		"13 %d Antigravity /Applications/Antigravity.app/Contents/MacOS/Antigravity --app_data_dir antigravity --csrf_token SECRET-9\n", uid, good, uid, good, uid)
	t.Setenv("MODELPLAN_DEBUG", "1")
	r, w, _ := os.Pipe()
	oldErr := os.Stderr
	os.Stderr = w
	got := antigravityServers([]byte(raw))
	w.Close()
	os.Stderr = oldErr
	var buf strings.Builder
	b := make([]byte, 4096)
	n, _ := r.Read(b)
	buf.Write(b[:n])
	if len(got) != 2 || got[0].PID != 11 || got[1].PID != 12 {
		t.Fatalf("a language_server under any Antigravity.app path matches: %+v", got)
	}
	out := buf.String()
	if !strings.Contains(out, "pid=13") || strings.Contains(out, "SECRET-9") || strings.Contains(out, "tok-123") {
		t.Fatalf("debug lists the unmatched candidate without argument values: %q", out)
	}
}

const hubToken = "0123456789abcdef0123456789abcdef-abc1"

func hubHome(t *testing.T, name string, d map[string]any, mode os.FileMode) {
	t.Helper()
	home := t.TempDir()
	old := antigravityHome
	t.Cleanup(func() { antigravityHome = old })
	antigravityHome = func() string { return home }
	dir := filepath.Join(home, ".gemini", "antigravity", "daemon")
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	if d == nil {
		return
	}
	b, _ := json.Marshal(d)
	if err := os.WriteFile(filepath.Join(dir, name), b, mode); err != nil {
		t.Fatal(err)
	}
	_ = os.Chmod(filepath.Join(dir, name), mode)
}

func TestAntigravityHubDescriptorIsStrict(t *testing.T) {
	good := map[string]any{"pid": 4242, "httpPort": 5555, "csrfToken": hubToken}
	with := func(k string, v any) map[string]any {
		m := map[string]any{}
		for a, b := range good {
			m[a] = b
		}
		m[k] = v
		return m
	}
	cases := []struct {
		name, file string
		d          map[string]any
		mode       os.FileMode
		ok         bool
	}{
		{"valid", "hub_5555.json", good, 0600, true},
		{"wrong pid", "hub_5555.json", with("pid", 1), 0600, false},
		{"port differs from file name", "hub_5556.json", good, 0600, false},
		{"short token", "hub_5555.json", with("csrfToken", "abc"), 0600, false},
		{"token with other characters", "hub_5555.json", with("csrfToken", strings.Repeat("g", 40)), 0600, false},
		{"group writable", "hub_5555.json", good, 0666, false},
		{"oversize", "hub_5555.json", with("pad", strings.Repeat("x", 5000)), 0600, false},
		{"not a descriptor name", "other.json", good, 0600, false},
	}
	for _, c := range cases {
		hubHome(t, c.file, c.d, c.mode)
		port, token, ok := readAntigravityHubDescriptor(4242)
		if ok != c.ok || ok && (port != 5555 || token != hubToken) {
			t.Errorf("%s: %d %v", c.name, port, ok)
		}
	}
	hubHome(t, "hub_5555.json", nil, 0600)
	dir := filepath.Join(antigravityHome(), ".gemini", "antigravity", "daemon")
	real := filepath.Join(t.TempDir(), "real.json")
	b, _ := json.Marshal(good)
	_ = os.WriteFile(real, b, 0600)
	if os.Symlink(real, filepath.Join(dir, "hub_5555.json")) == nil {
		if _, _, ok := readAntigravityHubDescriptor(4242); ok {
			t.Error("a symlink is not a descriptor")
		}
	}
}

// hubFixture serves GetUserStatus, fakes ps and lsof, and records every command and request.
type hubFixture struct {
	desc     AntigravityServer
	requests atomic.Int32
	execs    []string
	owned    bool
	local    atomic.Int32
	tokenHdr atomic.Value
	summary  string
	methods  []string
}

func newHubFixture(t *testing.T, owned bool) *hubFixture {
	t.Helper()
	h := &hubFixture{owned: owned}
	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h.requests.Add(1)
		h.tokenHdr.Store(r.Header.Get("X-Codeium-Csrf-Token"))
		h.methods = append(h.methods, r.URL.Path[strings.LastIndex(r.URL.Path, "/")+1:])
		if h.summary != "" && strings.HasSuffix(r.URL.Path, "/RetrieveUserQuotaSummary") {
			_, _ = w.Write([]byte(h.summary))
			return
		}
		_, _ = w.Write([]byte(antigravityFixture))
	}))
	srv.Config.ConnState = func(c net.Conn, st http.ConnState) {
		if st == http.StateNew {
			h.local.Store(int32(c.RemoteAddr().(*net.TCPAddr).Port))
		}
	}
	srv.Start()
	t.Cleanup(srv.Close)
	port := srv.Listener.Addr().(*net.TCPAddr).Port
	hubHome(t, fmt.Sprintf("hub_%d.json", port), map[string]any{"pid": 4242, "httpPort": port, "csrfToken": hubToken}, 0600)
	old := antigravityCommand
	t.Cleanup(func() { antigravityCommand = old })
	antigravityCommand = func(_ context.Context, bin string, args ...string) ([]byte, error) {
		h.execs = append(h.execs, bin)
		joined := strings.Join(args, " ")
		switch {
		case strings.HasSuffix(bin, "/ps"):
			return []byte(fmt.Sprintf("4242 %d /Applications/Antigravity.app/Contents/Resources/bin/language_server %s\n", os.Getuid(), antigravityHubPS)), nil
		case strings.Contains(joined, "LISTEN"):
			return []byte(fmt.Sprintf("p4242\nu%d\nn127.0.0.1:%d\n", os.Getuid(), port)), nil
		case strings.Contains(joined, "ESTABLISHED"):
			if !h.owned {
				return []byte("n127.0.0.1:1->127.0.0.1:2\n"), nil
			}
			for i := 0; i < 20 && h.local.Load() == 0; i++ {
				time.Sleep(10 * time.Millisecond)
			}
			return []byte(fmt.Sprintf("n127.0.0.1:%d->127.0.0.1:%d\n", port, h.local.Load())), nil
		}
		return nil, fmt.Errorf("unexpected command")
	}
	return h
}

// Real ps line from Antigravity 2.34 (hub mode): no --csrf_token, no --extension_server_port.
const antigravityHubPS = "/Applications/Antigravity.app/Contents/Resources/bin/language_server --standalone --override_ide_name antigravity --subclient_type hub --override_ide_version 2.34.0 --override_user_agent_name antigravity --https_server_port 0 --app_data_dir antigravity --api_server_url https://generativelanguage.googleapis.com --cloud_code_endpoint https://daily-cloudcode-pa.googleapis.com --enable_sidecars --host_bridge_url=http://127.0.0.1:54028 --read_host_bridge_token_from_stdin"

func TestAntigravityHubReadsThroughDescriptor(t *testing.T) {
	isolateHome(t)
	h := newHubFixture(t, true)
	line := fmt.Sprintf("4242 %d /Applications/Antigravity.app/Contents/Resources/bin/language_server %s\n", os.Getuid(), antigravityHubPS)
	if got := antigravityServers([]byte(line)); len(got) != 1 || !got[0].Hub || got[0].PID != 4242 {
		t.Fatalf("hub line is a hub candidate: %+v", got)
	}
	e := fetchAntigravity(context.Background(), nil, "", "", now)
	if e.Status != "ok" || h.requests.Load() != 2 || h.tokenHdr.Load() != hubToken || strings.Join(h.methods, ",") != "RetrieveUserQuotaSummary,GetUserStatus" {
		t.Fatalf("%+v requests=%d", e, h.requests.Load())
	}
	if b, _ := json.Marshal(e); strings.Contains(string(b), hubToken) {
		t.Fatal("token in output")
	}
	for _, bin := range h.execs {
		if !strings.HasSuffix(bin, "/ps") && !strings.HasSuffix(bin, "/lsof") {
			t.Fatalf("only ps and lsof may run: %v", h.execs)
		}
	}
}

func TestAntigravityHubSendsNothingToAnUnownedSocket(t *testing.T) {
	isolateHome(t)
	h := newHubFixture(t, false)
	e := fetchAntigravity(context.Background(), nil, "", "", now)
	if e.Status != "error" || h.requests.Load() != 0 {
		t.Fatalf("%+v requests=%d", e, h.requests.Load())
	}
	if strings.Contains(e.Error+e.ErrorCode, hubToken) {
		t.Fatal("token in error")
	}
}

// With no readable descriptor the app is running but unreadable: not "not running".
func TestAntigravityHubWithoutDescriptorIsUnsupportedNotMissing(t *testing.T) {
	isolateHome(t)
	h := newHubFixture(t, true)
	hubHome(t, "", nil, 0600) // an empty daemon directory
	e := fetchAntigravity(context.Background(), nil, "", "", now)
	if e.Status != "error" || e.ErrorCode != "unsupported_login" || e.Error != antigravityNext("not_supported_yet") || h.requests.Load() != 0 {
		t.Fatalf("%+v", e)
	}
}

// Fixture shaped like Token Monitor@417f84d2 tests/shared/antigravityProbe.test.js:547-577.
const antigravitySummaryFixture = `{"response":{"groups":[
{"displayName":"Claude and GPT models","buckets":[
 {"bucketId":"3p-weekly","displayName":"Weekly Limit","remaining":{"remainingFraction":0.64},"resetTime":"2026-10-20T00:39:54Z"},
 {"bucketId":"3p-5h","displayName":"Five Hour Limit","remaining":{"remainingFraction":0.73},"resetTime":"2026-10-14T12:52:10Z"}]},
{"displayName":"Gemini Models","buckets":[
 {"bucketId":"gemini-weekly","displayName":"Weekly Limit","remaining":{"case":"remainingFraction","value":0.82}},
 {"bucketId":"gemini-5h","displayName":"Five Hour Limit","remainingFraction":0.91,"description":"Refreshes in four hours."},
 {"bucketId":"gemini-session-history","displayName":"Session History","remainingFraction":0.25}]}]}}`

func TestAntigravityHubPrefersQuotaSummary(t *testing.T) {
	isolateHome(t)
	h := newHubFixture(t, true)
	h.summary = antigravitySummaryFixture
	e := fetchAntigravity(context.Background(), nil, "", "", now)
	if e.Status != "ok" || strings.Join(h.methods, ",") != "RetrieveUserQuotaSummary" {
		t.Fatalf("%+v %v", e, h.methods)
	}
	var got []string
	for _, w := range e.Windows {
		got = append(got, fmt.Sprintf("%s %s %.0f", w.Limit, w.Kind, *w.UsedPercent))
	}
	want := "Gemini five_hour 9,Gemini weekly 18,Claude/GPT five_hour 27,Claude/GPT weekly 36"
	if strings.Join(got, ",") != want {
		t.Fatalf("%v", got)
	}
	// An empty or unusable summary falls back to GetUserStatus, never to a schema error.
	h2 := newHubFixture(t, true)
	h2.summary = `{"response":{"groups":[]}}`
	if e := fetchAntigravity(context.Background(), nil, "", "", now); e.Status != "ok" || strings.Join(h2.methods, ",") != "RetrieveUserQuotaSummary,GetUserStatus" {
		t.Fatalf("%+v %v", e, h2.methods)
	}
}

// macrevb-1282-4: the outer native failure reservation must not hold the 45 s re-check or Settings Retry.
func TestAntigravityNotRunningOuterGatesAllowRecheckAndRetry(t *testing.T) {
	isolateHome(t)
	p := nativePaths(t)
	_ = SetConnection(p.ConnectionsFile, QuotaSource{Provider: "antigravity", Backend: BackendNative, Enabled: true})
	old := antigravityCommand
	t.Cleanup(func() { antigravityCommand = old })
	calls := 0
	antigravityCommand = func(context.Context, string, ...string) ([]byte, error) { calls++; return nil, nil }
	ctx := context.Background()
	if err := RefreshNative(ctx, p, now); err != nil {
		t.Fatal(err)
	}
	if calls != 1 {
		t.Fatal(calls)
	}
	if err := RefreshNative(ctx, p, now.Add(10*time.Second)); err != nil || calls != 1 {
		t.Fatalf("inside the re-check interval nothing is probed: %d %v", calls, err)
	}
	if !NativeDue(p, now.Add(antigravityRecheck+time.Second)) {
		t.Fatal("the planner must see the re-check due after 45 s, not after the 30-minute failure wait")
	}
	if err := RefreshNative(ctx, p, now.Add(antigravityRecheck+time.Second)); err != nil || calls != 2 {
		t.Fatalf("re-check after 45 s: %d %v", calls, err)
	}
	// Settings Retry: a changed login generation is due at once.
	p.ReaderAccess = &ReaderAccess{Grants: map[string]ReaderGrant{"antigravity": {Generation: "g2"}}}
	at := now.Add(antigravityRecheck + 2*time.Second)
	if !antigravityRetryDue(p) || !NativeDue(p, at) {
		t.Fatal("Retry is due immediately")
	}
	// Other providers and other outcomes keep their request limits.
	if nativeRetryAfter != 30*time.Minute || NativeEvery != 10*time.Minute {
		t.Fatal("provider request limits changed")
	}
}

// macrevb-1282-5: the diagnostic never prints an opaque argument value.
func TestAntigravityDebugPrintsNoOpaqueValues(t *testing.T) {
	t.Setenv("MODELPLAN_DEBUG", "1")
	line := fmt.Sprintf("77 %d /opt/x/language_server /opt/x/language_server --csrf_token=OPAQUE-SECRET-1 --weird-flag-OPAQUE-NAME --app_data_dir OPAQUE-DIR /Users/OPAQUE-PATH/x", os.Getuid())
	r, w, _ := os.Pipe()
	oldErr := os.Stderr
	os.Stderr = w
	antigravityServers([]byte(line))
	w.Close()
	os.Stderr = oldErr
	b := make([]byte, 4096)
	n, _ := r.Read(b)
	out := string(b[:n])
	if !strings.Contains(out, "pid=77") || strings.Contains(out, "OPAQUE") || strings.Contains(out, "/Users") {
		t.Fatalf("%q", out)
	}
}

// macrevb-1282-6: an unknown vendor group name is stored and shown as a fixed label only.
func TestAntigravityUnknownGroupNameIsNotStored(t *testing.T) {
	isolateHome(t)
	h := newHubFixture(t, true)
	h.summary = `{"response":{"groups":[{"displayName":"ZZ-UNKNOWN-GROUP-CANARY","buckets":[{"bucketId":"x-5h","displayName":"Five Hour Limit","remainingFraction":0.5,"resetTime":"2026-10-14T12:52:10Z"}]}]}}`
	cache := t.TempDir()
	ctx := WithAntigravityAccess(context.Background(), AntigravityAccess{Allowed: true})
	e := collectAntigravity(ctx, nil, cache, now)
	if e.Status != "ok" || len(e.Windows) != 1 || e.Windows[0].Limit != "Other models" {
		t.Fatalf("%+v", e)
	}
	b, _ := os.ReadFile(antigravityStatePath(cache))
	proj, _ := json.Marshal(ReadAntigravityCache(ctx, cache, now.Add(time.Second)))
	if strings.Contains(string(b), "CANARY") || strings.Contains(string(proj), "CANARY") {
		t.Fatal("unknown vendor group name reached the cache or the projection")
	}
}

// macrevb-1282-7: a descriptor replaced between listing and opening is never admitted.
func TestAntigravityHubDescriptorReplacementIsNotAdmitted(t *testing.T) {
	good := map[string]any{"pid": 4242, "httpPort": 5555, "csrfToken": hubToken}
	for _, swap := range []string{"symlink", "group-writable"} {
		hubHome(t, "hub_5555.json", good, 0600)
		dir := filepath.Join(antigravityHome(), ".gemini", "antigravity", "daemon")
		path := filepath.Join(dir, "hub_5555.json")
		other := filepath.Join(t.TempDir(), "other.json")
		b, _ := json.Marshal(good)
		_ = os.WriteFile(other, b, 0600)
		antigravityBeforeOpen = func(p string) {
			switch swap {
			case "symlink":
				_ = os.Remove(p)
				_ = os.Symlink(other, p)
			default:
				_ = os.Chmod(p, 0666)
			}
		}
		_, _, ok := readAntigravityHubDescriptor(4242)
		antigravityBeforeOpen = nil
		if ok {
			t.Errorf("%s replacement admitted a credential", swap)
		}
		_ = path
	}
}

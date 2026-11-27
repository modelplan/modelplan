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
}

func newHubFixture(t *testing.T, owned bool) *hubFixture {
	t.Helper()
	h := &hubFixture{owned: owned}
	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		h.requests.Add(1)
		h.tokenHdr.Store(r.Header.Get("X-Codeium-Csrf-Token"))
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
	if e.Status != "ok" || h.requests.Load() != 1 || h.tokenHdr.Load() != hubToken {
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

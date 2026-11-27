package quota

import (
	"context"
	"fmt"
	"os"
	"strings"
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

// Real ps line from Antigravity 2.34 (hub mode): no --csrf_token, no --extension_server_port.
const antigravityHubPS = "/Applications/Antigravity.app/Contents/Resources/bin/language_server --standalone --override_ide_name antigravity --subclient_type hub --override_ide_version 2.34.0 --override_user_agent_name antigravity --https_server_port 0 --app_data_dir antigravity --api_server_url https://generativelanguage.googleapis.com --cloud_code_endpoint https://daily-cloudcode-pa.googleapis.com --enable_sidecars --host_bridge_url=http://127.0.0.1:54028 --read_host_bridge_token_from_stdin"

func TestAntigravityHubModeIsUnsupportedNotMissing(t *testing.T) {
	isolateHome(t)
	old := antigravityCommand
	t.Cleanup(func() { antigravityCommand = old })
	line := fmt.Sprintf("4242 %d /Applications/Antigravity.app/Contents/Resources/bin/language_server %s\n", os.Getuid(), antigravityHubPS)
	var execs []string
	antigravityCommand = func(_ context.Context, bin string, args ...string) ([]byte, error) {
		execs = append(execs, bin)
		return []byte(line), nil
	}
	if len(antigravityServers([]byte(line))) != 0 || !antigravityHub([]byte(line)) {
		t.Fatal("hub line is recognised but has no readable token")
	}
	e := fetchAntigravity(context.Background(), nil, "", "", now)
	if e.Status != "error" || e.ErrorCode != "unsupported_login" || e.Error != antigravityNext("not_supported_yet") || e.Error == antigravityNext("not_detected") {
		t.Fatalf("%+v", e)
	}
	if len(execs) != 1 || execs[0] != "/bin/ps" {
		t.Fatalf("only ps may run: %v", execs)
	}
}

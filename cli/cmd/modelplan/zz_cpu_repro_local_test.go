// LOCAL ONLY - do not commit.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"bufio"
	"context"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
)

func procCPU(pid int) time.Duration {
	b, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil {
		return 0
	}
	f := strings.Fields(string(b)[strings.LastIndex(string(b), ")")+2:])
	u, _ := strconv.Atoi(f[11])
	s, _ := strconv.Atoi(f[12])
	return time.Duration(u+s) * 10 * time.Millisecond
}

func seedLargeLogs(t *testing.T, home string) {
	now := time.Now().UTC()
	for d := 0; d < 20; d++ {
		day := now.AddDate(0, 0, -d)
		dir := filepath.Join(home, ".codex", "sessions", day.Format("2006"), day.Format("01"), day.Format("02"))
		os.MkdirAll(dir, 0o700)
		for k := 0; k < 4; k++ {
			var sb strings.Builder
			fmt.Fprintf(&sb, `{"timestamp":%q,"type":"session_meta","payload":{"id":"s-%d-%d"}}`+"\n", day.Format(time.RFC3339), d, k)
			for i := 0; i < 3000; i++ {
				at := day.Add(time.Duration(i) * time.Second).Format(time.RFC3339Nano)
				fmt.Fprintf(&sb, `{"timestamp":%q,"type":"turn_context","payload":{"model":"gpt-5.2"}}`+"\n", at)
				fmt.Fprintf(&sb, `{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"cached_input_tokens":900,"output_tokens":10,"reasoning_output_tokens":4,"total_tokens":1010},"total_token_usage":{"input_tokens":%d,"cached_input_tokens":900,"output_tokens":10,"reasoning_output_tokens":4,"total_tokens":1010}},"rate_limits":{"primary":{"used_percent":12.0,"window_minutes":300,"resets_at":%d},"secondary":{"used_percent":30.0,"window_minutes":10080,"resets_at":%d}}}}`+"\n", at, 1000*i, now.Add(time.Hour).Unix(), now.Add(48*time.Hour).Unix())
			}
			name := fmt.Sprintf("rollout-%s-0000%04d-aaaa-7000-8000-%012d.jsonl", day.Add(time.Duration(k)*time.Minute).Format("2006-01-02T15-04-05"), d*10+k, d*10+k)
			os.WriteFile(filepath.Join(dir, name), []byte(sb.String()), 0o600)
		}
	}
	for p := 0; p < 10; p++ {
		dir := filepath.Join(home, ".claude", "projects", fmt.Sprintf("-synthetic-%d", p))
		os.MkdirAll(dir, 0o700)
		for s := 0; s < 6; s++ {
			var sb strings.Builder
			start := now.Add(-time.Duration(p*6+s) * 6 * time.Hour)
			for i := 0; i < 3000; i++ {
				fmt.Fprintf(&sb, `{"type":"assistant","timestamp":%q,"sessionId":"sess-%d-%d","requestId":"req-%d","message":{"id":"msg_%d","model":"claude-sonnet-4-5-20250929","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_read_input_tokens":900,"cache_creation_input_tokens":20,"output_tokens":10}}}`+"\n", start.Add(time.Duration(i)*time.Second).Format(time.RFC3339Nano), p, s, i, i)
			}
			os.WriteFile(filepath.Join(dir, fmt.Sprintf("session-%d.jsonl", s)), []byte(sb.String()), 0o600)
		}
	}
}

func TestLocalEngineIdleCPU(t *testing.T) {
	if os.Getenv("MP_LOCAL_REPRO") == "" {
		t.Skip()
	}
	home := setupQueryHome(t)
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	seedLargeLogs(t, home)
	now := time.Now()
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		for _, tool := range []string{"codex", "claude"} {
			if err := consent.Set(s, tool, true, "native:"+tool, "native", now.Add(-30*24*time.Hour)); err != nil {
				return err
			}
		}
		s.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		s.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	if p := os.Getenv("MP_PROF_OUT"); p != "" {
		t.Setenv("MP_LOCAL_CPUPROFILE", p)
	}
	c := startLongQueryBinary(t, binary, []string{"rows", "cockpit", "cockpitDetailsV1"})
	c.call("rows/subscribe", map[string]any{})
	pid := c.cmd.Process.Pid
	// settle: first reads, imports
	time.Sleep(40 * time.Second)
	cockpit := os.Getenv("MP_COCKPIT") != ""
	before := procCPU(pid)
	c.notifications = nil
	start := time.Now()
	idle, _ := strconv.Atoi(os.Getenv("MP_IDLE_SECONDS"))
	if idle == 0 {
		idle = 60
	}
	for time.Since(start) < time.Duration(idle)*time.Second {
		if cockpit {
			c.call("cockpit/query", map[string]any{})
			time.Sleep(time.Second)
		} else {
			c.call("diagnostics/get", map[string]any{})
			time.Sleep(5 * time.Second)
		}
	}
	used := procCPU(pid) - before
	wall := time.Since(start)
	methods := map[string]int{}
	for _, n := range c.notifications {
		s := string(n)
		if i := strings.Index(s, `"method":"`); i >= 0 {
			m := s[i+10:]
			methods[m[:strings.Index(m, `"`)]]++
		}
	}
	t.Logf("CPU %v over %v = %.1f%%; notifications %v", used, wall.Round(time.Second), 100*used.Seconds()/wall.Seconds(), methods)
	c.cmd.Process.Signal(syscall.SIGUSR1)
	time.Sleep(time.Second)
}
func startLongQueryBinary(t *testing.T, binary string, capabilities []string, args ...string) *queryBinary {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
	cmd := exec.CommandContext(ctx, binary, append([]string{"app-server"}, args...)...)
	if so := os.Getenv("MP_STRACE"); so != "" {
		cmd = exec.CommandContext(ctx, "strace", append([]string{"-f", "-qq", "-tt", "-o", so, "-e", "trace=openat,unlinkat,renameat,mkdirat", binary, "app-server"}, args...)...)
	}
	in, err := cmd.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	stderr, err := os.CreateTemp(t.TempDir(), "stderr")
	if err != nil {
		t.Fatal(err)
	}
	cmd.Stderr = stderr
	p := &queryBinary{t: t, cmd: cmd, in: in, frames: make(chan []byte, 128), done: make(chan error, 1)}
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	go func() {
		scanner := bufio.NewScanner(out)
		scanner.Buffer(make([]byte, 4096), wire.MaxFrameBytes)
		for scanner.Scan() {
			select {
			case p.frames <- append([]byte(nil), scanner.Bytes()...):
			case <-ctx.Done():
				return
			}
		}
		close(p.frames)
	}()
	go func() { p.done <- cmd.Wait() }()
	t.Cleanup(func() {
		in.Close()
		select {
		case err := <-p.done:
			if err != nil {
				t.Errorf("app-server exit: %v", err)
			}
		case <-time.After(3 * time.Second):
			cmd.Process.Kill()
			<-p.done
			t.Error("app-server failed to stop")
		}
		cancel()
		b, _ := os.ReadFile(stderr.Name())
		stderr.Close()
		if len(b) != 0 {
			t.Errorf("unexpected app-server stderr: %s", b)
		}
	})
	p.initialize = p.call("initialize", map[string]any{"sessionId": "u3c-binary", "protocolVersion": "1.0", "appVersion": "test", "capabilities": capabilities})
	return p
}

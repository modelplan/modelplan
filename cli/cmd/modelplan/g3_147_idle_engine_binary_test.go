// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// collect reads server frames for d and returns the notifications among them.
func (p *queryBinary) collect(d time.Duration) []string {
	p.t.Helper()
	var methods []string
	deadline := time.After(d)
	for {
		select {
		case raw, ok := <-p.frames:
			if !ok {
				p.t.Fatal("app-server stdout closed")
			}
			var msg struct {
				Method string `json:"method"`
			}
			if json.Unmarshal(raw, &msg) == nil && msg.Method != "" {
				methods = append(methods, msg.Method)
			}
		case <-deadline:
			return methods
		}
	}
}

// G3-147 (WP-17), through the real app-server: an idle engine with unchanged inputs does no
// repeated parsing and publishes nothing. On the owner's Mac the engine held 150-215% CPU:
// each snapshot's identity reads created and removed a lock file in the observed directory the
// engine watches, so every snapshot started the next, and the reader sources came out in map
// order, so every snapshot was published as a change.
func TestG3147IdleAppServerPublishesNothing(t *testing.T) {
	if testing.Short() {
		t.Skip("starts the real app-server for about 25 s")
	}
	// One time zone, and an idle window clear of midnight: the day rollover is a scheduled
	// republication (Today totals start over), not an idle one.
	t.Setenv("TZ", "UTC")
	home := setupQueryHome(t)
	now := time.Now().UTC()
	// A Claude Code log whose responses predate the recording start, and a Codex rollout.
	claude := filepath.Join(home, ".claude", "projects", "-synthetic", "session.jsonl")
	codex := filepath.Join(home, ".codex", "sessions", now.Format("2006"), now.Format("01"), now.Format("02"), "rollout-g3147.jsonl")
	var c, x strings.Builder
	for i := 0; i < 200; i++ {
		at := now.Add(-72*time.Hour + time.Duration(i)*time.Second).Format(time.RFC3339Nano)
		fmt.Fprintf(&c, `{"type":"assistant","timestamp":%q,"sessionId":"synthetic","requestId":"req-%d","message":{"id":"msg_%d","model":"claude-sonnet-4-5-20250929","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_read_input_tokens":900,"output_tokens":10}}}`+"\n", at, i, i)
		at = now.Add(-2*time.Hour + time.Duration(i)*time.Second).Format(time.RFC3339Nano)
		fmt.Fprintf(&x, `{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"output_tokens":10},"total_token_usage":{"input_tokens":%d,"output_tokens":%d}}}}`+"\n", at, 100*(i+1), 10*(i+1))
	}
	for path, body := range map[string]string{claude: c.String(), codex: x.String()} {
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		old := now.Add(-time.Hour)
		if err := os.Chtimes(path, old, old); err != nil {
			t.Fatal(err)
		}
	}
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
		t.Fatalf("build: %v: %s", err, raw)
	}
	p := startQueryBinaryFor(t, 60*time.Second, binary, []string{"rows"})
	p.call("rows/subscribe", map[string]any{})

	// Settle: the first reads and the first observation (2.5 s after start) may publish.
	started := time.Now()
	for quiet := 0; quiet < 3; {
		if time.Since(started) > 20*time.Second {
			t.Fatal("the app-server never went quiet after start")
		}
		if n := len(p.collect(time.Second)); n == 0 && time.Since(started) > 5*time.Second {
			quiet++
		} else if n != 0 {
			quiet = 0
		}
	}
	if untilMidnight := time.Until(time.Now().UTC().Truncate(24 * time.Hour).Add(24 * time.Hour)); untilMidnight < 10*time.Second {
		p.collect(untilMidnight + 3*time.Second) // let the rollover's publication pass
	}
	observed := filepath.Join(home, "cache", "observed")
	before, err := os.Stat(observed)
	if err != nil {
		t.Fatal(err)
	}
	// 30 polls of the change watcher (200 ms) with nothing new: nothing may be published and the
	// engine's own reads must not change what it watches.
	if got := p.collect(6 * time.Second); len(got) != 0 {
		t.Fatalf("idle app-server published %d notifications: %v", len(got), got)
	}
	after, err := os.Stat(observed)
	if err != nil {
		t.Fatal(err)
	}
	if !after.ModTime().Equal(before.ModTime()) {
		t.Fatal("idle reads changed the observed directory the engine watches")
	}
}

// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/testenv"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"
)

// G3-13: a subscribed app sees a new local observation without manual refresh.
func TestG313LocalReadingNotifiesRealBinary(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	if out, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, out)
	}
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "cache"))
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	path := filepath.Join(home, ".codex", "sessions", "2026", "11", "05", "rollout-synthetic.jsonl")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	line := func(at time.Time, used int) []byte {
		b, err := json.Marshal(map[string]any{"timestamp": at.UTC(), "type": "event_msg", "payload": map[string]any{"type": "token_count", "rate_limits": map[string]any{"limit_id": "codex", "plan_type": "plus", "primary": map[string]any{"used_percent": used, "window_minutes": 300, "resets_at": time.Now().Add(2 * time.Hour).Unix()}}}})
		if err != nil {
			t.Fatal(err)
		}
		return append(b, '\n')
	}
	if err := os.WriteFile(path, line(time.Now().Add(-time.Hour-time.Minute), 80), 0600); err != nil {
		t.Fatal(err)
	}
	p := startQueryBinaryCapsWithArgs(t, binary, []string{"rows"}, "--offline")
	initial := p.call("rows/subscribe", map[string]any{})
	var env wire.Envelope[wire.RowsSnapshot]
	if err := json.Unmarshal(initial["result"], &env); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, row := range env.Data.Projection.Rows {
		if row.ID == "codex" && string(row.State) == "stale" {
			found = true
		}
	}
	if !found {
		t.Fatalf("expected stale initial reading: %s", initial["result"])
	}
	// Allow the existing backend watcher to establish its initial baseline.
	time.Sleep(500 * time.Millisecond)
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.Write(line(time.Now(), 30)); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	timeout := time.After(8 * time.Second)
	for {
		select {
		case raw := <-p.frames:
			var msg map[string]json.RawMessage
			if json.Unmarshal(raw, &msg) != nil || string(msg["method"]) != `"rows/changed"` {
				continue
			}
			var update wire.Envelope[wire.RowsSnapshot]
			if err := json.Unmarshal(msg["params"], &update); err != nil {
				t.Fatal(err)
			}
			for _, row := range update.Data.Projection.Rows {
				if row.ID == "codex" && string(row.State) == "fresh" && len(row.Accounts) > 0 && len(row.Accounts[0].Windows) > 0 {
					remaining := row.Accounts[0].Windows[0].RemainingPercent
					if remaining != nil && *remaining == 70 {
						return
					}
				}
			}
		case <-timeout:
			t.Fatal("no fresh 70% rows/changed after local reading")
		}
	}
}

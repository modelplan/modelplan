// SPDX-License-Identifier: MIT
package appserver

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// G3-20 through the normal entry: the real `modelplan app-server` binary on a fresh profile
// (no consent file, no first-run click, owner decision 2026-11-06) with a signed-in Codex
// (synthetic runtime) and Codex session logs of the same account. The automatic refresh
// reads the runtime by default and the app's rows show ONE Codex account with a current
// reading. No credential, network or real home is used.
func TestG320FreshProfileShowsOneCodexAccountWithReading(t *testing.T) {
	g320FreshProfileOneAccount(t, "pro", func(reset time.Time) time.Time { return reset }, "pro")
}

// macrevb-602-1 through the normal entry: the plan was upgraded (pro_100 -> pro_200) before
// ModelPlan ever ran, so the newest session log still carries the old tier and an old cycle.
// The app still shows one Codex account, on the new plan.
func TestG320FreshProfileAfterUnobservedUpgradeShowsOneAccount(t *testing.T) {
	g320FreshProfileOneAccount(t, "pro_100", func(reset time.Time) time.Time { return reset.Add(-2 * time.Hour) }, "pro_200")
}

func g320FreshProfileOneAccount(t *testing.T, logPlan string, logReset func(reset time.Time) time.Time, runtimePlan string) {
	t.Helper()
	bin := candidateBinary(t, "./cmd/modelplan")
	runtimeHost := candidateBinary(t, "./internal/appserver/testdata/runtime")
	home := t.TempDir()
	binDir := filepath.Join(home, "bin")
	if err := os.MkdirAll(binDir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(runtimeHost, filepath.Join(binDir, "codex")); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC().Truncate(time.Second)
	reset := now.Add(3 * time.Hour)
	// A recent Codex turn logged the same five-hour meter (same reset instant).
	logAt := now.Add(-2 * time.Minute)
	day := filepath.Join(home, ".codex", "sessions", logAt.Format("2006"), logAt.Format("01"), logAt.Format("02"))
	if err := os.MkdirAll(day, 0o700); err != nil {
		t.Fatal(err)
	}
	line := fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","plan_type":%q,"primary":{"used_percent":9,"window_minutes":300,"resets_at":%d},"secondary":null}}}`+"\n", logAt.Format(time.RFC3339), logPlan, logReset(reset).Unix())
	if err := os.WriteFile(filepath.Join(day, "rollout-"+logAt.Format("2006-01-02T15-04-05")+"-g320.jsonl"), []byte(line), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(home, ".config", "modelplan", "consent.json")); !os.IsNotExist(err) {
		t.Fatal("fixture must start without consent decisions")
	}
	trace := filepath.Join(home, "runtime.jsonl")
	c, stderr := candidateClient(t, bin, home, nil, []string{"MODELPLAN_U3B_RUNTIME_CALLS=" + trace, "MODELPLAN_U3B_RUNTIME_RESETS_AT=" + strconv.FormatInt(reset.Unix(), 10), "MODELPLAN_U3B_RUNTIME_PLAN=" + runtimePlan})
	c.initialize(t)
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	m := c.response(t, 2)
	var snapshot wire.Envelope[wire.RowsSnapshot]
	if err := json.Unmarshal(m["result"], &snapshot); err != nil {
		t.Fatalf("rows/subscribe: %s", m["error"])
	}
	// Wait on the published state, not on one notification: under load the read can finish
	// between the last rows/changed and the check, so ask for the rows again while waiting.
	deadline := time.Now().Add(90 * time.Second)
	var codex *rows.Row
	for id := 3; ; id++ {
		codex = nil
		for i := range snapshot.Data.Projection.Rows {
			if snapshot.Data.Projection.Rows[i].ID == "codex" {
				codex = &snapshot.Data.Projection.Rows[i]
			}
		}
		if codex != nil && runtimeReadCount(t, trace) > 0 && hasRuntimeAccount(codex) {
			break
		}
		if !time.Now().Before(deadline) {
			account, _ := os.ReadFile(filepath.Join(home, "cache", "observed", "codex-account.json"))
			t.Fatalf("no Codex runtime reading by default on a fresh profile (runtime reads=%d, codex row=%t, cached snapshot bytes=%d)", runtimeReadCount(t, trace), codex != nil, len(account))
		}
		if next, ok := nextRowsChanged(t, c, time.Now().Add(time.Second)); ok {
			snapshot = next
			continue
		}
		c.send(t, id, "rows/subscribe", wire.Empty{})
		var current wire.Envelope[wire.RowsSnapshot]
		if json.Unmarshal(c.response(t, id)["result"], &current) == nil {
			snapshot = current
		}
	}
	if len(codex.Accounts) != 1 {
		for _, a := range codex.Accounts {
			t.Logf("account route=%s value=%s windows=%d", a.Route, a.ValueState, len(a.Windows))
		}
		t.Fatalf("one signed-in Codex account shown as %d accounts", len(codex.Accounts))
	}
	account := codex.Accounts[0]
	if account.ValueState != rows.ValueStateCurrent {
		t.Fatalf("Codex reading is not current: %s", account.ValueState)
	}
	finishCandidate(t, c)
	if stderr.Len() != 0 {
		t.Fatalf("unexpected protocol stderr: %s", stderr.String())
	}
}

func hasRuntimeAccount(row *rows.Row) bool {
	for _, a := range row.Accounts {
		if a.Route == rows.RouteRuntimeRPC && a.ValueState == rows.ValueStateCurrent {
			for _, w := range a.Windows {
				if w.Current {
					return true
				}
			}
		}
	}
	return false
}

// nextRowsChanged waits for the next rows/changed notification without failing the test.
func nextRowsChanged(t *testing.T, c *pipeClient, deadline time.Time) (wire.Envelope[wire.RowsSnapshot], bool) {
	t.Helper()
	decode := func(m map[string]json.RawMessage) (wire.Envelope[wire.RowsSnapshot], bool) {
		var value wire.Envelope[wire.RowsSnapshot]
		return value, string(m["method"]) == `"rows/changed"` && json.Unmarshal(m["params"], &value) == nil
	}
	for i, m := range c.pending {
		if value, ok := decode(m); ok {
			c.pending = append(c.pending[:i], c.pending[i+1:]...)
			return value, true
		}
	}
	timer := time.NewTimer(time.Until(deadline))
	defer timer.Stop()
	for {
		select {
		case m, open := <-c.messages:
			if !open {
				return wire.Envelope[wire.RowsSnapshot]{}, false
			}
			if value, ok := decode(m); ok {
				return value, true
			}
			c.pending = append(c.pending, m)
		case <-timer.C:
			return wire.Envelope[wire.RowsSnapshot]{}, false
		}
	}
}

// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// A real server wakes an admitted local reader when a three-hour-old runtime
// cannot satisfy freshness. Under owner decision B (#602) the unavailable runtime
// is then not an account: the fresh, unbound local logs are the only Codex account.
func TestStaleCodexRuntimeFallbackPublishesRealBinary(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	if out, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, out)
	}
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	cache := filepath.Join(home, "cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		if err := consent.Set(s, "codex", true, "native:codex", "native", time.Now()); err != nil {
			return err
		}
		for _, scope := range []string{consent.ScopeCodexRuntimeUsage, consent.ScopeCodexLocalHistory} {
			s.Scopes[scope] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	admission := consent.Capture()
	now := time.Now().UTC().Truncate(time.Second)
	old := now.Add(-3 * time.Hour)
	used := 80.0
	snapshot := map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": old, "subscriptionRef": "0123456789abcdef", "admission": admission.State().CaptureStamp(consent.ScopeCodexRuntimeUsage), "windows": []quota.Window{{Kind: "weekly", UsedPercent: &used, WindowMinutes: 10080, ObservedAt: old}}}
	writeJSON := func(path string, value any) {
		t.Helper()
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			t.Fatal(err)
		}
		b, err := json.Marshal(value)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, b, 0600); err != nil {
			t.Fatal(err)
		}
	}
	writeJSON(filepath.Join(cache, "observed", "codex-account.json"), snapshot)
	writeJSON(filepath.Join(cache, "observed", "reader-attempts", "codex.json"), map[string]any{"schemaVersion": 1, "nextAttemptAt": now.Add(30 * time.Minute)})
	log := filepath.Join(home, ".codex", "sessions", "2026", "11", "05", "rollout-synthetic.jsonl")
	if err := os.MkdirAll(filepath.Dir(log), 0700); err != nil {
		t.Fatal(err)
	}
	line := func(at time.Time, percent int) []byte {
		t.Helper()
		b, err := json.Marshal(map[string]any{"timestamp": at, "type": "event_msg", "payload": map[string]any{"type": "token_count", "rate_limits": map[string]any{"limit_id": "codex", "plan_type": "plus", "primary": map[string]any{"used_percent": percent, "window_minutes": 10080, "resets_at": now.Add(24 * time.Hour).Unix()}}}})
		if err != nil {
			t.Fatal(err)
		}
		return append(b, '\n')
	}
	if err := os.WriteFile(log, line(old, 80), 0600); err != nil {
		t.Fatal(err)
	}
	unlock, err := consent.ReaderLock()
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		if unlock != nil {
			unlock()
		}
	}()
	p := startQueryBinaryCaps(t, binary, []string{"rows", "diagnostics", "refreshDecisionsV1"})
	initial := p.call("rows/subscribe", map[string]any{})
	if len(initial["result"]) == 0 {
		t.Fatalf("subscribe failed: %s", initial["error"])
	}
	// The admitted scheduler decision is a synchronization point: while the
	// reader lock is held, no local capture can run before the new fixture exists.
	// The child's read waits up to 2 s for the lock only from the decision on, and
	// the lock is released within one 10 ms poll of the decision becoming visible,
	// so a long deadline here never exhausts that budget; it only tolerates a slow
	// start of the child on a loaded runner (glm-523-5).
	deadline := time.Now().Add(10 * time.Second)
	scheduled := false
	for time.Now().Before(deadline) {
		response := p.call("diagnostics/get", map[string]any{})
		var diag wire.Envelope[wire.Diagnostics]
		if json.Unmarshal(response["result"], &diag) == nil && diag.Data.RefreshDecisions != nil {
			for _, decision := range *diag.Data.RefreshDecisions {
				if decision.Scope == wire.DecisionCodexLocal {
					scheduled = true
				}
			}
		}
		if scheduled {
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if !scheduled {
		t.Fatal("stale runtime suppressed the admitted local fallback")
	}
	f, err := os.OpenFile(log, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.Write(line(now, 30)); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	unlock()
	unlock = nil
	timeout := time.After(5 * time.Second)
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
			freshLocal, runtimeShown, accounts := false, false, 0
			for _, row := range update.Data.Projection.Rows {
				if row.ID != "codex" {
					continue
				}
				accounts += len(row.Accounts)
				for _, account := range row.Accounts {
					if account.Route == "local_log" && account.ObservedAt != nil && !account.ObservedAt.Before(now) {
						for _, window := range account.Windows {
							if window.RemainingPercent != nil && *window.RemainingPercent == 70 {
								freshLocal = true
							}
						}
					}
					if account.Route == "runtime_rpc" {
						runtimeShown = true
					}
				}
			}
			if freshLocal {
				if runtimeShown || accounts != 1 {
					t.Fatalf("unavailable runtime shown beside the local fallback (%d accounts)", accounts)
				}
				return
			}
		case <-timeout:
			t.Fatal("local fallback did not publish fresh local data")
		}
	}
}

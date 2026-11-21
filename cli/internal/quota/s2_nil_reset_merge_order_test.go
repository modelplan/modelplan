// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// Sampling 11-20 S2 (#1059): three Codex rollouts of one five-hour meter, none with a reset time.
// A reads 80% at noon, B 95% at 11:44, C 60% at 11:45 (after an unseen reset). Invariant: the
// inferred cycle does not depend on the order rollouts are merged in, so every file order gives
// the 60-to-80 rise: a 15-minute run-out and conserve. Read through the local Codex reader.
func TestRunOutWithoutAResetTimeDoesNotDependOnRolloutOrder(t *testing.T) {
	now := time.Date(2026, 11, 20, 12, 0, 0, 0, time.UTC)
	reads := map[string][2]float64{"a": {0, 80}, "b": {-16, 95}, "c": {-15, 60}}
	for _, order := range [][]string{{"a", "b", "c"}, {"a", "c", "b"}, {"b", "a", "c"}, {"b", "c", "a"}, {"c", "a", "b"}, {"c", "b", "a"}} {
		t.Run(fmt.Sprint(order), func(t *testing.T) {
			forgetCodexRollouts()
			t.Cleanup(forgetCodexRollouts)
			home := t.TempDir()
			day := filepath.Join(home, "sessions", "2026", "11", "20")
			if err := os.MkdirAll(day, 0o700); err != nil {
				t.Fatal(err)
			}
			for i, name := range order { // order[0] has the newest modification time
				r := reads[name]
				ts := now.Add(time.Duration(r[0]) * time.Minute).Format(time.RFC3339Nano)
				line := fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":%g,"window_minutes":300},"plan_type":"plus"}}}`+"\n", ts, r[1])
				p := filepath.Join(day, fmt.Sprintf("rollout-2026-11-20T11-00-0%d-%s.jsonl", i, name))
				if err := os.WriteFile(p, []byte(line), 0o600); err != nil {
					t.Fatal(err)
				}
				mod := now.Add(-time.Duration(i) * time.Minute)
				_ = os.Chtimes(p, mod, mod)
			}
			accts, st := readCodex(home, "")
			if st.Status != "ok" || len(accts) != 1 {
				t.Fatalf("read: %+v %+v", st, accts)
			}
			a := accts[0]
			Evaluate(&a, now)
			var w *Window
			for i := range a.Windows {
				if a.Windows[i].WindowMinutes == 300 {
					w = &a.Windows[i]
				}
			}
			if w == nil || w.UsedPercent == nil || *w.UsedPercent != 80 {
				t.Fatalf("five-hour window: %+v", a.Windows)
			}
			if w.RunsOutInMinutes == nil || *w.RunsOutInMinutes != 15 {
				t.Fatalf("run-out %v, want 15 minutes", deref(w.RunsOutInMinutes))
			}
			if a.Headroom != "conserve" {
				t.Fatalf("headroom %q, want conserve", a.Headroom)
			}
		})
	}
}

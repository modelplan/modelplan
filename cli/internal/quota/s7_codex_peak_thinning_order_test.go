// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// Sampling 11-21 S7 (#1130): four Codex rollouts of one five-hour meter, none with a reset time:
// 75% at 11:30, 85% at 11:31, 84% at 11:45 (after an unseen reset) and 85% at noon. Merging the
// older rollouts in timestamp order thinned away the 11:31 peak before the 11:45 drop arrived,
// so the cycle spanned the reset and the reader forecast a 45-minute run-out. Invariant: the
// inferred cycle, and so the forecast, does not depend on the order rollouts are merged in; here
// every one of the 24 file orders gives no run-out forecast.
func TestS7PeakIsNotThinnedBeforeItsDropInAnyRolloutOrder(t *testing.T) {
	now := time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)
	reads := map[string][2]float64{"a": {-30, 75}, "b": {-29, 85}, "c": {-15, 84}, "d": {0, 85}}
	var orders [][]string
	var permute func(prefix, rest []string)
	permute = func(prefix, rest []string) {
		if len(rest) == 0 {
			orders = append(orders, append([]string(nil), prefix...))
			return
		}
		for i := range rest {
			next := append(append([]string(nil), rest[:i]...), rest[i+1:]...)
			permute(append(prefix, rest[i]), next)
		}
	}
	permute(nil, []string{"a", "b", "c", "d"})
	if len(orders) != 24 {
		t.Fatal(len(orders))
	}
	for _, order := range orders {
		t.Run(fmt.Sprint(order), func(t *testing.T) {
			forgetCodexRollouts()
			t.Cleanup(forgetCodexRollouts)
			home := t.TempDir()
			day := filepath.Join(home, "sessions", "2026", "11", "21")
			if err := os.MkdirAll(day, 0o700); err != nil {
				t.Fatal(err)
			}
			for i, name := range order { // order[0] has the newest modification time
				r := reads[name]
				ts := now.Add(time.Duration(r[0]) * time.Minute).Format(time.RFC3339Nano)
				line := fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":%g,"window_minutes":300},"plan_type":"plus"}}}`+"\n", ts, r[1])
				p := filepath.Join(day, fmt.Sprintf("rollout-2026-11-21T11-00-0%d-%s.jsonl", i, name))
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
			if w == nil || w.UsedPercent == nil || *w.UsedPercent != 85 {
				t.Fatalf("five-hour window: %+v", a.Windows)
			}
			if w.RunsOutInMinutes != nil {
				t.Fatalf("run-out %d minutes across an unseen reset", *w.RunsOutInMinutes)
			}
		})
	}
}

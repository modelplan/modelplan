// SPDX-License-Identifier: MIT
package advise

import (
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

// paceEvents is a user-only factual warning. It does not change headroom,
// configure a harness, arm switch-back advice or enter the model's task brief.
func paceEvents(a *quota.Account, state *State, now time.Time) []Event {
	var out []Event
	for i := range a.Windows {
		w := &a.Windows[i]
		if !a.InPool(w) || w.UsedPercent == nil || w.ElapsedPercent == nil ||
			*w.UsedPercent-*w.ElapsedPercent < 10 {
			continue
		}
		runout := w.LastDayRunout(now)
		if runout == nil {
			continue
		}
		key := windowKey(WindowPace, a, w)
		if state != nil {
			if _, seen := state.Seen[key]; seen {
				continue
			}
		}
		reset := w.ResetsAt.UTC()
		out = append(out, Event{Type: WindowPace, Key: key, Severity: "warn", Source: a.Source,
			Plan: a.Plan, Window: w.Kind, Limit: w.Limit, At: &reset,
			InMinutes: minutesUntil(reset, now), RemainingPercent: w.RemainingPercent, RunsOutInMinutes: runout})
	}
	return out
}

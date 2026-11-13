package advise

import (
	"encoding/json"
	"sort"
	"strings"
	"time"
)

// Boundaries: the coming instants at which Derive may give other events from the same input,
// only because the clock passed them: a reset or the start of its last quarter, a card expiry or
// rate boundary entering its lead, a harness reading going quiet, a public reset becoming or
// ceasing to be news, a switch-back's or a better model's time in the status line ending. Shares
// of a window that move with every minute (elapsed, projected) have no boundary and are not here.
// Sorted, without repeats.
func Boundaries(in Input) []time.Time {
	now := in.Now.UTC()
	var out []time.Time
	add := func(ts ...time.Time) {
		for _, t := range ts {
			if t.After(now) {
				out = append(out, t.UTC())
			}
		}
	}
	for i := range in.Report.Accounts {
		a := &in.Report.Accounts[i]
		if harnessOf(a.Source) != "" && !a.ObservedAt.IsZero() {
			add(a.ObservedAt.Add(harnessQuiet))
		}
		for j := range a.Windows {
			w := &a.Windows[j]
			if w.ResetsAt == nil {
				continue
			}
			add(*w.ResetsAt)
			if w.WindowMinutes > 0 {
				add(w.ResetsAt.Add(-time.Duration(float64(w.WindowMinutes) * soonShare * float64(time.Minute))))
			}
		}
		for _, c := range a.Cards {
			if c.ExpiresAt != nil {
				add(c.ExpiresAt.Add(-cardLead), *c.ExpiresAt)
			}
		}
	}
	if d := in.Digest; d != nil {
		for _, raw := range d.Resets {
			var r resetSummary
			if json.Unmarshal(raw, &r) != nil || r.ID == "" {
				continue
			}
			if p, err := time.Parse(time.RFC3339, r.PublishedAt); err == nil {
				add(p.Add(-5*time.Minute), p.Add(publicFresh))
			}
			if r.Schedule != nil {
				if t, err := time.Parse(time.RFC3339, r.Schedule.Through); err == nil {
					add(t.Add(-announcedLead), t)
				}
			}
		}
		if h := d.MultiplierHorizon; h != nil {
			if to, err := time.Parse(time.RFC3339, h.To); err == nil {
				add(to)
			}
		}
		for i := range d.Multipliers {
			for _, s := range []string{d.Multipliers[i].StartsAt, d.Multipliers[i].EndsAt} {
				if t, err := time.Parse(time.RFC3339, s); err == nil {
					add(t.Add(-rateLead), t)
				}
			}
		}
	}
	if s := in.State; s != nil {
		for _, a := range s.Armed {
			add(a.ResetAt, a.ResetAt.Add(a.lasts()))
			if a.Noted != nil {
				add(a.Noted.Add(switchBackShown))
			}
		}
		for k, t := range s.Seen {
			if strings.HasPrefix(k, "better|") || strings.HasPrefix(k, shownPrefix+"better|") {
				add(t.Add(betterShown))
			}
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Before(out[j]) })
	kept := out[:0]
	for i, t := range out {
		if i == 0 || !t.Equal(out[i-1]) {
			kept = append(kept, t)
		}
	}
	return kept
}

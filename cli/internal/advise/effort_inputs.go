// SPDX-License-Identifier: MIT
package advise

import (
	"encoding/json"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

// AnnouncedResets: the times of officially announced extra resets for this source that
// are still in force, for gating the weekly effort suggestion. A record counts only
// while it is announced or confirmed upstream; one that was withdrawn or cancelled (a
// later record with the same ID, or its own status) is ignored, and so is any status
// we do not recognise. The caller combines these with the scheduled reset and
// re-reads them on every publication read, so a withdrawal takes effect at once.
func AnnouncedResets(d *digest.Digest, source string, now time.Time) []time.Time {
	if d == nil {
		return nil
	}
	type rec struct {
		ID, Provider, EventType, Status string
		Schedule                        *struct{ Through string }
	}
	withdrawn := map[string]bool{}
	var live []rec
	for _, raw := range d.Resets {
		var r rec
		if json.Unmarshal(raw, &r) != nil || r.ID == "" || providerSource[r.Provider] != source {
			continue
		}
		switch r.Status {
		case "withdrawn", "cancelled":
			withdrawn[r.ID] = true
		case "upstream-announced", "upstream-confirmed":
			if r.EventType == "direct_reset_announced" && r.Schedule != nil {
				live = append(live, r)
			}
		}
	}
	var out []time.Time
	for _, r := range live {
		if t, err := time.Parse(time.RFC3339, r.Schedule.Through); err == nil && t.After(now) && !withdrawn[r.ID] {
			out = append(out, t)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Before(out[j]) })
	return out
}

// ResetUnused: whether derived advice says this source's quota resets unused (the
// statusline's "↑" spend headroom or an announced reset worth spending ahead of).
// The weekly effort suggestion reuses it instead of a second surplus rule.
func ResetUnused(es []Event, source string) bool {
	for _, e := range es {
		if e.Source == source && (e.Type == ResetSoonSurplus || e.Type == AnnouncedSurplus) {
			return true
		}
	}
	return false
}

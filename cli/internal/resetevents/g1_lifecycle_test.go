// SPDX-License-Identifier: MIT
package resetevents

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// DOCK-3.7-05: public events expire at their own deadline, not at a
// consumer-dependent refresh time. Confirmations use their own publication time.
func TestG1ResetEventLifecycleBoundaries(t *testing.T) {
	published := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	through := published.Add(3 * time.Hour)
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	announce := record{ID: "event", Provider: "openai", EventType: "direct_reset_announced", Status: "upstream-announced", PublishedAt: published}
	confirmedAt := published.Add(time.Hour)
	confirm := record{Provider: "openai", EventType: "direct_reset_reported_complete", Status: "upstream-confirmed", PublishedAt: confirmedAt, Confirms: "event"}
	scheduled := announce
	scheduled.Schedule = &Schedule{Precision: "window", From: published.Add(2 * time.Hour), Through: through}

	for _, tc := range []struct {
		name    string
		records []record
		expiry  time.Time
		status  string
	}{
		{"unscheduled", []record{announce}, published.Add(48 * time.Hour), "announced"},
		{"scheduled", []record{scheduled}, through, "announced"},
		{"confirmed", []record{announce, confirm}, confirmedAt.Add(24 * time.Hour), "confirmed"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			d := &digest.Digest{PublicationID: "0123456789abcdef01234567"}
			for _, r := range tc.records {
				b, err := json.Marshal(r)
				if err != nil {
					t.Fatal(err)
				}
				d.Resets = append(d.Resets, b)
			}
			before, dropped := Project(d, projection, tc.expiry.Add(-time.Nanosecond))
			if dropped != 0 || len(before) != 1 || before[0].Status != tc.status || !before[0].ExpiresAt.Equal(tc.expiry) {
				t.Fatalf("before expiry: events=%+v dropped=%d", before, dropped)
			}
			at, _ := Project(d, projection, tc.expiry)
			if len(at) != 0 {
				t.Fatalf("retained at expiry: %+v", at)
			}
		})
	}
}

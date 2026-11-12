// SPDX-License-Identifier: MIT
package resetevents

import (
	"encoding/json"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// CaptureEvents returns the events the real projector emits for a synthetic
// publication: an announced direct reset, an announced reset credit, and a
// confirmed credit read for the first time. The app-side captures take their
// reset events from here, so a field the producer adds reaches the cockpit page
// validator tests without anyone transcribing it (G3-96).
func CaptureEvents(now time.Time) ([]Event, error) {
	window := &Schedule{Precision: "window", From: now.Add(time.Hour), Through: now.Add(3 * time.Hour)}
	records := []record{
		{ID: "synthetic-reset", Provider: "openai", EventType: "direct_reset_announced", Status: "upstream-announced", PublishedAt: now, Schedule: window, URL: "https://aihot.news/codex-reset"},
		{ID: "synthetic-credit", Provider: "openai", EventType: "reset_credit_issued", Status: "upstream-announced", PublishedAt: now, Schedule: window},
		{ID: "synthetic-confirmed", Provider: "openai", EventType: "reset_credit_issued", Status: "upstream-confirmed", PublishedAt: now},
	}
	d := &digest.Digest{PublicationID: "0123456789abcdef01234567"}
	for _, r := range records {
		b, err := json.Marshal(r)
		if err != nil {
			return nil, err
		}
		d.Resets = append(d.Resets, b)
	}
	events, _ := ProjectWithMemo(d, rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}, now, NewMemo())
	return events, nil
}

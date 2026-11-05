// SPDX-License-Identifier: MIT
package resetevents

// Spec-data scenario R-12 (tier-1 producer half): "DOCK-3.4-09: a verified
// public event is present in the CLI snapshot / Launch the App normally and
// subscribe to rows / The event reaches the corresponding Dock presentation
// from the CLI snapshot events." A verified upstream announcement reaches the
// Dock presentation data only for the row that exists in the snapshot — never
// inventing a presentation for a tool the snapshot does not carry.

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestR12AnnouncementReachesOnlyAnExistingDockRow(t *testing.T) {
	now := time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
	announce := record{ID: "published-id", Provider: "openai", EventType: "direct_reset_announced", Status: "upstream-announced", PublishedAt: now.Add(-time.Hour)}
	raw, err := json.Marshal(announce)
	if err != nil {
		t.Fatal(err)
	}
	d := &digest.Digest{PublicationID: "0123456789abcdef01234567", Resets: []json.RawMessage{raw}}

	// With the codex row subscribed, the announcement reaches its Dock
	// presentation with the verified publication source attached.
	withRow := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	events, dropped := Project(d, withRow, now)
	if len(events) != 1 || dropped != 0 {
		t.Fatalf("announcement must reach the subscribed row, got %+v dropped %d", events, dropped)
	}
	event := events[0]
	if event.RowID != "codex" || event.Provider != "openai" || event.Status != "announced" {
		t.Fatalf("event lost its row binding: %+v", event)
	}
	if event.Source.Kind != "publication" || event.Source.PublicationID != d.PublicationID {
		t.Fatalf("verified publication source lost: %+v", event.Source)
	}

	// Without the codex row in the snapshot, no Dock presentation is invented.
	withoutRow := rows.Projection{Rows: []rows.Row{{ID: "claude", Kind: rows.KindTool}}}
	events, dropped = Project(d, withoutRow, now)
	if len(events) != 0 || dropped != 0 {
		t.Fatalf("announcement must not invent an absent presentation, got %+v dropped %d", events, dropped)
	}
}

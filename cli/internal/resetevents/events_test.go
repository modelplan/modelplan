// SPDX-License-Identifier: MIT
package resetevents

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestVerifiedResetNormalization(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	p := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool, Accounts: []rows.Account{{Plan: rows.Plan{ID: "pro"}}}}}}
	announce := record{ID: "published-id", Provider: "openai", EventType: "direct_reset_announced", Status: "upstream-announced", PublishedAt: now.Add(-time.Hour)}
	encode := func(r record) json.RawMessage {
		b, err := json.Marshal(r)
		if err != nil {
			t.Fatal(err)
		}
		return b
	}
	d := &digest.Digest{PublicationID: "0123456789abcdef01234567", Resets: []json.RawMessage{encode(announce)}}
	events, dropped := Project(d, p, now)
	if len(events) != 1 || events[0].ID != "published-id" || events[0].Status != "announced" || dropped != 0 {
		t.Fatalf("announcement: %+v %d", events, dropped)
	}
	confirm := record{Provider: "openai", EventType: "direct_reset_reported_complete", Status: "upstream-confirmed", PublishedAt: now, Confirms: "published-id"}
	unlinked := confirm
	unlinked.Confirms = "unmatched"
	unknown := announce
	unknown.Status = "future-status"
	d.Resets = []json.RawMessage{encode(announce), encode(confirm), encode(unlinked), encode(unknown)}
	events, dropped = Project(d, p, now)
	if len(events) != 1 || events[0].Status != "confirmed" || events[0].Confirms != "published-id" || dropped != 1 {
		t.Fatalf("confirmation: %+v %d", events, dropped)
	}
	events, _ = Project(d, p, now.Add(25*time.Hour))
	if len(events) != 0 {
		t.Fatal("expired confirmation emitted")
	}
	d.Resets = []json.RawMessage{encode(announce)}
	events, _ = Project(d, p, now.Add(48*time.Hour))
	if len(events) != 0 {
		t.Fatal("expired announcement emitted")
	}
	scopeText := "pro subscribers"
	announce.Scope = &scopeText
	d.Resets = []json.RawMessage{encode(announce)}
	events, _ = Project(d, p, now)
	if len(events) != 1 || len(events[0].PlanIDs) != 0 {
		t.Fatal("unmapped scope must use the row-wide v1 fallback")
	}
	announce.Scope = nil
	plans := []string{"plus"}
	announce.PlanIDs = &plans
	d.Resets = []json.RawMessage{encode(announce)}
	events, _ = Project(d, p, now)
	if len(events) != 0 {
		t.Fatal("unmatched plan emitted")
	}
	plans = []string{"pro"}
	announce.PlanIDs = &plans
	d.Resets = []json.RawMessage{encode(announce)}
	events, _ = Project(d, p, now)
	if len(events) != 1 || len(events[0].PlanIDs) != 1 {
		t.Fatal("matching scoped plan dropped")
	}
}

// V1 has no official-host interface: links are omitted for every source while
// otherwise eligible announcements remain visible.
func TestSourceLinksAreOmittedInV1(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	for _, rawURL := range []string{"https://vendor.example/reset", "https://unlisted.example/reset"} {
		r := record{ID: "record", Provider: "openai", EventType: "direct_reset_announced", Status: "upstream-announced", PublishedAt: now.Add(-time.Hour), At: &now, URL: rawURL}
		b, _ := json.Marshal(r)
		d := &digest.Digest{PublicationID: "0123456789abcdef01234567", Resets: []json.RawMessage{b}}
		events, _ := Project(d, projection, now)
		if len(events) != 1 || events[0].Source.URL != "" {
			t.Fatal("v1 exposed a source link or dropped an eligible event")
		}
	}
}

func TestDuplicateAnnouncementIdentityFailsClosed(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	p := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	r := record{ID: "same-id", Provider: "openai", EventType: "direct_reset_announced", Status: "upstream-announced", PublishedAt: now.Add(-time.Hour)}
	b, _ := json.Marshal(r)
	d := &digest.Digest{PublicationID: "0123456789abcdef01234567", Resets: []json.RawMessage{b, b}}
	if events, _ := Project(d, p, now); len(events) != 0 {
		t.Fatal("duplicate identity accepted")
	}
}

func TestStableIdentityAndUnsafeInputs(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	r := record{Provider: "openai", At: &now, URL: "https://example.test/source", ID: "fallback"}
	id, ok := eventID(r)
	if !ok || len(id) != 64 {
		t.Fatal("hash identity")
	}
	r.At = nil
	id, ok = eventID(r)
	if !ok || id != "fallback" {
		t.Fatal("missing instant fallback")
	}
	r.ID = "account@example.test"
	if _, ok = eventID(r); ok {
		t.Fatal("unsafe fallback")
	}
	r.At = &now
	r.URL = "https://user:pass@example.test/source"
	if _, ok = eventID(r); ok {
		t.Fatal("credential URL accepted")
	}
}

func TestPointDeadlineAndWindowBoundaries(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	deadline := now.Add(2 * time.Hour)
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	for _, tc := range []struct {
		name, precision string
		from, through   time.Time
		want            bool
	}{
		{"point deadline", "deadline", deadline, deadline, true},
		{"reversed deadline", "deadline", deadline, deadline.Add(-time.Second), false},
		{"point window", "window", deadline, deadline, false},
		{"reversed window", "window", deadline, deadline.Add(-time.Second), false},
		{"bounded window", "window", deadline, deadline.Add(time.Hour), true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			r := record{ID: "event", Provider: "openai", EventType: "direct_reset_announced", Status: "upstream-announced", PublishedAt: now.Add(-time.Hour), Schedule: &Schedule{Precision: tc.precision, From: tc.from, Through: tc.through}}
			raw, err := json.Marshal(r)
			if err != nil {
				t.Fatal(err)
			}
			d := &digest.Digest{PublicationID: "0123456789abcdef01234567", Resets: []json.RawMessage{raw}}
			events, _ := Project(d, projection, now)
			if (len(events) == 1) != tc.want {
				t.Fatalf("got %d events, want eligible=%v", len(events), tc.want)
			}
			if tc.want {
				e := events[0]
				if e.Schedule == nil || e.Schedule.Precision != tc.precision || !e.Schedule.From.Equal(tc.from) || !e.Schedule.Through.Equal(tc.through) || !e.ExpiresAt.Equal(tc.through) {
					t.Fatalf("deadline changed: %+v", e)
				}
				expired, _ := Project(d, projection, tc.through)
				if len(expired) != 0 {
					t.Fatal("event retained at expiry")
				}
			}
		})
	}
}

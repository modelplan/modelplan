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
	if len(events) != 0 {
		t.Fatal("unmapped scope treated as plan-wide")
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

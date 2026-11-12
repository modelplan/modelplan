// SPDX-License-Identifier: MIT
package resetevents

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// D166: reset credits and direct resets, announced and confirmed, reach the
// Codex row with their kind and state; old ones expire.
func TestResetKindsAndStates(t *testing.T) {
	now := time.Date(2026, 11, 12, 10, 0, 0, 0, time.UTC)
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	window := &Schedule{Precision: "window", From: now.Add(-time.Hour), Through: now.Add(5 * time.Hour)}
	reported := now.Add(-30 * time.Minute)
	cases := []struct {
		name      string
		r         record
		kind      string
		status    string
		basis     string
		expiresAt time.Time
	}{
		{"credit announced", record{ID: "c1", EventType: "reset_credit_issued", Status: "upstream-announced", Schedule: window}, KindResetCredit, "announced", "", window.Through.Add(24 * time.Hour)},
		{"credit confirmed with time", record{ID: "c2", EventType: "reset_credit_issued", Status: "upstream-confirmed", ConfirmedAt: &reported}, KindResetCredit, "confirmed", BasisPublished, reported.Add(24 * time.Hour)},
		{"credit confirmed first seen", record{ID: "c3", EventType: "reset_credit_issued", Status: "upstream-confirmed"}, KindResetCredit, "confirmed", BasisFirstSeen, now.Add(24 * time.Hour)},
		{"direct announced", record{ID: "d1", EventType: "direct_reset_announced", Status: "upstream-announced", Schedule: window}, KindDirectReset, "announced", "", window.Through.Add(24 * time.Hour)},
		{"direct confirmed in place", record{ID: "d2", EventType: "direct_reset_reported_complete", Status: "upstream-confirmed"}, KindDirectReset, "confirmed", BasisFirstSeen, now.Add(24 * time.Hour)},
		{"direct announcement marked confirmed", record{ID: "d3", EventType: "direct_reset_announced", Status: "upstream-confirmed", ConfirmedAt: &reported}, KindDirectReset, "confirmed", BasisPublished, reported.Add(24 * time.Hour)},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			c.r.Provider, c.r.PublishedAt = "openai", now.Add(-2*time.Hour)
			events, _ := Project(publication(t, c.r), projection, now)
			if len(events) != 1 {
				t.Fatalf("got %d events", len(events))
			}
			e := events[0]
			if e.Kind != c.kind || e.Status != c.status || e.ConfirmedAtBasis != c.basis || !e.ExpiresAt.Equal(c.expiresAt) {
				t.Fatalf("unexpected event: %+v", e)
			}
			if c.status == "confirmed" && (e.Confirms != e.ID || e.ConfirmedAt == nil || e.Schedule != nil) {
				t.Fatalf("confirmed event lacks its own reference and time: %+v", e)
			}
			if c.status == "announced" && (e.ConfirmedAt != nil || e.Confirms != "") {
				t.Fatalf("announced event carries confirmation facts: %+v", e)
			}
		})
	}
	expired := []struct {
		name string
		r    record
	}{
		{"credit window over a day ago", record{ID: "x1", EventType: "reset_credit_issued", Status: "upstream-announced", PublishedAt: now.Add(-72 * time.Hour), Schedule: &Schedule{Precision: "date", From: now.Add(-64 * time.Hour), Through: now.Add(-24 * time.Hour)}}},
		{"credit confirmed long ago without time", record{ID: "x2", EventType: "reset_credit_issued", Status: "upstream-confirmed", PublishedAt: now.Add(-10 * 24 * time.Hour)}},
		{"credit confirmed after its window long ago", record{ID: "x3", EventType: "reset_credit_issued", Status: "upstream-confirmed", PublishedAt: now.Add(-60 * time.Hour), Schedule: &Schedule{Precision: "deadline", From: now.Add(-25 * time.Hour), Through: now.Add(-25 * time.Hour)}}},
		{"direct confirmed with old time", record{ID: "x4", EventType: "direct_reset_reported_complete", Status: "upstream-confirmed", PublishedAt: now.Add(-30 * time.Hour), ConfirmedAt: ptr(now.Add(-25 * time.Hour))}},
		{"other provider", record{ID: "x5", Provider: "claude", EventType: "reset_credit_issued", Status: "upstream-announced", PublishedAt: now.Add(-time.Hour)}},
		{"withdrawn", record{ID: "x6", EventType: "reset_credit_issued", Status: "withdrawn", PublishedAt: now.Add(-time.Hour)}},
		{"completion without confirmed status", record{ID: "x7", EventType: "direct_reset_reported_complete", Status: "upstream-announced", PublishedAt: now.Add(-time.Hour)}},
	}
	for _, c := range expired {
		t.Run(c.name, func(t *testing.T) {
			if c.r.Provider == "" {
				c.r.Provider = "openai"
			}
			if events, _ := Project(publication(t, c.r), projection, now); len(events) != 0 {
				t.Fatalf("expired or ineligible event emitted: %+v", events)
			}
		})
	}
}

// The live publication shape on 2026-11-11: a date-precision reset credit
// forecast with no confirmation time, beside an old confirmed one and other
// providers' records.
func TestLiveShapedResetCredit(t *testing.T) {
	live := `[
 {"id":"banked-2120410480204525936-1-1","provider":"openai","eventType":"reset_credit_issued",
  "schedule":{"precision":"date","from":"2026-11-12T16:00:00.000+08:00","through":"2026-11-13T16:00:00.000+08:00","label":"北京时间预计 11月12日 16:00–11月13日 16:00"},
  "observationUrl":"https://aihot.news/codex-reset","scope":null,"status":"upstream-announced","at":null,"precision":"unknown",
  "publishedAt":"2026-11-11T14:57:08.000+08:00","url":"https://x.com/thsottiaux/status/2120410480204525936"},
 {"id":"didreset-claude-2120275296637321476","provider":"claude","eventType":"reset_credit_issued","schedule":null,
  "observationUrl":"https://x.com/ClaudeDevs/status/2120275296637321476","scope":"global","status":"upstream-announced","at":null,
  "precision":"unknown","publishedAt":"2026-11-10T21:59:58.000Z","url":"https://x.com/ClaudeDevs/status/2120275296637321476"},
 {"id":"banked-2116405414921384099-1-1","provider":"openai","eventType":"reset_credit_issued",
  "schedule":{"precision":"deadline","from":"2026-11-02T13:42:00.000+08:00","through":"2026-11-02T13:42:00.000+08:00","label":"北京时间预计 11月2日 13:42 前"},
  "observationUrl":"https://aihot.news/codex-reset","scope":null,"status":"upstream-confirmed","at":null,"precision":"unknown",
  "publishedAt":"2026-10-31T13:42:26.000+08:00","url":"https://x.com/thsottiaux/status/2116692529970311254"}
]`
	var resets []json.RawMessage
	if err := json.Unmarshal([]byte(live), &resets); err != nil {
		t.Fatal(err)
	}
	d := &digest.Digest{PublicationID: "0123456789abcdef01234567", Resets: resets}
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	memo := NewMemo()
	now := time.Date(2026, 11, 11, 20, 0, 0, 0, time.UTC)
	events, _ := ProjectWithMemo(d, projection, now, memo)
	if len(events) != 1 {
		t.Fatalf("want the one current Codex forecast, got %+v", events)
	}
	e := events[0]
	through := time.Date(2026, 11, 13, 8, 0, 0, 0, time.UTC)
	if e.ID != "banked-2120410480204525936-1-1" || e.Kind != KindResetCredit || e.Status != "announced" ||
		e.Schedule == nil || e.Schedule.Precision != "date" || !e.ExpiresAt.Equal(through.Add(24*time.Hour)) || e.ConfirmedAt != nil {
		t.Fatalf("live forecast: %+v", e)
	}
	if len(e.Source.Links) != 2 {
		t.Fatalf("live forecast links: %+v", e.Source.Links)
	}
	// AIhot later confirms the same record in place, without a confirmation time.
	var record map[string]any
	_ = json.Unmarshal(resets[0], &record)
	record["status"] = "upstream-confirmed"
	confirmed, _ := json.Marshal(record)
	d.Resets = []json.RawMessage{confirmed, resets[1], resets[2]}
	seen := through.Add(-3 * time.Hour)
	events, _ = ProjectWithMemo(d, projection, seen, memo)
	if len(events) != 1 || events[0].Status != "confirmed" || events[0].ConfirmedAtBasis != BasisObserved ||
		!events[0].ConfirmedAt.Equal(seen) || !events[0].ExpiresAt.Equal(seen.Add(24*time.Hour)) || events[0].Kind != KindResetCredit {
		t.Fatalf("observed confirmation: %+v", events)
	}
	// A later refresh keeps the first observed instant.
	events, _ = ProjectWithMemo(d, projection, seen.Add(time.Hour), memo)
	if len(events) != 1 || !events[0].ConfirmedAt.Equal(seen) {
		t.Fatalf("confirmation time moved: %+v", events)
	}
	// A fresh process first reading it confirmed one day after the window: gone.
	if events, _ := ProjectWithMemo(d, projection, through.Add(24*time.Hour), NewMemo()); len(events) != 0 {
		t.Fatalf("stale first-seen confirmation emitted: %+v", events)
	}
}

func publication(t *testing.T, records ...record) *digest.Digest {
	t.Helper()
	d := &digest.Digest{PublicationID: "0123456789abcdef01234567"}
	for _, r := range records {
		b, err := json.Marshal(r)
		if err != nil {
			t.Fatal(err)
		}
		d.Resets = append(d.Resets, b)
	}
	return d
}

func ptr(t time.Time) *time.Time { return &t }

// macrev2-862-2: after its window a forecast stays, awaiting confirmation, for
// 24 hours or until it is confirmed, whichever is first.
func TestForecastAwaitsConfirmationAfterItsWindow(t *testing.T) {
	now := time.Date(2026, 11, 12, 10, 0, 0, 0, time.UTC)
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	through := now.Add(time.Hour)
	forecast := record{ID: "f", Provider: "openai", EventType: "reset_credit_issued", Status: "upstream-announced", PublishedAt: now.Add(-time.Hour),
		Schedule: &Schedule{Precision: "window", From: now, Through: through}}
	d := publication(t, forecast)
	for _, c := range []struct {
		at   time.Time
		want int
	}{{through.Add(-time.Second), 1}, {through, 1}, {through.Add(24*time.Hour - time.Second), 1}, {through.Add(24 * time.Hour), 0}} {
		events, _ := Project(d, projection, c.at)
		if len(events) != c.want {
			t.Fatalf("at %s: %d events, want %d", c.at, len(events), c.want)
		}
		if c.want == 1 && (events[0].Status != "announced" || !events[0].Schedule.Through.Equal(through)) {
			t.Fatalf("awaiting forecast lost its window: %+v", events[0])
		}
	}
	confirmed := forecast
	confirmed.Status = "upstream-confirmed"
	events, _ := ProjectWithMemo(publication(t, confirmed), projection, through.Add(2*time.Hour), NewMemo())
	if len(events) != 1 || events[0].Status != "confirmed" {
		t.Fatalf("confirmation must replace the awaiting forecast: %+v", events)
	}
}

// macrev2-862-1: a remembered confirmation keeps its instant, lives exactly 24
// hours after it, and never comes back re-dated.
func TestRememberedConfirmationIsStableAndNeverResurrects(t *testing.T) {
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	posted := time.Date(2026, 11, 10, 12, 0, 0, 0, time.UTC)
	t.Run("first seen late in the recency window", func(t *testing.T) {
		memo := NewMemo()
		d := publication(t, record{ID: "late", Provider: "openai", EventType: "reset_credit_issued", Status: "upstream-confirmed", PublishedAt: posted})
		seen := posted.Add(23 * time.Hour)
		events, _ := ProjectWithMemo(d, projection, seen, memo)
		if len(events) != 1 || !events[0].ExpiresAt.Equal(seen.Add(24*time.Hour)) {
			t.Fatalf("first sight: %+v", events)
		}
		for _, later := range []time.Duration{2 * time.Hour, 24*time.Hour - time.Second} {
			events, _ = ProjectWithMemo(d, projection, seen.Add(later), memo)
			if len(events) != 1 || !events[0].ConfirmedAt.Equal(seen) {
				t.Fatalf("after %s the remembered confirmation vanished or moved: %+v", later, events)
			}
		}
		for _, later := range []time.Duration{24 * time.Hour, 49 * time.Hour, 13 * 24 * time.Hour} {
			if events, _ = ProjectWithMemo(d, projection, seen.Add(later), memo); len(events) != 0 {
				t.Fatalf("after %s an expired confirmation came back: %+v", later, events)
			}
		}
	})
	t.Run("window far ahead", func(t *testing.T) {
		memo := NewMemo()
		d := publication(t, record{ID: "ahead", Provider: "openai", EventType: "reset_credit_issued", Status: "upstream-confirmed", PublishedAt: posted,
			Schedule: &Schedule{Precision: "window", From: posted, Through: posted.Add(72 * time.Hour)}})
		events, _ := ProjectWithMemo(d, projection, posted.Add(time.Hour), memo)
		if len(events) != 1 {
			t.Fatalf("initial: %+v", events)
		}
		for _, later := range []time.Duration{25 * time.Hour, 49 * time.Hour, 71 * time.Hour} {
			if events, _ = ProjectWithMemo(d, projection, posted.Add(later), memo); len(events) != 0 {
				t.Fatalf("at +%s the confirmation resurrected: %+v", later, events)
			}
		}
	})
}

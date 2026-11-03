// SPDX-License-Identifier: MIT
package resetevents

import (
	"encoding/json"
	"reflect"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestTypedSourceLinkAdmission(t *testing.T) {
	for _, tc := range []struct {
		name, kind, raw string
		want            bool
	}{
		{"aihot event page", "aihot", "https://aihot.news/openai-codex-reset-2026-11", true},
		{"x.com status", "original", "https://x.com/OpenAI/status/1791234567890123456", true},
		{"twitter.com status", "original", "https://twitter.com/OpenAI/status/1791234567890123456", true},
		{"x.com profile", "original", "https://x.com/OpenAI", false},
		{"x.com search", "original", "https://x.com/search?q=reset", false},
		{"x.com status with query", "original", "https://x.com/OpenAI/status/1791234567890123456?s=20", false},
		{"x.com status with fragment", "original", "https://x.com/OpenAI/status/1791234567890123456#m", false},
		{"x.com non-status path", "original", "https://x.com/OpenAI/status/abc", false},
		{"aihot lookalike", "aihot", "https://aihot.news.evil.test/reset", false},
		{"x lookalike", "original", "https://evilx.com/OpenAI/status/1791234567890123456", false},
		{"openai status page", "official", "https://status.openai.com/incidents/kj8w3pn1", true},
		{"anthropic docs page", "official", "https://docs.anthropic.com/en/docs", true},
		{"official lookalike", "official", "https://openai.com.evil.test/reset", false},
		{"official suffix host", "official", "https://notopenai.com/reset", false},
		{"http rejected", "aihot", "http://aihot.news/reset", false},
		{"userinfo rejected", "aihot", "https://user:pass@aihot.news/reset", false},
		{"non-default port rejected", "aihot", "https://aihot.news:8443/reset", false},
		{"token-like query rejected", "aihot", "https://aihot.news/reset?session=abc", false},
		{"credential query rejected", "official", "https://status.openai.com/incidents/x?auth_token=abc", false},
		{"harmless query allowed", "aihot", "https://aihot.news/reset?utm_source=app", true},
		{"uppercase host matches exactly", "aihot", "https://AIHOT.news/reset", true},
		{"unknown type rejected", "press", "https://aihot.news/reset", false},
		{"malformed url rejected", "aihot", "https://aihot.news/%zz", false},
		{"empty url rejected", "aihot", "", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			link, ok := admittedLink(tc.kind, tc.raw)
			if ok != tc.want {
				t.Fatalf("admittedLink(%q, %q) = %v, want %v", tc.kind, tc.raw, ok, tc.want)
			}
			if ok && (link.Type != tc.kind || link.URL != tc.raw) {
				t.Fatalf("admitted link not round-tripped: %+v", link)
			}
		})
	}
}

func projectLinks(t *testing.T, links []recordLink) Event {
	t.Helper()
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	r := record{ID: "record", Provider: "openai", EventType: "direct_reset_announced", Status: "upstream-announced", PublishedAt: now.Add(-time.Hour), Links: links}
	b, err := json.Marshal(r)
	if err != nil {
		t.Fatal(err)
	}
	d := &digest.Digest{PublicationID: "0123456789abcdef01234567", Resets: []json.RawMessage{b}}
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	events, _ := Project(d, projection, now)
	if len(events) != 1 {
		t.Fatalf("got %d events, want one eligible event", len(events))
	}
	return events[0]
}

func TestProjectedLinksAdmittedInStableOrder(t *testing.T) {
	event := projectLinks(t, []recordLink{
		{Type: "original", URL: "https://x.com/OpenAI/status/1791234567890123456"},
		{Type: "official", URL: "https://status.openai.com/incidents/kj8w3pn1"},
		{Type: "aihot", URL: "https://aihot.news/openai-codex-reset-2026-11"},
	})
	want := []Link{
		{Type: "aihot", URL: "https://aihot.news/openai-codex-reset-2026-11"},
		{Type: "official", URL: "https://status.openai.com/incidents/kj8w3pn1"},
		{Type: "original", URL: "https://x.com/OpenAI/status/1791234567890123456"},
	}
	if !reflect.DeepEqual(event.Source.Links, want) {
		t.Fatalf("links: %+v, want %+v", event.Source.Links, want)
	}
	published := time.Date(2026, 11, 1, 11, 0, 0, 0, time.UTC)
	if !event.PublishedAt.Equal(published) || !event.ExpiresAt.Equal(published.Add(48*time.Hour)) {
		t.Fatalf("links changed published facts: %+v", event)
	}
}

func TestNoOriginalPostLeavesAihotOnly(t *testing.T) {
	event := projectLinks(t, []recordLink{{Type: "aihot", URL: "https://aihot.news/openai-codex-reset-2026-11"}})
	want := []Link{{Type: "aihot", URL: "https://aihot.news/openai-codex-reset-2026-11"}}
	if !reflect.DeepEqual(event.Source.Links, want) {
		t.Fatalf("links: %+v, want %+v", event.Source.Links, want)
	}
}

func TestFailingLinkOmittedEventKept(t *testing.T) {
	for _, tc := range []struct {
		name  string
		links []recordLink
		want  []Link
	}{
		{"malformed url", []recordLink{{Type: "aihot", URL: "https://aihot.news/%zz"}, {Type: "original", URL: "https://x.com/OpenAI/status/1791234567890123456"}},
			[]Link{{Type: "original", URL: "https://x.com/OpenAI/status/1791234567890123456"}}},
		{"all links fail", []recordLink{{Type: "aihot", URL: "http://aihot.news/reset"}, {Type: "original", URL: "https://x.com/OpenAI"}}, nil},
		{"duplicate type keeps first valid", []recordLink{{Type: "aihot", URL: "https://aihot.news/first"}, {Type: "aihot", URL: "https://aihot.news/second"}},
			[]Link{{Type: "aihot", URL: "https://aihot.news/first"}}},
		{"first candidate fails, later valid", []recordLink{{Type: "aihot", URL: "https://evil.test/reset"}, {Type: "aihot", URL: "https://aihot.news/second"}},
			[]Link{{Type: "aihot", URL: "https://aihot.news/second"}}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			event := projectLinks(t, tc.links)
			if !reflect.DeepEqual(event.Source.Links, tc.want) {
				t.Fatalf("links: %+v, want %+v", event.Source.Links, tc.want)
			}
		})
	}
}

func TestLinksDoNotChangeEventIdentity(t *testing.T) {
	without := projectLinks(t, nil)
	with := projectLinks(t, []recordLink{{Type: "aihot", URL: "https://aihot.news/openai-codex-reset-2026-11"}})
	if without.ID != with.ID || without.ID != "record" {
		t.Fatalf("links changed the stable identity: %q vs %q", without.ID, with.ID)
	}
}

func TestConfirmationLinksReplaceAnnouncementLinks(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}
	announcement := record{ID: "event", Provider: "openai", EventType: "direct_reset_announced", Status: "upstream-announced", PublishedAt: now.Add(-time.Hour),
		Links: []recordLink{{Type: "aihot", URL: "https://aihot.news/announcement"}, {Type: "original", URL: "https://x.com/OpenAI/status/1791234567890123456"}}}
	confirmation := record{Provider: "openai", EventType: "direct_reset_reported_complete", Status: "upstream-confirmed", PublishedAt: now, Confirms: "event",
		Links: []recordLink{{Type: "aihot", URL: "https://aihot.news/confirmation"}}}
	encode := func(r record) json.RawMessage {
		b, err := json.Marshal(r)
		if err != nil {
			t.Fatal(err)
		}
		return b
	}
	d := &digest.Digest{PublicationID: "0123456789abcdef01234567", Resets: []json.RawMessage{encode(announcement), encode(confirmation)}}
	events, _ := Project(d, projection, now)
	if len(events) != 1 || events[0].Status != "confirmed" {
		t.Fatalf("confirmation not applied: %+v", events)
	}
	want := []Link{{Type: "aihot", URL: "https://aihot.news/confirmation"}}
	if !reflect.DeepEqual(events[0].Source.Links, want) {
		t.Fatalf("confirmation links: %+v, want %+v", events[0].Source.Links, want)
	}
	// A confirmation without its own links keeps the announcement's citations.
	confirmation.Links = nil
	d.Resets = []json.RawMessage{encode(announcement), encode(confirmation)}
	events, _ = Project(d, projection, now)
	want = []Link{{Type: "aihot", URL: "https://aihot.news/announcement"}, {Type: "original", URL: "https://x.com/OpenAI/status/1791234567890123456"}}
	if len(events) != 1 || !reflect.DeepEqual(events[0].Source.Links, want) {
		t.Fatalf("announcement links not retained: %+v", events)
	}
}

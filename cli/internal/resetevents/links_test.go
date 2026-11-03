// SPDX-License-Identifier: MIT
package resetevents

import (
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"reflect"
	"testing"
	"time"
)

func TestTypedSourceLinkAdmission(t *testing.T) {
	for _, tc := range []struct{ kind, good, personal string }{
		{"aihot", "https://aihot.news/openai-codex-reset-2026-11", "https://aihot.news/users/alice"},
		{"original", "https://x.com/OpenAI/status/1791234567890123456", "https://x.com/user/status/123"},
		{"official", "https://status.openai.com/incidents/kj8w3pn1", "https://status.openai.com/account/alice"},
	} {
		t.Run(tc.kind, func(t *testing.T) {
			for _, raw := range []string{tc.good + "?utm_source=app", tc.good + "?", tc.good + "#fragment", tc.good + "#", tc.personal} {
				if _, ok := admittedLink(tc.kind, raw); ok {
					t.Errorf("admitted unsafe %s", raw)
				}
			}
			if _, ok := admittedLink(tc.kind, tc.good); !ok {
				t.Errorf("rejected %s", tc.good)
			}
		})
	}
	for _, tc := range []struct{ kind, raw string }{{"aihot", "https://user:pass@aihot.news/reset"}, {"aihot", "https://aihot.news.evil.test/reset"}, {"aihot", "https://aihot.news/alice"}, {"official", "https://openai.com/alice"}, {"official", "https://openai.com.evil.test/reset"}, {"original", "https://x.com/OpenAI"}, {"original", "https://x.com/OpenAI/status/abc"}, {"aihot", "https://aihot.news/%75sers/alice"}, {"aihot", "http://aihot.news/reset"}, {"aihot", "https://aihot.news:8443/reset"}, {"aihot", "https://aihot.news:443/reset"}, {"aihot", "https://aihot.news:/reset"}} {
		if _, ok := admittedLink(tc.kind, tc.raw); ok {
			t.Errorf("admitted %s", tc.raw)
		}
	}
}
func TestPublicationFieldsProduceLinks(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	for _, tc := range []struct {
		name, url, observation string
		want                   []Link
	}{
		{"article and original", "https://aihot.news/openai-reset", "https://x.com/OpenAI/status/123", []Link{{Type: "aihot", URL: "https://aihot.news/openai-reset"}, {Type: "original", URL: "https://x.com/OpenAI/status/123"}}},
		{"fields reversed", "https://twitter.com/OpenAI/status/123", "https://aihot.news/openai-reset", []Link{{Type: "aihot", URL: "https://aihot.news/openai-reset"}, {Type: "original", URL: "https://twitter.com/OpenAI/status/123"}}},
		{"no original keeps official", "https://aihot.news/openai-reset", "https://status.openai.com/incidents/abc", []Link{{Type: "aihot", URL: "https://aihot.news/openai-reset"}, {Type: "official", URL: "https://status.openai.com/incidents/abc"}}},
		{"official only", "https://status.openai.com/incidents/abc", "", []Link{{Type: "official", URL: "https://status.openai.com/incidents/abc"}}},
		{"official with original", "https://x.com/OpenAI/status/123", "https://status.openai.com/incidents/abc", []Link{{Type: "official", URL: "https://status.openai.com/incidents/abc"}, {Type: "original", URL: "https://x.com/OpenAI/status/123"}}},
		{"invalid alongside valid", "https://aihot.news/openai-reset?x=123", "https://x.com/OpenAI/status/123", []Link{{Type: "original", URL: "https://x.com/OpenAI/status/123"}}},
		{"no original", "https://aihot.news/openai-reset", "", []Link{{Type: "aihot", URL: "https://aihot.news/openai-reset"}}},
		{"unsafe omitted", "https://aihot.news/openai-reset?email=a", "https://x.com/OpenAI/status/123#x", nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			raw, _ := json.Marshal(map[string]any{"id": "event", "provider": "openai", "eventType": "direct_reset_announced", "status": "upstream-announced", "publishedAt": now.Add(-time.Hour), "url": tc.url, "observationUrl": tc.observation, "links": []map[string]string{{"type": "official", "url": "https://openai.com/extra"}}})
			d := &digest.Digest{PublicationID: "0123456789abcdef01234567", Resets: []json.RawMessage{raw}}
			events, _ := Project(d, rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}, now)
			if len(events) != 1 {
				t.Fatalf("event lost: %+v", events)
			}
			if !reflect.DeepEqual(events[0].Source.Links, tc.want) {
				t.Fatalf("links = %+v; want %+v", events[0].Source.Links, tc.want)
			}
			if events[0].ID != "event" || !events[0].PublishedAt.Equal(now.Add(-time.Hour)) {
				t.Fatalf("facts changed: %+v", events[0])
			}
		})
	}
}

func TestConfirmationUsesPublishedFieldsAndPreservesFacts(t *testing.T) {
	now := time.Date(2026, 11, 1, 12, 0, 0, 0, time.UTC)
	announcement := map[string]any{"id": "event", "provider": "openai", "eventType": "direct_reset_announced", "status": "upstream-announced", "publishedAt": now.Add(-time.Hour), "url": "https://aihot.news/reset-announced", "observationUrl": "https://x.com/OpenAI/status/123"}
	confirmation := map[string]any{"provider": "openai", "eventType": "direct_reset_reported_complete", "status": "upstream-confirmed", "publishedAt": now, "confirms": "event", "url": "https://aihot.news/reset-confirmed", "observationUrl": "https://status.openai.com/incidents/abc"}
	encode := func(v any) json.RawMessage {
		b, err := json.Marshal(v)
		if err != nil {
			t.Fatal(err)
		}
		return b
	}
	project := func() Event {
		d := &digest.Digest{PublicationID: "0123456789abcdef01234567", Resets: []json.RawMessage{encode(announcement), encode(confirmation)}}
		events, dropped := Project(d, rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool}}}, now)
		if len(events) != 1 || dropped != 0 {
			t.Fatalf("events %v dropped %d", events, dropped)
		}
		return events[0]
	}
	event := project()
	want := []Link{{Type: "aihot", URL: "https://aihot.news/reset-confirmed"}, {Type: "official", URL: "https://status.openai.com/incidents/abc"}}
	if event.ID != "event" || event.Status != "confirmed" || event.Confirms != "event" || !event.PublishedAt.Equal(now) || !event.ExpiresAt.Equal(now.Add(24*time.Hour)) || !reflect.DeepEqual(event.Source.Links, want) {
		t.Fatalf("confirmation: %+v", event)
	}
	confirmation["url"] = "https://aihot.news/users/alice"
	confirmation["observationUrl"] = "https://status.openai.com/incidents/abc?tracking=1"
	event = project()
	want = []Link{{Type: "aihot", URL: "https://aihot.news/reset-announced"}, {Type: "original", URL: "https://x.com/OpenAI/status/123"}}
	if !reflect.DeepEqual(event.Source.Links, want) {
		t.Fatalf("unsafe confirmation changed citations: %+v", event.Source.Links)
	}
}

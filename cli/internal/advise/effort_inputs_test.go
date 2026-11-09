// SPDX-License-Identifier: MIT
package advise

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

func resetRecord(id, status string, through time.Duration) json.RawMessage {
	b, _ := json.Marshal(map[string]any{"id": id, "provider": "openai", "eventType": "direct_reset_announced", "status": status,
		"schedule": map[string]string{"through": now.Add(through).Format(time.RFC3339)}})
	return b
}

func TestAnnouncedResetsOnlyCountsStandingAnnouncements(t *testing.T) {
	d := &digest.Digest{PublicationID: "p"}
	d.Resets = []json.RawMessage{
		resetRecord("a", "upstream-announced", 20*time.Hour),
		resetRecord("b", "upstream-confirmed", 10*time.Hour),
		resetRecord("c", "upstream-announced", 5*time.Hour),
		resetRecord("c", "withdrawn", 5*time.Hour), // withdrawn later: ignored
		resetRecord("d", "cancelled", 3*time.Hour),
		resetRecord("e", "rumoured", 2*time.Hour),          // not confirmed upstream: ignored
		resetRecord("f", "upstream-announced", -time.Hour), // already past
	}
	got := AnnouncedResets(d, "codex", now)
	if len(got) != 2 || !got[0].Equal(now.Add(10*time.Hour)) || !got[1].Equal(now.Add(20*time.Hour)) {
		t.Fatalf("got %v", got)
	}
	if AnnouncedResets(d, "claude-code", now) != nil || AnnouncedResets(nil, "codex", now) != nil {
		t.Fatal("another vendor's or a missing publication's resets counted")
	}
	// Re-read on every publication: dropping the announcement drops the gate at once.
	d.Resets = nil
	if AnnouncedResets(d, "codex", now) != nil {
		t.Fatal("stale announcement")
	}
}

func TestResetUnusedReusesTheSurplusEvents(t *testing.T) {
	es := []Event{{Source: "claude-code", Type: WindowTight}, {Source: "codex", Type: ResetSoonSurplus}}
	if ResetUnused(es, "claude-code") || !ResetUnused(es, "codex") {
		t.Fatal("wrong source or type")
	}
	if !ResetUnused([]Event{{Source: "claude-code", Type: AnnouncedSurplus}}, "claude-code") {
		t.Fatal("announced surplus not counted")
	}
}

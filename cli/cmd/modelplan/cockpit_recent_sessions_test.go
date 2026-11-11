// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// D63: the 7-day time view's sessions come from the recorded ledger, bounded to seven days and 200 rows, newest
// first, with only a last sighting, the last day's model and effort, a project label while labels are on and a
// verified subscription.
func TestCockpitRecentSessionsKeepsSevenBoundedDaysOfLastSightings(t *testing.T) {
	now := time.Date(2026, 11, 8, 12, 0, 0, 0, time.UTC)
	day := func(model, effort, status string) []speed.SessionDay {
		return []speed.SessionDay{{Day: "2026-11-01", Model: "other", Effort: "low", EffortStatus: "reported"}, {Day: "2026-11-02", Model: model, Effort: effort, EffortStatus: status}}
	}
	sessions := []speed.PerfSession{
		{Ref: "1111111111111111", Source: "codex", ProjectRef: "p1", ProjectLabel: "Synthetic project", SubscriptionRef: "aaaaaaaaaaaaaaaa", LastAt: now.Add(-2 * time.Hour), Days: day("synthetic-alias", "high", "reported")},
		{Ref: "2222222222222222", Source: "codex", SubscriptionRef: "bbbbbbbbbbbbbbbb", LastAt: now.Add(-6 * 24 * time.Hour), Days: day("unknown-secret", "secret", "reported")},
		{Ref: "3333333333333333", Source: "codex", LastAt: now.Add(-8 * 24 * time.Hour), Days: day("synthetic-alias", "high", "reported")},
		{Ref: "4444444444444444", Source: "claude-code", LastAt: now.Add(-time.Hour), Days: day("synthetic-alias", "high", "reported")},
		{Ref: "not-a-reference", Source: "codex", LastAt: now.Add(-time.Hour)},
		{Ref: "5555555555555555", Source: "codex", LastAt: now.Add(time.Hour)},
		{Ref: "6666666666666666", Source: "codex", LastAt: now.Add(-time.Minute), Days: day("synthetic-alias", "medium", "unreported")},
	}
	allowed := map[string]bool{consent.ScopeCodexLocalHistory: true}
	scopes := map[string]string{"codex": consent.ScopeCodexLocalHistory, "claude-code": consent.ScopeClaudeLocalHistory}
	verified := map[string]*wire.CockpitSubscriptionDetails{"aaaaaaaaaaaaaaaa": {}}
	models := []digest.Model{{ID: "public-model", HarnessIDs: map[string][]string{"codex": {"synthetic-alias"}}}}
	got := cockpitRecentSessions(sessions, allowed, scopes, verified, true, models, now)
	if len(got) != 3 || got[0].SessionRef != "6666666666666666" || got[1].SessionRef != "1111111111111111" || got[2].SessionRef != "2222222222222222" {
		t.Fatalf("seven admitted days, newest first, references only: %+v", got)
	}
	first := got[1]
	if first.Model != "public-model" || first.Effort == nil || *first.Effort != "high" || first.ProjectLabel == nil || *first.ProjectLabel != "Synthetic project" ||
		first.SubscriptionRef == nil || *first.SubscriptionRef != "aaaaaaaaaaaaaaaa" || !first.LastObservedAt.Equal(now.Add(-2*time.Hour)) {
		t.Fatalf("last day and verified binding: %+v", first)
	}
	if got[2].Model != "unknown" || got[2].Effort != nil || got[2].SubscriptionRef != nil {
		t.Fatalf("untrusted fields and unverified bindings stay out: %+v", got[2])
	}
	if got[0].Effort != nil {
		t.Fatalf("an unreported effort stays unknown: %+v", got[0])
	}
	if hidden := cockpitRecentSessions(sessions, allowed, scopes, verified, false, models, now); hidden[1].ProjectLabel != nil {
		t.Fatalf("project labels off: %+v", hidden[1])
	}
	many := make([]speed.PerfSession, 0, 260)
	for i := 0; i < 260; i++ {
		many = append(many, speed.PerfSession{Ref: "7777777777777" + string(rune('a'+i%6)) + string(rune('a'+(i/6)%6)) + string(rune('a'+(i/36)%6)), Source: "codex", LastAt: now.Add(-time.Duration(i) * time.Minute)})
	}
	if capped := cockpitRecentSessions(many, allowed, scopes, verified, true, models, now); len(capped) != 200 || !capped[0].LastObservedAt.Equal(now) {
		t.Fatalf("capped at 200 newest: %d", len(capped))
	}
}

// glm-737-1: the model and effort come from the newest day by date even when the days were read out of order.
func TestCockpitRecentSessionsTakeTheNewestDayByDate(t *testing.T) {
	now := time.Date(2026, 11, 8, 12, 0, 0, 0, time.UTC)
	sessions := []speed.PerfSession{{Ref: "1111111111111111", Source: "codex", LastAt: now.Add(-time.Hour), Days: []speed.SessionDay{
		{Day: "2026-11-05", Model: "synthetic-alias", Effort: "high", EffortStatus: "reported"},
		{Day: "2026-11-02", Model: "other", Effort: "low", EffortStatus: "reported"}}}}
	models := []digest.Model{{ID: "public-model", HarnessIDs: map[string][]string{"codex": {"synthetic-alias"}}}}
	got := cockpitRecentSessions(sessions, map[string]bool{consent.ScopeCodexLocalHistory: true}, map[string]string{"codex": consent.ScopeCodexLocalHistory}, nil, true, models, now)
	if len(got) != 1 || got[0].Model != "public-model" || got[0].Effort == nil || *got[0].Effort != "high" {
		t.Fatalf("newest day by date: %+v", got)
	}
}

// The field crosses the app-server only for a client that negotiated cockpitSessionsV1.
func TestCockpitRecentSessionsNeedTheNegotiatedCapability(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	epoch := &speed.GrantEpoch{StoreEpoch: state.StoreEpoch, RevokedGeneration: 0}
	cache := t.TempDir()
	ledger := speed.PerfLedger{SchemaVersion: 1, Since: now.Add(-48 * time.Hour), Rows: []speed.PerfRow{}, Live: []speed.LiveRecord{},
		Sessions: []speed.PerfSession{{Ref: "1111111111111111", Source: "codex", LastAt: now.Add(-24 * time.Hour), GrantEpoch: epoch}}}
	if err := os.MkdirAll(filepath.Dir(speed.PerfPath(cache)), 0700); err != nil {
		t.Fatal(err)
	}
	payload, err := json.Marshal(ledger)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(speed.PerfPath(cache), payload, 0600); err != nil {
		t.Fatal(err)
	}
	admission := queries.CockpitAdmission{Stamp: appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}, Scopes: []string{consent.ScopeCodexLocalHistory}}
	got, err := (sharedCockpit{cache: cache}).cockpitDetails(context.Background(), appserver.View{}, admission, nil)
	if err != nil || got.RecentSessions != nil {
		t.Fatalf("without the capability the field is omitted: %+v, %v", got.RecentSessions, err)
	}
	got, err = (sharedCockpit{cache: cache}).cockpitDetails(appserver.WithCockpitSessionsForTest(context.Background()), appserver.View{}, admission, nil)
	if err != nil || len(got.RecentSessions) != 1 || got.RecentSessions[0].SessionRef != "1111111111111111" {
		t.Fatalf("negotiated, the admitted recorded session crosses: %+v, %v", got.RecentSessions, err)
	}
}

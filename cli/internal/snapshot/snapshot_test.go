package snapshot

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

var now = time.Date(2026, 10, 18, 9, 0, 0, 0, time.UTC)

func f(v float64) *float64 { return &v }

func fixture() (*digest.Digest, quota.Report) {
	e := func(k, l string, a, c float64) digest.Effort {
		return digest.Effort{Effort: k, Label: l, Ability: f(a), Cost: f(c), CostBasisID: "ref"}
	}
	d := &digest.Digest{Models: []digest.Model{{ID: "opus", Name: "Claude Opus 5.5", DeveloperID: "anthropic", Recommended: "medium",
		HarnessIDs: map[string][]string{"claude-code": {"claude-opus-5-5"}}, Efforts: []digest.Effort{e("medium", "Med", 55.4, 2.91), e("high", "High", 60.2, 3.98)}}}}
	seen := now.Add(-2 * time.Minute)
	fast := true
	r := quota.Report{SchemaVersion: 1, EvaluatedAt: now, Accounts: []quota.Account{
		{Source: "claude-code", ObservedAt: seen, Headroom: "normal", Deciding: "five_hour", Harness: &quota.Harness{Model: "claude-opus-5-5", Effort: "high", FastMode: &fast, ObservedAt: &seen, Attribution: "current-thread"}},
		{Source: "codex", ObservedAt: seen, Headroom: "conserve", Pool: "reserve", Harness: &quota.Harness{Model: "gpt-9-unknown", ServiceTier: "fast", ObservedAt: &seen}},
		{Source: "codexbar:zai", ObservedAt: seen, Headroom: "normal"},
	}, Sources: []quota.SourceStatus{{Source: "claude-code", Status: "ok"}}}
	return d, r
}

func TestSnapshot(t *testing.T) {
	d, r := fixture()
	ev := advise.Event{Type: advise.WindowTight, Key: "window_tight|claude-code||five_hour||x", Severity: "warn", Source: "claude-code", Window: "five_hour",
		RemainingPercent: f(12), Model: "claude-opus-5-5", Effort: "high", Suggest: &advise.Step{Action: "step_down", Label: "Med", Recommended: true, AbilityDelta: f(-4.8), CostRatio: f(0.73)}}
	s := Build(Input{Report: r, Digest: d, State: store.State{PublicationID: "p1", PublishedAt: "2026-10-18T08:00:00Z", CheckedAt: now.Add(-time.Hour)},
		Events: []advise.Event{ev}, Measured: []speed.Stat{{Source: "claude-code", Model: "claude-opus-5-5", Effort: "high", Turns: 7}}, Recording: true, CLIVersion: "0.5.25", Now: now})
	if s.Kind != Kind || s.SchemaVersion != 1 || s.Publication == nil || s.Publication.Stale || len(s.Accounts) != 3 || len(s.Measured) != 1 {
		t.Fatalf("snapshot = %+v", s)
	}
	if len(s.Sessions) != 2 {
		t.Fatalf("CodexBar accounts are not sessions: %+v", s.Sessions)
	}
	cc := s.Sessions[0]
	if cc.Model.ID != "opus" || cc.Effort == nil || cc.Effort.Label != "High" || cc.Effort.Star || cc.Recommended.Label != "Med" || cc.Speed != "fast" ||
		*cc.VsRecommended.AbilityDelta != 4.8 || *cc.VsRecommended.CostRatio != 1.37 || cc.Attribution != "current-thread" {
		t.Errorf("claude-code session = %+v", cc)
	}
	cx := s.Sessions[1]
	if cx.Model.ID != "" || cx.Model.HarnessID != "gpt-9-unknown" || cx.Effort != nil || cx.Speed != "fast" || cx.Pool != "reserve" || cx.Headroom != "conserve" {
		t.Errorf("an unlisted model keeps what the harness said: %+v", cx)
	}
	e := s.Events[0]
	if e.Key != advise.ConfigKey(ev) || !strings.Contains(e.Text["zh"], "降到 ★Med") || e.Short["zh"] != "↓★Med ×0.73" || e.Short["en"] != "↓★Med ×0.73" || !e.InMenuBar {
		t.Errorf("event = %+v", e)
	}
	b, _ := json.Marshal(s)
	for _, want := range []string{`"kind":"modelplan.personal-snapshot"`, `"type":"window_tight"`, `"short":{`, `"inMenuBar":true`, `"vsRecommended":{"abilityDelta":4.8,"costRatio":1.37}`} {
		if !strings.Contains(string(b), want) {
			t.Errorf("missing %s in %s", want, b)
		}
	}
	if strings.Contains(string(b), "\x1b[") {
		t.Error("no terminal colours in the snapshot")
	}
}

func TestEmptySnapshotHasNoNulls(t *testing.T) {
	s := Build(Input{Now: now})
	b, _ := json.Marshal(s)
	for _, k := range []string{`"sessions":[]`, `"accounts":[]`, `"sources":[]`, `"events":[]`, `"measured":[]`, `"publication":null`} {
		if !strings.Contains(string(b), k) {
			t.Errorf("missing %s in %s", k, b)
		}
	}
	old := Build(Input{Digest: &digest.Digest{}, State: store.State{PublicationID: "p0", CheckedAt: now.Add(-49 * time.Hour)}, Now: now})
	if old.Publication == nil || !old.Publication.Stale {
		t.Errorf("a publication unchecked for two days is stale: %+v", old.Publication)
	}
}

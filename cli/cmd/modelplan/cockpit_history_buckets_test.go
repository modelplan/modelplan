// SPDX-License-Identifier: MIT
package main

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

func TestCockpitBucketsSumModelsAndKeepAdmittedSourcesOnly(t *testing.T) {
	old := time.Local
	time.Local = time.UTC
	t.Cleanup(func() { time.Local = old })
	now := time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
	day, older := "2026-11-04", now.AddDate(0, 0, -200).Format("2006-01-02")
	hour := "2026-11-05T10:00:00Z"
	perf := speed.PerfView{OK: true, LongOK: true, Recording: true, Now: now,
		Ledger: speed.PerfLedger{Since: now.AddDate(0, 0, -300), Hourly: []speed.Hourly{
			{Hour: hour, Source: "codex", Model: "a", ObservedOutputTokens: 5},
			{Hour: hour, Source: "codex", Model: "b", ObservedOutputTokens: 6},
			{Hour: hour, Source: "zcode", Model: "c", ObservedOutputTokens: 7},
		}},
		Long: speed.LongLedger{Since: now.AddDate(0, 0, -300), Rows: []speed.Daily{
			{Day: day, Source: "codex", Model: "a", ObservedOutputTokens: 10},
			{Day: day, Source: "codex", Model: "b", ObservedOutputTokens: 20},
			{Day: day, Source: "zcode", Model: "c", ObservedOutputTokens: 40},
			{Day: older, Source: "codex", Model: "a", ObservedOutputTokens: 80},
		}}}
	from, days, hours := cockpitBuckets(perf, map[string]bool{"codex": true}, now)
	if len(days) != 1 || days[0].At != day || days[0].Source != "codex" || days[0].ObservedOutputTokens != 30 {
		t.Fatalf("days = %+v", days)
	}
	if from == nil || *from != now.AddDate(0, 0, -181).Format("2006-01-02") {
		t.Fatalf("from = %v", from)
	}
	if len(hours) != 1 || hours[0].ObservedOutputTokens != 11 {
		t.Fatalf("hours = %+v", hours)
	}
}

func TestCockpitProjectsCarryLabelsOnlyWhileTheyAreOn(t *testing.T) {
	label, unsafe := "desktop", "a/b"
	r := speed.ProjectRanking{Recent7d: speed.ProjectWindow{Top: []speed.RankedProject{
		{Ref: "p1", Label: &label, ObservedOutputTokens: 9, Share: .9, Configs: []speed.SessionConfig{{Model: "sol", Effort: "high"}}}, {Ref: "p2", Label: &unsafe, ObservedOutputTokens: 1, Share: .1}}}}
	on := cockpitProjects(r, true, []digest.Model{{ID: "sol"}})
	if m, e := on.Recent7d[0].Model, on.Recent7d[0].Effort; m == nil || *m != "sol" || e == nil || *e != "high" || on.Recent7d[1].Model != nil {
		t.Fatalf("config = %+v", on.Recent7d)
	}
	if len(on.Recent7d) != 2 || on.Recent7d[0].Label == nil || *on.Recent7d[0].Label != label || on.Recent7d[1].Label != nil || on.Recent30d == nil {
		t.Fatalf("on = %+v", on)
	}
	if off := cockpitProjects(r, false, nil); off.Recent7d[0].Label != nil {
		t.Fatalf("off = %+v", off)
	}
}

func TestCockpitModelRankingCarriesOnlyPublishedModels(t *testing.T) {
	window := wire.CockpitEntityWindow{Entities: 3, TotalObservedOutputTokens: 30, Top: []wire.CockpitRankedEntity{
		{Name: "sol", ObservedOutputTokens: 10}, {Name: "harness-alias", ObservedOutputTokens: 10}, {Name: "synthetic-unverified-model-alias", ObservedOutputTokens: 10}}}
	models := []digest.Model{{ID: "sol"}, {ID: "opus", HarnessIDs: map[string][]string{"claude-code": {"harness-alias"}}}}
	got := cockpitPublishedModels(wire.CockpitEntityRanking{Recent7d: window, Recent30d: window}, models).Recent7d
	if len(got.Top) != 2 || got.Top[0].Name != "sol" || got.Top[1].Name != "opus" || got.TotalObservedOutputTokens != 30 {
		t.Fatalf("top = %+v", got)
	}
}

func TestCockpitCyclesKeepClosedCyclesOfBoundAdmittedSources(t *testing.T) {
	ref, now := "0123456789abcdef", time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
	cycles := []history.PaceCycleView{{Closed: false, ResetsAt: now.Add(time.Hour)}}
	for i := 0; i < 12; i++ {
		cycles = append(cycles, history.PaceCycleView{Closed: true, ResetsAt: now.Add(-time.Duration(i) * time.Hour), Points: float64(i),
			Spent: []history.Share{{Model: "sol", Effort: "high", Points: 1}, {Model: "local-alias", Effort: "custom", Points: 1}}})
	}
	groups := []history.PaceGroup{{Source: "codex", Kind: "five_hour", Attribution: "unattributed", Cycles: cycles},
		{Source: "codex", Kind: "five_hour", Limit: "other", Cycles: cycles}, {Source: "unbound", Kind: "weekly", Cycles: cycles}, {Source: "denied", Kind: "weekly", Cycles: cycles}}
	got := cockpitCycles(groups, map[string]string{"codex": ref, "denied": ref}, map[string]bool{"codex": true, "unbound": true}, map[string][]wire.CockpitAccount{ref: {}}, []digest.Model{{ID: "sol"}})
	if len(got) != 1 || len(got[0].Cycles) != 10 {
		t.Fatalf("groups = %+v", got)
	}
	spent := got[0].Cycles[0].Spent
	if *spent[0].Model != "sol" || *spent[0].Effort != "high" || spent[1].Model != nil || spent[1].Effort != nil {
		t.Fatalf("spent = %+v", spent)
	}
}

// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

func usageFixture(now time.Time) speed.PerfView {
	total := int64(1500)
	in, read, write := int64(300), int64(1000), int64(100)
	d := speed.SessionDay{Day: now.Local().Format("2006-01-02"), Model: "synthetic-alias", EffortStatus: "reported", Effort: "high", ObservedRequests: 1, ObservedOutputTokens: 100,
		Kinds: &speed.TokenKinds{TotalTokens: &total, InputTokens: &in, CacheReadTokens: &read, CacheWriteTokens: &write}}
	return speed.PerfView{OK: true, Recording: true, Now: now, Ledger: speed.PerfLedger{Sessions: []speed.PerfSession{
		{Ref: "1111111111111111", Key: "k1", Source: "codex", ProjectRef: "r1", ProjectLabel: "sample-site", ProjectKind: speed.KindRepo, ProjectRule: speed.CurrentProjectRule, Title: "Fix the tape", LastAt: now, FirstAt: now, Days: []speed.SessionDay{d}},
		{Ref: "2222222222222222", Key: "k2", Source: "codex", ProjectRef: "r2", ProjectKind: speed.KindIndependent, ProjectRule: speed.CurrentProjectRule, Title: "A chat", LastAt: now, FirstAt: now, Days: []speed.SessionDay{d}},
		{Ref: "3333333333333333", Key: "k3", Source: "claude-code", ProjectRef: "r3", ProjectKind: speed.KindHome, ProjectRule: speed.CurrentProjectRule, LastAt: now, FirstAt: now, Days: []speed.SessionDay{d}},
		{Ref: "4444444444444444", Key: "k4", Source: "gemini", ProjectRef: "r4", ProjectLabel: "hidden-source", ProjectKind: speed.KindRepo, ProjectRule: speed.CurrentProjectRule, LastAt: now, FirstAt: now, Days: []speed.SessionDay{d}},
	}}}
}

func TestCockpitUsageWireShapeAndLabelSwitch(t *testing.T) {
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	models := []digest.Model{{ID: "public-model", HarnessIDs: map[string][]string{"codex": {"synthetic-alias"}, "claude-code": {"synthetic-alias"}}}}
	allowed := map[string]bool{"codex": true, "claude-code": true}
	on := cockpitUsage(usageFixture(now), allowed, true, models, nil)
	w := on.Today
	if on.Measure != "total-tokens" || w.SessionCount != 3 || w.Tokens.Total != 4500 || len(w.Sessions) != 3 || len(w.Projects) != 3 {
		t.Fatalf("%+v", w)
	}
	byRef := map[string]wire.CockpitUsageSession{}
	for _, s := range w.Sessions {
		byRef[s.SessionRef] = s
	}
	repo, indep, home := byRef["1111111111111111"], byRef["2222222222222222"], byRef["3333333333333333"]
	if repo.ProjectState != wire.ProjectNamed || repo.ProjectLabel == nil || *repo.ProjectLabel != "sample-site" || repo.Title == nil || *repo.Title != "Fix the tape" || repo.Model == nil || *repo.Model != "public-model" {
		t.Fatalf("%+v", repo)
	}
	// Buckets are "no project" with their kind and no label; a cost nobody can price is null, never zero.
	if indep.ProjectState != wire.ProjectNone || indep.ProjectLabel != nil || indep.ProjectKind != wire.ProjectKindIndependent || home.ProjectKind != wire.ProjectKindHome || home.ProjectLabel != nil {
		t.Fatalf("%+v %+v", indep, home)
	}
	if repo.CostUsd != nil || repo.CostState != wire.CostStateUnpriced || repo.Share < 0.33 || repo.Share > 0.34 {
		t.Fatalf("%+v", repo)
	}
	if w.BackgroundReview != nil {
		t.Fatal("no review runs")
	}
	// Labels off: no label and no title cross; kinds and references stay.
	off := cockpitUsage(usageFixture(now), allowed, false, models, nil)
	b, _ := json.Marshal(off)
	for _, leak := range []string{"sample-site", "Fix the tape", "A chat", "hidden-source"} {
		if strings.Contains(string(b), leak) {
			t.Fatalf("%q with labels off: %s", leak, b)
		}
	}
	if s := off.Today.Sessions[0]; s.ProjectState != wire.ProjectHidden && s.ProjectState != wire.ProjectNone {
		t.Fatalf("%+v", s)
	}
}

func TestCockpitProjectStateByKind(t *testing.T) {
	ref, label := "r", "sample-site"
	for _, c := range []struct {
		kind   wire.CockpitProjectKind
		labels bool
		want   wire.CockpitProjectState
	}{
		{wire.ProjectKindRepo, true, wire.ProjectNamed}, {wire.ProjectKindRepo, false, wire.ProjectHidden}, {wire.ProjectKindWorkspace, true, wire.ProjectNamed},
		{wire.ProjectKindHome, true, wire.ProjectNone}, {wire.ProjectKindIndependent, true, wire.ProjectNone}, {wire.ProjectKindNone, false, wire.ProjectNone}, {"", true, wire.ProjectNamed},
	} {
		if got, _ := cockpitProjectState(&ref, &label, c.kind, c.labels); got != c.want {
			t.Errorf("%q labels=%v: %q, want %q", c.kind, c.labels, got, c.want)
		}
	}
	if got, _ := cockpitProjectState(nil, nil, wire.ProjectKindRepo, true); got != wire.ProjectNone {
		t.Error("no reference is no project")
	}
}

func TestEnrichRecentSessionsAddsTotalsAndNeverZero(t *testing.T) {
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	v := usageFixture(now)
	v.Ledger.Sessions[0].Days = append(v.Ledger.Sessions[0].Days, speed.SessionDay{Day: "2026-11-20", Model: "m", ObservedOutputTokens: 5}) // before token kinds
	out := []wire.CockpitRecentSession{{SessionRef: "1111111111111111"}, {SessionRef: "2222222222222222"}, {SessionRef: "9999999999999999"}}
	enrichRecentSessions(out, v, nil)
	if out[0].TotalTokens != nil || out[1].TotalTokens == nil || *out[1].TotalTokens != 1500 || out[2].TotalTokens != nil || out[1].CostUsd != nil {
		t.Fatalf("%+v", out)
	}
}

// Master spec §7.1: a project row's hover shows its first active, the earliest first turn among its sessions.
func TestCockpitUsageProjectFirstObservedAt(t *testing.T) {
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	total := int64(100)
	d := speed.SessionDay{Day: "2026-11-26", Model: "synthetic-alias", EffortStatus: "unreported", ObservedRequests: 1, ObservedOutputTokens: 10, Kinds: &speed.TokenKinds{TotalTokens: &total}}
	early, late := now.Add(-5*time.Hour), now.Add(-time.Hour)
	v := speed.PerfView{OK: true, Recording: true, Now: now, Ledger: speed.PerfLedger{Sessions: []speed.PerfSession{
		{Ref: "1111111111111111", Key: "k1", Source: "codex", ProjectRef: "r1", ProjectKind: speed.KindRepo, ProjectRule: speed.CurrentProjectRule, FirstAt: late, LastAt: now, Days: []speed.SessionDay{d}},
		{Ref: "2222222222222222", Key: "k2", Source: "codex", ProjectRef: "r1", ProjectKind: speed.KindRepo, ProjectRule: speed.CurrentProjectRule, FirstAt: early, LastAt: late, Days: []speed.SessionDay{d}},
	}}}
	u := cockpitUsage(v, map[string]bool{"codex": true}, true, nil, nil)
	if len(u.Today.Projects) != 1 || !u.Today.Projects[0].FirstObservedAt.Equal(early) || !u.Today.Projects[0].LastObservedAt.Equal(now) {
		t.Fatalf("%+v", u.Today.Projects)
	}
}

// macrevb-1303-4: at the full cap (200 projects and 200 sessions in every range) with long Unicode names and titles,
// the usage ranking stays within its share of the 1 MiB cockpit message; fewer rows are listed, the rest are summed
// into "other", and the totals stay exact.
func TestCockpitUsageStaysWithinItsMessageBudget(t *testing.T) {
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	label := strings.Repeat("项目名", 22)  // 198 bytes, the label bound
	title := strings.Repeat("会话标题", 24) // 96 runes, the title bound
	var sessions []speed.PerfSession
	for i := 0; i < 2*speed.RankCap; i++ {
		total, in := int64(1000+i), int64(500)
		d := speed.SessionDay{Day: "2026-11-26", Model: "synthetic-alias", EffortStatus: "reported", Effort: "high", ObservedRequests: 1, ObservedOutputTokens: 10,
			Kinds: &speed.TokenKinds{TotalTokens: &total, InputTokens: &in}}
		sessions = append(sessions, speed.PerfSession{Ref: fmt.Sprintf("%016x", i+1), Key: fmt.Sprint(i), Source: "codex", ProjectRef: fmt.Sprintf("%032x", i),
			ProjectLabel: fmt.Sprintf("%s%d", label[:len(label)-3], i), ProjectKind: speed.KindRepo, ProjectRule: speed.CurrentProjectRule, Title: title,
			SubscriptionRef: "aaaaaaaaaaaaaaaa", FirstAt: now.Add(-time.Hour), LastAt: now, Days: []speed.SessionDay{d}})
	}
	v := speed.PerfView{OK: true, Recording: true, Now: now, Ledger: speed.PerfLedger{Sessions: sessions}}
	models := []digest.Model{{ID: "public-model", HarnessIDs: map[string][]string{"codex": {"synthetic-alias"}}}}
	u := cockpitUsage(v, map[string]bool{"codex": true}, true, models, nil)
	b, err := json.Marshal(u)
	if err != nil {
		t.Fatal(err)
	}
	if len(b) > cockpitUsageBudget {
		t.Fatalf("usage takes %d bytes, budget %d", len(b), cockpitUsageBudget)
	}
	for _, w := range []wire.CockpitUsageWindow{u.Today, u.Recent7d, u.Recent30d} {
		if w.SessionCount != 2*speed.RankCap || w.OtherSessions.Count == 0 || len(w.Sessions)+w.OtherSessions.Count != w.SessionCount {
			t.Fatalf("sessions %d listed + %d other, of %d", len(w.Sessions), w.OtherSessions.Count, w.SessionCount)
		}
		if len(w.Projects)+w.OtherProjects.Count != w.ProjectCount {
			t.Fatalf("projects %d listed + %d other, of %d", len(w.Projects), w.OtherProjects.Count, w.ProjectCount)
		}
		sum := w.OtherSessions.Tokens.Total
		for _, s := range w.Sessions {
			sum += s.Tokens.Total
		}
		if sum != w.Tokens.Total {
			t.Fatalf("listed + other = %d, total %d", sum, w.Tokens.Total)
		}
	}
	// A small ledger keeps every row.
	small := speed.PerfView{OK: true, Recording: true, Now: now, Ledger: speed.PerfLedger{Sessions: sessions[:20]}}
	if w := cockpitUsage(small, map[string]bool{"codex": true}, true, models, nil).Today; len(w.Sessions) != 20 || w.OtherSessions.Count != 0 {
		t.Fatalf("a small ledger was cut: %d listed, %d other", len(w.Sessions), w.OtherSessions.Count)
	}
}

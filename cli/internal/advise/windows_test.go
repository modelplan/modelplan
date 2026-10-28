package advise

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func windowDigest() (*digest.Digest, time.Time) {
	at := time.Date(2026, 10, 28, 7, 59, 0, 0, time.UTC)
	d := &digest.Digest{MultiplierHorizon: &digest.MultiplierHorizon{From: at.Add(-time.Hour).Format(time.RFC3339), To: at.Add(48 * time.Hour).Format(time.RFC3339), Selection: "highest-priority-no-stacking"}}
	d.Models = []digest.Model{{ID: "model", Name: "Model", Recommended: "high", Efforts: []digest.Effort{{Effort: "high", Cost: f(2)}}}}
	w := func(rule string, rate float64, prio int, from, to time.Duration) digest.MultiplierWindow {
		return digest.MultiplierWindow{RuleID: rule, Provider: "synthetic", PlanIDs: []string{"pro", "max"}, Region: "china", Timezone: "Asia/Shanghai", Multiplier: f(rate), Priority: prio, StartsAt: at.Add(from).Format(time.RFC3339), EndsAt: at.Add(to).Format(time.RFC3339), Status: "CONFIRMED"}
	}
	d.Multipliers = []digest.MultiplierWindow{w("base", 1, 0, -time.Hour, 48*time.Hour), w("peak", 3, 10, -time.Hour, time.Minute), w("night", 0.5, 20, time.Minute, 8*time.Hour)}
	return d, at
}

func TestWindowPriorityNoStackingAndShanghaiBoundary(t *testing.T) {
	d, at := windowDigest()
	gs := Windows(d, WindowFilter{Provider: "synthetic", Plan: "pro", Region: "china"}, at)
	if len(gs) != 1 || len(gs[0].Series) != 1 {
		t.Fatalf("groups=%+v", gs)
	}
	s := gs[0].Series[0]
	if s.Now.Multiplier == nil || *s.Now.Multiplier != 3 || len(s.Changes) != 2 || *s.Changes[0].Multiplier != 0.5 {
		t.Fatalf("timeline=%+v", s)
	}
	loc, err := time.LoadLocation("Asia/Shanghai")
	if err != nil {
		t.Fatal(err)
	}
	if got := s.Changes[0].At.In(loc).Format("15:04"); got != "16:00" {
		t.Fatal(got)
	}
	gs = Windows(d, WindowFilter{Plan: "pro", Region: "china"}, at.Add(time.Minute))
	if got := *gs[0].Series[0].Now.Multiplier; got != 0.5 {
		t.Fatalf("half-open boundary=%v", got)
	}
	for _, filter := range []WindowFilter{{Provider: "other"}, {Plan: "other"}, {Region: "international"}} {
		if got := Windows(d, filter, at); len(got) != 0 {
			t.Fatalf("filter=%+v got=%+v", filter, got)
		}
	}
}

func TestWindowSubsetPlanOverrideAndModelAlias(t *testing.T) {
	d, at := windowDigest()
	d.Multipliers = d.Multipliers[:1]
	override := d.Multipliers[0]
	override.RuleID = "override"
	override.PlanIDs = []string{"pro"}
	override.Models = []string{"Model"}
	override.Multiplier = f(0.4)
	override.Priority = 10
	override.Status = "TENTATIVE"
	d.Multipliers = append(d.Multipliers, override)
	for _, tc := range []struct {
		plan   string
		want   float64
		status string
	}{{"pro", 0.4, "TENTATIVE"}, {"max", 1, "CONFIRMED"}} {
		gs := Windows(d, WindowFilter{Plan: tc.plan, Model: "model"}, at)
		if len(gs) != 1 || len(gs[0].Series) != 1 {
			t.Fatalf("groups=%+v", gs)
		}
		r := gs[0].Series[0].Now
		if r.Multiplier == nil || *r.Multiplier != tc.want || r.Status != tc.status {
			t.Fatalf("plan=%s rate=%+v", tc.plan, r)
		}
	}
}

func TestWindowConflictTentativeAndHorizonUnknown(t *testing.T) {
	d, at := windowDigest()
	match := func(*digest.MultiplierWindow) bool { return true }
	d.Multipliers[1].Status = "TENTATIVE"
	r, s := publishedRate(d, match, at)
	if r == nil || *r != 3 || s != "TENTATIVE" {
		t.Fatalf("%v %s", r, s)
	}
	conflicting := d.Multipliers[1]
	conflicting.Multiplier = f(2)
	d.Multipliers = append(d.Multipliers, conflicting)
	if r, _ := publishedRate(d, match, at); r != nil {
		t.Fatal("conflict resolved as a number")
	}
	d.Multipliers = d.Multipliers[:3]
	for _, when := range []time.Time{at.Add(48 * time.Hour), at.Add(-2 * time.Hour)} {
		gs := Windows(d, WindowFilter{}, when)
		if len(gs) != 1 || gs[0].Series[0].Now.Multiplier != nil || len(gs[0].Series[0].Changes) != 0 {
			t.Fatalf("outside horizon=%+v", gs)
		}
	}
	d.MultiplierHorizon.Selection = "stack"
	if r, _ := publishedRate(d, match, at); r != nil {
		t.Fatal("unsupported selection")
	}
}

func TestBillingContextDeclaredPlanRegionAndCheaperOption(t *testing.T) {
	d, at := windowDigest()
	models := []*digest.Model{&d.Models[0]}
	if got := Billing(d, quota.Report{}, models, at); len(got) != 0 {
		t.Fatal(got)
	}
	report := quota.Report{Accounts: []quota.Account{{Source: "user", Plan: "pro", Region: "china"}, {Source: "native:synthetic", Plan: "max"}}}
	got := Billing(d, report, models, at)
	if len(got) != 1 || *got[0].MultiplierNow != 3 || *got[0].BaseCost != 2 || *got[0].EffectiveCost != 6 || got[0].NextCheaperAt == nil || !got[0].NextCheaperAt.Equal(at.Add(time.Minute)) {
		t.Fatalf("billing=%+v", got)
	}
	report.Accounts[0].Region = "international"
	if got := Billing(d, report, models, at); len(got) != 0 {
		t.Fatal(got)
	}
	report.Accounts[0].Region = "china"
	got = Billing(d, report, models, at.Add(48*time.Hour))
	if len(got) != 1 || got[0].MultiplierNow != nil || got[0].EffectiveCost != nil || got[0].NextCheaperAt != nil {
		t.Fatalf("expired=%+v", got)
	}
}

func TestPlanRatesRespectExpiredHorizonAndGeneration(t *testing.T) {
	d := glmDigest(true)
	a := declared("zhipu-global-pro", "legacy-v2")
	p := planOf(&a, d)
	if r := p.rate(d.Model("glm"), now); r == nil || *r != 3 {
		t.Fatalf("current=%v", r)
	}
	if r := p.rate(d.Model("glm"), now.Add(48*time.Hour)); r != nil {
		t.Fatalf("stale=%v", r)
	}
	a.Generation = "credits-2026"
	p = planOf(&a, d)
	if r := p.rate(d.Model("glm"), now); r == nil || *r != 0.5 {
		t.Fatalf("generation=%v", r)
	}
}

func TestBillingUnknownRequiredScopeDoesNotBorrowLowerRate(t *testing.T) {
	d, at := windowDigest()
	report := quota.Report{Accounts: []quota.Account{{Source: "user", Plan: "pro"}}}
	models := []*digest.Model{&d.Models[0]}
	if got := Billing(d, report, models, at); len(got) != 1 || got[0].MultiplierNow != nil {
		t.Fatalf("missing region=%+v", got)
	}
	report.Accounts[0].Region = "china"
	d.Multipliers[1].Generations = []string{"legacy"}
	if got := Billing(d, report, models, at); len(got) != 1 || got[0].MultiplierNow != nil {
		t.Fatalf("missing generation=%+v", got)
	}
	report.Accounts[0].Generation = "new"
	if got := Billing(d, report, models, at); len(got) != 1 || got[0].MultiplierNow == nil || *got[0].MultiplierNow != 1 {
		t.Fatalf("excluded generation=%+v", got)
	}
}

func TestWindowsUnrestrictedPlanFilter(t *testing.T) {
	d, at := windowDigest()
	d.Multipliers = d.Multipliers[:1]
	d.Multipliers[0].PlanIDs = nil
	got := Windows(d, WindowFilter{Plan: "any-plan"}, at)
	if len(got) != 1 || len(got[0].PlanIDs) != 1 || got[0].PlanIDs[0] != "any-plan" || *got[0].Series[0].Now.Multiplier != 1 {
		t.Fatalf("unrestricted=%+v", got)
	}
}

func TestGlobalRegionIsAnExactScope(t *testing.T) {
	d, at := windowDigest()
	d.Multipliers = d.Multipliers[:1]
	global := d.Multipliers[0]
	global.Region = "global"
	global.Multiplier = f(0.25)
	global.Priority = 99
	d.Multipliers = append(d.Multipliers, global)
	got := Windows(d, WindowFilter{Plan: "pro", Region: "china"}, at)
	if len(got) != 1 || *got[0].Series[0].Now.Multiplier != 1 {
		t.Fatalf("global leaked to china=%+v", got)
	}
	report := quota.Report{Accounts: []quota.Account{{Source: "user", Plan: "pro", Region: "china"}}}
	costs := Billing(d, report, []*digest.Model{&d.Models[0]}, at)
	if len(costs) != 1 || costs[0].MultiplierNow == nil || *costs[0].MultiplierNow != 1 {
		t.Fatalf("regional cost=%+v", costs)
	}
}

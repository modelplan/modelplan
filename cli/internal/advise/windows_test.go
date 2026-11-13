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

func TestWindowsPlanRuleAliasAgreesWithBilling(t *testing.T) {
	d := glmDigest(true)
	// The published rule IDs link pro to windows labelled with the legacy plan.
	groups := Windows(d, WindowFilter{Provider: "zai", Plan: "zhipu-global-pro", Model: "glm"}, now)
	report := quota.Report{Accounts: []quota.Account{declared("zhipu-global-pro", "legacy-v2"), declared("zhipu-global-pro", "credits-2026")}}
	billing := Billing(d, report, []*digest.Model{d.Model("glm")}, now)
	if len(groups) != 2 || len(billing) != 2 {
		t.Fatalf("alias groups=%+v billing=%+v", groups, billing)
	}
	for _, cost := range billing {
		var matched *WindowSeries
		for _, group := range groups {
			if len(group.PlanIDs) != 1 || group.PlanIDs[0] != "zhipu-global-pro" {
				t.Fatalf("wrong plan scope=%+v", group)
			}
			if len(group.Generations) == 1 && group.Generations[0] == cost.Generation {
				if len(group.Series) != 1 {
					t.Fatalf("series=%+v", group.Series)
				}
				matched = &group.Series[0]
			}
		}
		if matched == nil || !sameRate(matched.Now.Multiplier, cost.MultiplierNow) || matched.Now.Status != cost.Status {
			t.Fatalf("generation=%s public=%+v billing=%+v", cost.Generation, matched, cost)
		}
		if cost.Generation == "legacy-v2" && (len(matched.Changes) == 0 || !matched.Changes[0].At.Equal(now.Add(time.Hour)) || matched.Changes[0].Multiplier == nil || *matched.Changes[0].Multiplier != 1) {
			t.Fatalf("legacy fallback=%+v", matched)
		}
	}
	// The unfiltered view must also discover canonical aliases, not just literal planIds.
	found := false
	for _, g := range Windows(d, WindowFilter{Provider: "zai", Model: "glm"}, now) {
		found = found || contains(g.PlanIDs, "zhipu-global-pro")
	}
	if !found {
		t.Fatal("unfiltered windows omit canonical pro alias")
	}
}

func TestWindowsPlanRuleAliasPreservesScopeExclusions(t *testing.T) {
	d := glmDigest(true)
	for i := range d.Multipliers {
		if d.Multipliers[i].Provider == "zai" {
			d.Multipliers[i].Region = "global"
		}
	}
	// A higher-priority client-specific rule must stay in its own public scenario.
	override := d.Multipliers[len(d.Multipliers)-1]
	override.Provider = "zai"
	override.Region = "global"
	override.Generations = []string{"legacy-v2"}
	override.Models = []string{"GLM-5.3"}
	d.Multipliers = append(d.Multipliers, override)
	groups := Windows(d, WindowFilter{Provider: "zai", Plan: "zhipu-global-pro", Model: "glm", Region: "global"}, now)
	normal, client := false, false
	for _, g := range groups {
		if len(g.Generations) != 1 || g.Generations[0] != "legacy-v2" {
			continue
		}
		r := g.Series[0].Now.Multiplier
		if len(g.Clients) == 0 {
			normal = r != nil && *r == 3
		} else if len(g.Clients) == 1 && g.Clients[0] == "ZCode" {
			client = r != nil && *r == 0.1
		}
	}
	if !normal || !client {
		t.Fatalf("client scopes=%+v", groups)
	}
	for _, filter := range []WindowFilter{
		{Provider: "zai", Plan: "zhipu-global-pro", Model: "not-a-published-model", Region: "china"},
		{Provider: "zai", Plan: "zhipu-global-pro", Model: "glm", Region: "china"},
		{Provider: "other", Plan: "zhipu-global-pro", Model: "glm", Region: "global"},
	} {
		if got := Windows(d, filter, now); len(got) != 0 {
			t.Fatalf("filter=%+v groups=%+v", filter, got)
		}
	}
	// In the legacy generation the Flash override must not leak into GLM, or vice versa.
	for _, g := range Windows(d, WindowFilter{Provider: "zai", Plan: "zhipu-global-pro", Model: "glm-5.3-flash", Region: "global"}, now) {
		if len(g.Generations) == 1 && g.Generations[0] == "legacy-v2" && len(g.Clients) == 0 {
			if r := g.Series[0].Now.Multiplier; r == nil || *r != 0.4 {
				t.Fatalf("model leaked=%+v", g)
			}
			return
		}
	}
	t.Fatal("alias lookup omitted Flash's model-specific schedule")
}

func TestWindowsOverlappingClientSetsResolvePerClient(t *testing.T) {
	d, at := windowDigest()
	d.Multipliers = d.Multipliers[:1]
	d.Multipliers[0].Clients = []string{"A", "B"}
	override := d.Multipliers[0]
	override.RuleID = "A-offpeak"
	override.Clients = []string{"A"}
	override.Priority = 10
	override.Multiplier = f(0.5)
	override.EndsAt = at.Add(time.Hour).Format(time.RFC3339)
	d.Multipliers = append(d.Multipliers, override)
	groups := Windows(d, WindowFilter{Provider: "synthetic", Plan: "pro", Model: "model", Region: "china"}, at)
	if len(groups) != 2 {
		t.Fatalf("client groups=%+v", groups)
	}
	seen := map[string]bool{}
	for _, g := range groups {
		if len(g.Clients) != 1 || len(g.Series) != 1 {
			t.Fatalf("not a concrete client scope=%+v", g)
		}
		client := g.Clients[0]
		seen[client] = true
		s := g.Series[0]
		switch client {
		case "A":
			if s.Now.Multiplier == nil || *s.Now.Multiplier != 0.5 || len(s.Changes) != 1 || !s.Changes[0].At.Equal(at.Add(time.Hour)) || s.Changes[0].Multiplier == nil || *s.Changes[0].Multiplier != 1 {
				t.Fatalf("A must return to shared base=%+v", s)
			}
		case "B":
			if s.Now.Multiplier == nil || *s.Now.Multiplier != 1 || len(s.Changes) != 0 {
				t.Fatalf("B must retain shared base=%+v", s)
			}
		default:
			t.Fatalf("unexpected client=%s", client)
		}
	}
	if !seen["A"] || !seen["B"] {
		t.Fatalf("clients=%v", seen)
	}
	// At the half-open boundary A and B both use the shared base rate.
	for _, g := range Windows(d, WindowFilter{Provider: "synthetic", Plan: "pro", Model: "model", Region: "china"}, at.Add(time.Hour)) {
		if r := g.Series[0].Now.Multiplier; r == nil || *r != 1 {
			t.Fatalf("boundary=%+v", g)
		}
	}
}

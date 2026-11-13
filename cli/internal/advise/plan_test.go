package advise

import (
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/lineup"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

const zai = "https://api.z.ai/api/anthropic"

// glmDigest: GLM-5.3 reachable in Claude Code only through Z.ai, Flash with a Claude Code id for
// the cross-model cases, and the Zhipu plan metered two ways (as published for client-v1.3):
// legacy-v2 per request with peak hours, credits-2026 by credits per API USD.
func glmDigest(flashInClaudeCode bool) *digest.Digest {
	glm := digest.Model{ID: "glm", Name: "GLM-5.3", DeveloperID: "zhipuai", Recommended: "max",
		HarnessIDs:      map[string][]string{"claude-code": {"glm-5.3[1m]"}},
		HarnessEvidence: &digest.HarnessEvidence{RequiredEndpoints: map[string]string{"claude-code": zai}},
		Efforts:         []digest.Effort{eff("low", "Low", 29.6, 1.978), eff("max", "Max", 49.4, 4.233)}}
	flash := digest.Model{ID: "glm-5.3-flash", Name: "GLM-5.3-Flash", DeveloperID: "zhipuai", Recommended: "max",
		HarnessIDs: map[string][]string{"claude-code": {}}, Efforts: []digest.Effort{eff("max", "Max", 42, 0.448)}}
	if flashInClaudeCode {
		flash.HarnessIDs["claude-code"] = []string{"glm-5.3-flash"}
		flash.HarnessEvidence = glm.HarnessEvidence
	}
	d := fixtureDigest()
	d.Models = append(d.Models, glm, flash)
	d.Lineups = append(d.Lineups, digest.PublishedLineup{DeveloperID: "zhipuai", Lineup: lineup.Lineup{Members: []*lineup.Row{
		{ID: "glm", Ability: 49.4, Tags: []string{"strongest", "best_value"}}, {ID: "glm-5.3-flash", Ability: 42, Tags: []string{"cheapest"}}}}})
	d.PlanMetering = &digest.PlanMetering{Plans: []digest.MeteredPlan{
		{PlanID: "zhipu-global-pro", Generation: "credits-2026", Basis: digest.BasisTariff, Unit: "credits", TimeRules: []string{"glm-credits-base"},
			Rows: []digest.MeterRow{{ModelID: "glm", UnitsPerUSD: f(627.911)}, {ModelID: "glm-5.3-flash", UnitsPerUSD: f(1812.45)}}},
		{PlanID: "zhipu-global-pro", Generation: "legacy-v2", Basis: digest.BasisRequest, Unit: "requests", TimeRules: []string{"glm-legacy-base-0", "glm-legacy-peak-0", "glm-legacy-base-1"},
			Rows: []digest.MeterRow{{ModelID: "glm", Multiplier: f(1)}, {ModelID: "glm-5.3-flash", Multiplier: f(0.4)}}},
	}}
	w := func(rule, model string, mult float64, prio int, from, to time.Duration, gen string) digest.MultiplierWindow {
		var models []string
		if model != "" {
			models = []string{model}
		}
		// As published: the legacy windows name only the legacy plan; the rule id ties them to pro.
		return digest.MultiplierWindow{RuleID: rule, Provider: "zai", Models: models, PlanIDs: []string{"zhipu-global-legacy"}, Generations: []string{gen},
			Multiplier: f(mult), Priority: prio, StartsAt: now.Add(from).Format(time.RFC3339), EndsAt: now.Add(to).Format(time.RFC3339), Status: "CONFIRMED"}
	}
	d.Multipliers = append(d.Multipliers,
		// Peak now until +1h, then off-peak.
		w("glm-legacy-peak-0", "GLM-5.3", 3, 10, -2*time.Hour, time.Hour, "legacy-v2"),
		w("glm-legacy-base-0", "GLM-5.3", 1, 0, -3*time.Hour, 20*time.Hour, "legacy-v2"),
		w("glm-legacy-base-1", "GLM-5.3-Flash", 0.4, 0, -3*time.Hour, 20*time.Hour, "legacy-v2"),
		w("glm-credits-base", "", 0.5, 0, -3*time.Hour, 20*time.Hour, "credits-2026"),
		// A client-only factor never applies to Claude Code.
		digest.MultiplierWindow{RuleID: "glm-legacy-base-0", Clients: []string{"ZCode"}, Multiplier: f(0.1), Priority: 99,
			StartsAt: now.Add(-time.Hour).Format(time.RFC3339), EndsAt: now.Add(10 * time.Hour).Format(time.RFC3339), Status: "CONFIRMED"},
	)
	return d
}

// glmSession: Claude Code on GLM through Z.ai; Z.ai passes no usage windows to the status line.
func glmSession(effort, endpoint string) quota.Account {
	return quota.Account{Source: "claude-code", ObservedAt: now.Add(-time.Minute), Windows: []quota.Window{},
		Harness: &quota.Harness{Model: "glm-5.3[1m]", Effort: effort, Endpoint: endpoint}}
}

// session: the events about the Claude Code session; a declared plan's own rate hints (off-peak
// soon) come alongside.
func session(es []Event) []Event {
	var out []Event
	for _, e := range es {
		if e.Source == "claude-code" {
			out = append(out, e)
		}
	}
	return out
}

func declared(plan, gen string) quota.Account {
	return quota.Account{Source: "user", Plan: plan, Generation: gen, Windows: []quota.Window{}}
}

// zaiReading: the Z.ai plan's five-hour window as CodexBar read it.
func zaiReading(used float64, resetIn time.Duration) quota.Account {
	a := quota.Account{Source: "codexbar:zai", ObservedAt: now.Add(-time.Minute), Via: "codexbar",
		Windows: []quota.Window{{Kind: "five_hour", UsedPercent: f(used), ResetsAt: at(resetIn), WindowMinutes: 300, ResetMode: "fixed", ObservedAt: now.Add(-time.Minute)}}}
	quota.Evaluate(&a, now)
	return a
}

func TestPerRequestPlanNeverSuggestsALowerEffort(t *testing.T) {
	d := glmDigest(false)
	es := session(derive(t, nil, d, glmSession("max", zai), declared("zhipu-global-pro", "legacy-v2"), zaiReading(88, 2*time.Hour)))
	if len(es) != 1 || es[0].Type != WindowTight || es[0].Source != "claude-code" || es[0].Plan != "zhipu-global-pro" || es[0].Basis != digest.BasisRequest {
		t.Fatalf("events = %+v", es)
	}
	// Peak (×3) ends in an hour, before the reset: waiting is what saves quota.
	st := es[0].Suggest
	if st.Action != "wait_offpeak" || *st.InMinutes != 60 || *st.RateFrom != 3 || *st.RateTo != 1 {
		t.Fatalf("suggest = %+v", st)
	}
	if es[0].Alternative != nil {
		t.Fatalf("Flash has no Claude Code id, so no alternative: %+v", es[0].Alternative)
	}

	// Off-peak already: nothing to wait for, and still no lower effort.
	later := Derive(Input{Report: quota.Report{Accounts: []quota.Account{glmSession("max", zai), declared("zhipu-global-pro", "legacy-v2"), zaiReading(88, 2*time.Hour)}}, Digest: d, Now: now.Add(90 * time.Minute)})
	if len(later) != 1 || later[0].Suggest.Action != "effort_free" {
		t.Fatalf("off-peak = %+v", later)
	}
}

func TestPerRequestSurplusStepsUpAtNoExtraQuota(t *testing.T) {
	es := session(derive(t, nil, glmDigest(false), glmSession("low", zai), declared("zhipu-global-pro", "legacy-v2"), zaiReading(10, 30*time.Minute)))
	if len(es) != 1 || es[0].Type != ResetSoonSurplus {
		t.Fatalf("events = %v", types(es))
	}
	if st := es[0].Suggest; st.Action != "step_up" || st.Effort != "max" || *st.CostRatio != 1 || *st.AbilityDelta != 19.8 {
		t.Fatalf("suggest = %+v", st)
	}
}

func TestTariffPlanComparesModelsByWhatThePlanCharges(t *testing.T) {
	es := derive(t, nil, glmDigest(true), glmSession("low", zai), declared("zhipu-global-pro", "credits-2026"), zaiReading(88, 2*time.Hour))
	if len(es) != 1 || es[0].Type != WindowTight || es[0].Basis != digest.BasisTariff {
		t.Fatalf("events = %+v", es)
	}
	if es[0].Suggest.Action != "none" {
		t.Fatalf("already at the lowest effort: %+v", es[0].Suggest)
	}
	// Flash Max: 0.448 × 1812.45 credits vs GLM Low 1.978 × 627.911 (same ×0.5 now on both).
	alt := es[0].Alternative
	if alt == nil || alt.Model != "glm-5.3-flash" || *alt.CostRatio != 0.65 || *alt.AbilityDelta != 12.4 {
		t.Fatalf("alternative = %+v", alt)
	}
}

func TestNoPlanIsGuessed(t *testing.T) {
	d := glmDigest(false)
	reading := zaiReading(88, 2*time.Hour)
	for name, as := range map[string][]quota.Account{
		"no endpoint: GLM is not resolved":    {glmSession("max", ""), declared("zhipu-global-pro", "legacy-v2"), reading},
		"another endpoint":                    {glmSession("max", "https://proxy.example/anthropic"), declared("zhipu-global-pro", "legacy-v2"), reading},
		"no declared plan":                    {glmSession("max", zai), reading},
		"generation not declared, plan has 2": {glmSession("max", zai), declared("zhipu-global-pro", ""), reading},
	} {
		if es := session(derive(t, nil, d, as...)); len(es) != 0 {
			t.Errorf("%s: %+v", name, es)
		}
	}
	// Two declared plans that both meter GLM: which pays is unknown, so the session is not linked
	// and each plan keeps its own (windowless) account.
	d.PlanMetering.Plans = append(d.PlanMetering.Plans, digest.MeteredPlan{PlanID: "zhipu-cn-pro", Basis: digest.BasisRequest, Rows: []digest.MeterRow{{ModelID: "glm", Multiplier: f(1)}}})
	if _, p := Link(&[]quota.Account{glmSession("max", zai)}[0], quota.Report{Accounts: []quota.Account{declared("zhipu-global-pro", "legacy-v2"), declared("zhipu-cn-pro", "")}}, d); p != nil {
		t.Fatalf("linked to %+v", p)
	}
}

func TestDeclaredPlanRateHintsFollowItsTimeRules(t *testing.T) {
	// The legacy windows name only zhipu-global-legacy; pro on legacy-v2 still gets them by rule id.
	es := Derive(Input{Report: quota.Report{Accounts: []quota.Account{declared("zhipu-global-pro", "legacy-v2")}}, Digest: glmDigest(false), Now: now.Add(10 * time.Minute)})
	if len(es) != 1 || es[0].Type != OffpeakStartsSoon || es[0].Rate.Model != "GLM-5.3" || *es[0].Rate.From != 3 || *es[0].Rate.To != 1 {
		t.Fatalf("events = %+v", es)
	}
}

func TestBriefForAGLMSessionNamesThePlanAndItsLineup(t *testing.T) {
	a := glmSession("max", zai)
	r := quota.Report{Accounts: []quota.Account{a, declared("zhipu-global-pro", "legacy-v2"), zaiReading(40, 3*time.Hour)}}
	b := TaskStart(&a, r, glmDigest(false), now)
	if b == nil || b.Model != "GLM-5.3" || b.Plan == nil || b.Plan.Basis != digest.BasisRequest || b.Headroom == "" || b.Headroom == "unknown" {
		t.Fatalf("brief = %+v", b)
	}
	var names []string
	for _, m := range b.Models {
		names = append(names, m.Name)
	}
	if strings.Join(names, ",") != "GLM-5.3" {
		t.Fatalf("models = %v (GLM's lineup, only what Claude Code can run)", names)
	}
	for _, s := range b.Ladder {
		if s.CostRatio == nil || *s.CostRatio != 1 {
			t.Fatalf("every effort costs one request: %+v", b.Ladder)
		}
	}
	if len(b.BillingContext) != 1 || b.BillingContext[0].MultiplierNow == nil || *b.BillingContext[0].MultiplierNow != 3 || b.BillingContext[0].NextCheaperAt == nil || !b.BillingContext[0].NextCheaperAt.Equal(now.Add(time.Hour)) {
		t.Fatalf("billing context=%+v", b.BillingContext)
	}
	if len(b.PlanRates) != 1 || b.PlanRates[0].MultiplierNow == nil || *b.PlanRates[0].MultiplierNow != 3 || b.PlanRates[0].NextCheaperAt == nil {
		t.Fatalf("plan rate context=%+v", b.PlanRates)
	}
	if len(b.PlanRates) != 1 || *b.PlanRates[0].Now != 3 {
		t.Fatalf("rates = %+v", b.PlanRates)
	}
}

func TestUndeclaredListsThePlansThatMeterTheModel(t *testing.T) {
	d := glmDigest(false)
	s := glmSession("max", zai)
	m, plans := Undeclared(&s, quota.Report{Accounts: []quota.Account{s}}, d)
	if m == nil || m.ID != "glm" || len(plans) != 2 {
		t.Fatalf("model %v plans %+v", m, plans)
	}
	r := quota.Report{Accounts: []quota.Account{s, declared("zhipu-global-pro", "legacy-v2")}}
	if m, _ := Undeclared(&s, r, d); m != nil {
		t.Fatal("asked although the plan is declared")
	}
	claude := claude("medium", 30, time.Hour, 300)
	if m, _ := Undeclared(&claude, quota.Report{}, d); m != nil {
		t.Fatal("Claude on Claude's plan is not another vendor's model")
	}
}

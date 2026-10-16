package render

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
)

func TestAdviceLines(t *testing.T) {
	f := func(v float64) *float64 { return &v }
	n := func(v int) *int { return &v }
	at := time.Date(2026, 10, 14, 10, 40, 0, 0, time.UTC)
	cases := []struct {
		e      advise.Event
		zh, en string
	}{
		{advise.Event{Type: advise.ResetSoonSurplus, Source: "claude-code", Window: "five_hour", InMinutes: n(42), RemainingPercent: f(61),
			Suggest: &advise.Step{Action: "step_up", Effort: "high", Label: "High", AbilityDelta: f(4.8), CostRatio: f(1.37)}},
			"Claude Code 5小时还剩 61%，42分后重置，用不完就作废：可升到 High（+4.8分 ×1.37）",
			"Claude Code 5h window has 61% left and resets in 42m; unused allowance is lost: step up to High (+4.8 pts ×1.37)"},
		{advise.Event{Type: advise.WindowTight, Source: "codex", Window: "weekly", InMinutes: n(1500), RemainingPercent: f(8),
			Suggest: &advise.Step{Action: "step_down", Label: "Med", Recommended: true, AbilityDelta: f(-4.8), CostRatio: f(0.73)}},
			"Codex 每周额度偏紧（剩 8%，25时后重置）：降到 ★Med（-4.8分 ×0.73）",
			"Codex week window is tight (8% left, resets in 25h): step down to ★Med (-4.8 pts ×0.73)"},
		{advise.Event{Type: advise.PeakStartsSoon, Source: "user", Plan: "zhipu-cn-legacy", InMinutes: n(30), Rate: &advise.Rate{Model: "GLM-5.3", From: f(1), To: f(3), Status: "TENTATIVE"}},
			"zhipu-cn-legacy 30分后进入高峰：GLM-5.3 额度消耗 ×1 → ×3（待确认），重活可以提前做",
			"zhipu-cn-legacy enters peak hours in 30m: GLM-5.3 quota rate ×1 → ×3 (tentative); do heavy work first"},
		{advise.Event{Type: advise.PublicReset, Source: "codex", Public: &advise.Public{EventType: "reset_credit_issued"}},
			"Codex 官方发放了重置卡，你的余量以本机读数为准", "Codex issued reset credits; your own balance is the local reading"},
		{advise.Event{Type: advise.AnnouncedSurplus, Source: "codex", Window: "weekly", At: &at, RemainingPercent: f(52), Public: &advise.Public{When: "label"},
			Suggest: &advise.Step{Action: "step_up", Effort: "high", Label: "High", AbilityDelta: f(2.6), CostRatio: f(1.39)}},
			"Codex 官方预告重置（" + fmt.Sprintf("%d月%d日 %s 前", at.Local().Month(), at.Local().Day(), at.Local().Format("15:04")) + "）：如果包含你的账号，Codex 每周额度剩下的 52% 届时作废：可升到 High（+2.6分 ×1.39）",
			"Codex announced a reset (by " + at.Local().Format("Jan 2 15:04") + "): if it covers your account, the 52% left in your Codex week window is void then: step up to High (+2.6 pts ×1.39)"},
		{advise.Event{Type: advise.SwitchBack, Source: "claude-code", Window: "five_hour", At: &at, Suggest: &advise.Step{Action: "switch_back", Label: "Med", Recommended: true, AbilityDelta: f(-4.8), CostRatio: f(0.73)}},
			"Claude Code 5小时已于 " + at.Local().Format("15:04") + " 重置：可换回 ★Med（-4.8分 ×0.73）",
			"Claude Code 5h window reset at " + at.Local().Format("15:04") + ": switch back to ★Med (-4.8 pts ×0.73)"},
	}
	for _, c := range cases {
		if got := (Style{T: ZH}).AdviceLine(c.e); got != c.zh {
			t.Errorf("zh:\n got %s\nwant %s", got, c.zh)
		}
		if got := (Style{T: EN}).AdviceLine(c.e); got != c.en {
			t.Errorf("en:\n got %s\nwant %s", got, c.en)
		}
	}
	if h := (Style{T: ZH}).AdviceShort(cases[5].e); h != "↺★Med" {
		t.Errorf("short = %q", h)
	}
	if ctx := (Style{T: ZH}).AdviceContext([]advise.Event{cases[0].e}); !strings.HasPrefix(ctx, "Model Plan 本机额度提醒") || !strings.Contains(ctx, "\n- Claude Code 5小时") {
		t.Errorf("context = %q", ctx)
	}
}

func TestTaskBriefSaysWhenToSpeak(t *testing.T) {
	d, r := 4.8, 1.37
	b := &advise.Brief{Model: "GPT-6.1 Sol", Effort: "Med", AtRec: true, EffortKnown: true, Headroom: "normal", AtDefault: true, DefaultReason: "best_value",
		Default: &advise.BriefModel{Name: "GPT-6.1 Sol", Rec: "Med", Tags: []string{"strongest", "best_value"}},
		Models:  []advise.BriefModel{{Name: "GPT-6.1 Sol", Rec: "Med", Ability: 51.2, CostRelative: 1.4, Tags: []string{"strongest"}}, {Name: "GPT-6 Astra", Rec: "Med", Ability: 44, CostRelative: 1.6, Skip: true}},
		Ladder:  []advise.BriefStep{{Label: "Med", Recommended: true, Current: true}, {Label: "High", AbilityDelta: &d, CostRatio: &r}}}
	got := TaskBrief(b)
	for _, want := range []string{"Now: GPT-6.1 Sol · Med (★ recommended)", "GPT-6.1 Sol ★Med 51.2 pts ×1.40 (strongest)", "GPT-6 Astra ★Med 44.0 pts ×1.60 (skip", "★Med (current) · High +4.8 pts ×1.37", "Otherwise say nothing about models or efforts.", "Default for ordinary tasks: GPT-6.1 Sol ★Med (both the strongest and the best value). The thread is on it.", "back to the default once it is done", "never say you changed them"} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q in:\n%s", want, got)
		}
	}
	if TaskBrief(nil) != "" {
		t.Error("nil brief")
	}
}

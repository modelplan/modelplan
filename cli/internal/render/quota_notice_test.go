package render

import (
	"bytes"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestQuotaNoticeLines(t *testing.T) {
	f := func(v float64) *float64 { return &v }
	n := func(v int) *int { return &v }
	down := &advise.Step{Action: "step_down", Effort: "medium", Label: "Med", Recommended: true, AbilityDelta: f(-4.4), CostRatio: f(0.72)}
	cheaper := &advise.Step{Action: "cheaper_model", ModelName: "Claude Sonnet 5.5", Effort: "high", Label: "High", AbilityDelta: f(0.3), CostRatio: f(0.55)}
	for _, c := range []struct {
		n      advise.QuotaNotice
		en, zh string
	}{
		{advise.QuotaNotice{Kind: "low", Window: "weekly", Remaining: 4, ResetsIn: 26*60 + 27, RunsOutIn: n(180), RateOver: "day"},
			"Weekly quota: 4% left, resets in 26h27m; at the last day's rate it runs out in ~3h.",
			"每周额度：剩余4%，26时27分后重置；按最近一天的用量约3时后用完。"},
		{advise.QuotaNotice{Kind: "low", Window: "five_hour", Remaining: 18, ResetsIn: 120, Down: down},
			"5-hour quota: 18% left, resets in 2h. The effort is above ★: ★Med uses ×0.72 the quota of the current effort (-4.4 pts); suggest it to the user once.",
			"5小时额度：剩余18%，2时后重置。当前档位高于★：★Med 的额度消耗是当前档的 ×0.72（-4.4 分），可以向用户提一次。"},
		{advise.QuotaNotice{Kind: "low", Window: "five_hour", Remaining: 60, ResetsIn: 180, RunsOutIn: n(50), RateOver: "recent", Cheaper: cheaper},
			"5-hour quota: 60% left, resets in 3h; at the recent rate it runs out in ~50m. Claude Sonnet 5.5 High scores as well at ×0.55 the cost (+0.3 pts).",
			"5小时额度：剩余60%，3时后重置；按最近的用量约50分后用完。Claude Sonnet 5.5 High 能力相当，成本 ×0.55（+0.3 分）。"},
		{advise.QuotaNotice{Kind: "surplus", Window: "weekly", Remaining: 62, ResetsIn: 300},
			"Weekly quota: 62% left, resets in 5h; what is left lapses at the reset.",
			"每周额度：剩余62%，5时后重置，没用完的届时作废。"},
		{advise.QuotaNotice{Kind: "reset", Window: "five_hour", Remaining: 96, ResetsIn: 300},
			"5-hour window reset: 96% left, resets in 5h.",
			"5小时窗口已重置：剩余96%，5时后重置。"},
	} {
		if got := (Style{T: EN}).QuotaNotice(c.n); got != c.en {
			t.Errorf("en:\ngot  %s\nwant %s", got, c.en)
		}
		if got := (Style{T: ZH}).QuotaNotice(c.n); got != c.zh {
			t.Errorf("zh:\ngot  %s\nwant %s", got, c.zh)
		}
	}
}

func TestQuotaSaysWhyNothingWasRead(t *testing.T) {
	for reason, want := range map[string]string{"reader-privacy": "MODELPLAN_READERS", "consent-newer": "Update the plugin or the CLI"} {
		var out bytes.Buffer
		Style{T: EN}.Quota(&out, quota.Report{Sources: []quota.SourceStatus{{Source: "readers", Status: "off", Reason: reason}}})
		if !strings.Contains(out.String(), "No local quota readings.") || !strings.Contains(out.String(), want) {
			t.Fatalf("%s: %q", reason, out.String())
		}
	}
}

func TestSpendNoticeAndOtherPlan(t *testing.T) {
	f := func(v float64) *float64 { return &v }
	cheaper := &advise.Step{Action: "cheaper_model", ModelName: "Claude Sonnet 5.5", Label: "High", AbilityDelta: f(0.3), CostRatio: f(0.55)}
	other := &advise.OtherPlan{Name: "Codex", Window: "weekly", Remaining: 60, ResetsIn: 48 * 60}
	n := []advise.QuotaNotice{{Kind: "low", Window: "weekly", Remaining: 8, ResetsIn: 180, Other: other, Cheaper: cheaper}}
	for _, c := range []struct {
		s                 Style
		user, model, line string
	}{
		{Style{T: EN},
			"Quota is low for spawning subagents. Weekly quota: 8% left, resets in 3h; Codex still has 60% of its weekly quota left, resets in 2d.",
			"Quota is low for spawning subagents. Weekly quota: 8% left, resets in 3h; Codex still has 60% of its weekly quota left, resets in 2d. For subagents that do not need this model, Claude Sonnet 5.5 High scores as well at ×0.55 the cost (+0.3 pts).",
			"Weekly quota: 8% left, resets in 3h; Codex still has 60% of its weekly quota left, resets in 2d. Claude Sonnet 5.5 High scores as well at ×0.55 the cost (+0.3 pts)."},
		{Style{T: ZH},
			"派子代理前注意额度。每周额度：剩余8%，3时后重置；Codex 每周额度还剩60%，2天后重置。",
			"派子代理前注意额度。每周额度：剩余8%，3时后重置；Codex 每周额度还剩60%，2天后重置。不需要当前模型的子代理可以用 Claude Sonnet 5.5 High，能力相当，成本 ×0.55（+0.3 分）。",
			"每周额度：剩余8%，3时后重置；Codex 每周额度还剩60%，2天后重置。Claude Sonnet 5.5 High 能力相当，成本 ×0.55（+0.3 分）。"},
	} {
		if got := c.s.SpendNotice(n, nil, false); got != c.user {
			t.Errorf("user:\ngot  %s\nwant %s", got, c.user)
		}
		if got := c.s.SpendNotice(n, cheaper, true); got != c.model {
			t.Errorf("model:\ngot  %s\nwant %s", got, c.model)
		}
		if got := c.s.QuotaNotice(n[0]); got != c.line {
			t.Errorf("prompt notice:\ngot  %s\nwant %s", got, c.line)
		}
	}
}

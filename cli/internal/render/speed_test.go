package render

import (
	"testing"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

func tier(id, harness, kind, label string, ratio *float64, qual string, caveats []string, plans []string, bill ...digest.SpeedBilling) digest.ModelTier {
	t := &digest.SpeedTier{ID: id, Harness: harness, Tier: kind, Label: label, Billing: bill, Caveats: caveats}
	t.Eligibility.Plans = plans
	m := &digest.SpeedTierModel{}
	m.Speed.Ratio, m.Speed.Qualifier = ratio, qual
	return digest.ModelTier{SpeedTier: t, Model: m}
}

func TestSpeedLines(t *testing.T) {
	f := func(v float64) *float64 { return &v }
	cases := []struct {
		t      digest.ModelTier
		zh, en string
	}{
		{tier("codex-fast", "codex", "fast", "Fast", nil, "unstated", nil, nil,
			digest.SpeedBilling{Account: "subscription", BillsTo: "plan-quota", Ratio: 2.5}, digest.SpeedBilling{Account: "credits", BillsTo: "credits", Ratio: 2}),
			"⚡ Codex Fast  套餐额度 ×2.5 · 积分 ×2 · 提速未公布",
			"⚡ Codex Fast  plan quota ×2.5 · credits ×2 · speed-up not stated"},
		{tier("codex-fast", "codex", "fast", "Fast", f(1.5), "approximate", nil, nil,
			digest.SpeedBilling{Account: "subscription", BillsTo: "plan-quota", Ratio: 2.5}, digest.SpeedBilling{Account: "credits", BillsTo: "credits", Ratio: 2}),
			"⚡ Codex Fast  套餐额度 ×2.5 · 积分 ×2 · 提速约 ×1.5 · 生成耗时约 ×0.67",
			"⚡ Codex Fast  plan quota ×2.5 · credits ×2 · about ×1.5 faster · generation time about ×0.67"},
		{tier("codex-ultrafast", "codex", "ultrafast", "Ultrafast", f(8), "up-to", []string{"restricted-plans"}, []string{"chatgpt-pro-500", "enterprise-eligible", "edu-eligible"},
			digest.SpeedBilling{Account: "subscription", BillsTo: "plan-quota", Ratio: 8}, digest.SpeedBilling{Account: "credits", BillsTo: "credits", Ratio: 6}),
			"⚡⚡ Codex Ultrafast  套餐额度 ×8 · 积分 ×6 · 提速最多 ×8 · 生成耗时最低 ×0.13 · 仅 Pro $500 / Enterprise / Edu",
			"⚡⚡ Codex Ultrafast  plan quota ×8 · credits ×6 · up to ×8 faster · generation time ≥ ×0.13 · only Pro $500 / Enterprise / Edu"},
		{tier("claude-code-fast", "claude-code", "fast", "Fast mode", f(2.5), "up-to", []string{"not-plan-quota", "rebills-context-on-enable"}, nil,
			digest.SpeedBilling{Account: "subscription", BillsTo: "usage-credits", Ratio: 2}, digest.SpeedBilling{Account: "api", BillsTo: "api", Ratio: 2}),
			"⚡ Claude Code Fast mode  价格 ×2（扣 usage credits，不占订阅额度） · 提速最多 ×2.5 · 生成耗时最低 ×0.4 · 对话中途开启会按 fast 价重算一次整段上下文",
			"⚡ Claude Code Fast mode  price ×2 (billed to usage credits, not plan quota) · up to ×2.5 faster · generation time ≥ ×0.4 · turning it on mid-conversation re-bills the whole context once"},
	}
	for _, c := range cases {
		if got := (Style{T: ZH}).SpeedLine(c.t); got != c.zh {
			t.Errorf("zh:\n got %s\nwant %s", got, c.zh)
		}
		if got := (Style{T: EN}).SpeedLine(c.t); got != c.en {
			t.Errorf("en:\n got %s\nwant %s", got, c.en)
		}
	}
}

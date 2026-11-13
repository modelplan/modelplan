package render

import (
	"fmt"
	"io"
	"math"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

type speedText struct {
	Harness                                                  map[string]string
	Quota, Credits, Price, UsageCredits, API                 string
	Speed, Unstated, Approx, TimeAtBest, TimeAbout, NotQuota string
	Rebill, Restricted, Times                                string
}

var speedZH = speedText{
	Harness: map[string]string{"codex": "Codex", "claude-code": "Claude Code"},
	Quota:   "套餐额度 ×%s", Credits: "积分 ×%s", Price: "价格 ×%s", UsageCredits: "扣 usage credits，不占订阅额度", API: "API ×%s",
	Speed: "提速最多 ×%s", Unstated: "提速未公布", Approx: "提速约 ×%s", TimeAtBest: "生成耗时最低 ×%s", TimeAbout: "生成耗时约 ×%s",
	NotQuota: "", Rebill: "对话中途开启会按 fast 价重算一次整段上下文", Restricted: "仅 %s", Times: "每一档的成本再乘这个倍数",
}

var speedEN = speedText{
	Harness: map[string]string{"codex": "Codex", "claude-code": "Claude Code"},
	Quota:   "plan quota ×%s", Credits: "credits ×%s", Price: "price ×%s", UsageCredits: "billed to usage credits, not plan quota", API: "API ×%s",
	Speed: "up to ×%s faster", Unstated: "speed-up not stated", Approx: "about ×%s faster", TimeAtBest: "generation time ≥ ×%s", TimeAbout: "generation time about ×%s",
	NotQuota: "", Rebill: "turning it on mid-conversation re-bills the whole context once", Restricted: "only %s", Times: "multiply any effort's cost by this",
}

func (s Style) st() speedText {
	if s.T.Pts == "pts" {
		return speedEN
	}
	return speedZH
}

func g(v float64) string {
	return strings.TrimSuffix(strings.TrimRight(fmt.Sprintf("%.2f", math.Round(v*100)/100), "0"), ".") // half away from zero
}

var planNames = map[string]string{"chatgpt-pro-500": "Pro $500", "enterprise-eligible": "Enterprise", "edu-eligible": "Edu"}

// SpeedLine is one tier for one model: "⚡ Codex Fast  套餐额度 ×2.5 · 积分 ×2 · 提速未公布".
func (s Style) SpeedLine(t digest.ModelTier) string {
	x := s.st()
	var parts []string
	for _, b := range t.Billing {
		switch {
		case b.BillsTo == "plan-quota":
			parts = append(parts, fmt.Sprintf(x.Quota, g(b.Ratio)))
		case b.BillsTo == "credits":
			parts = append(parts, fmt.Sprintf(x.Credits, g(b.Ratio)))
		case b.BillsTo == "usage-credits":
			parts = append(parts, fmt.Sprintf(x.Price, g(b.Ratio))+"（"+x.UsageCredits+"）")
		}
	}
	if s.T.Pts == "pts" {
		for i, p := range parts {
			parts[i] = strings.NewReplacer("（", " (", "）", ")").Replace(p)
		}
	}
	sp := t.Model.Speed
	switch {
	case sp.Ratio == nil:
		parts = append(parts, x.Unstated)
	case sp.Qualifier == "up-to":
		parts = append(parts, fmt.Sprintf(x.Speed, g(*sp.Ratio)), fmt.Sprintf(x.TimeAtBest, g(1 / *sp.Ratio)))
	default:
		parts = append(parts, fmt.Sprintf(x.Approx, g(*sp.Ratio)), fmt.Sprintf(x.TimeAbout, g(1 / *sp.Ratio)))
	}
	if t.Has("restricted-plans") {
		var ps []string
		for _, p := range t.Eligibility.Plans {
			if n := planNames[p]; n != "" {
				ps = append(ps, n)
			}
		}
		parts = append(parts, fmt.Sprintf(x.Restricted, strings.Join(ps, " / ")))
	}
	if t.Has("rebills-context-on-enable") {
		parts = append(parts, x.Rebill)
	}
	bolt := "⚡"
	if t.Tier == "ultrafast" {
		bolt = "⚡⚡"
	}
	return s.c(gold, bolt) + " " + s.c(bold+";"+hi, x.Harness[t.Harness]+" "+t.Label) + "  " + s.c(dim, strings.Join(parts, " · "))
}

// Speed prints the model's speed tiers under its effort ladder.
func (s Style) Speed(w io.Writer, ts []digest.ModelTier) {
	if len(ts) == 0 {
		return
	}
	fmt.Fprintln(w)
	for _, t := range ts {
		fmt.Fprintln(w, "  "+s.SpeedLine(t))
	}
	fmt.Fprintln(w, "  "+s.c(dim, s.st().Times))
}

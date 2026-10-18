package render

import (
	"bytes"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

func TestMeasuredAgainstStarAndPublished(t *testing.T) {
	f := func(v float64) *float64 { return &v }
	sol := "sol-6.1"
	d := &digest.Digest{Models: []digest.Model{{ID: "sol-6.1", Name: "GPT-6.1 Sol", Recommended: "medium",
		HarnessIDs: map[string][]string{"codex": {"gpt-6.1-sol"}},
		Efforts:    []digest.Effort{{Effort: "low", Label: "Low", Time: f(0.6)}, {Effort: "medium", Label: "Med", Time: f(1)}, {Effort: "high", Label: "High", Time: f(1.4)}}}},
		Speed: []digest.SpeedTier{{ID: "codex-fast", Harness: "codex", Tier: "fast", Label: "Fast",
			Models: []digest.SpeedTierModel{{VendorModelID: "gpt-6.1-sol", ModelID: &sol}}}}}
	d.Speed[0].Models[0].Speed.Ratio, d.Speed[0].Models[0].Speed.Qualifier = f(1.5), "approximate"
	stats := []speed.Stat{
		{Source: "codex", Model: "gpt-6.1-sol", Effort: "medium", Turns: 20, Requests: 80, OutputTokensPerSecond: f(60), TTFTSeconds: f(1.8), TurnSeconds: f(40), TurnOutputTokens: f(1200)},
		{Source: "codex", Model: "gpt-6.1-sol", Effort: "high", Turns: 12, Requests: 50, OutputTokensPerSecond: f(58), TurnSeconds: f(64), TurnOutputTokens: f(2040)},
		{Source: "codex", Model: "gpt-6.1-sol", Effort: "high", Speed: "fast", Turns: 6, Requests: 30, OutputTokensPerSecond: f(81.2), TurnSeconds: f(50)},
		{Source: "codex", Model: "gpt-6.1-sol", Effort: "low", Turns: 2, Requests: 3},
		{Source: "claude-code", Model: "claude-opus-5-5", Effort: "high", Turns: 7, Requests: 49, OutputTokensPerSecond: f(120), TurnSeconds: f(157)},
	}
	if got := MeasuredFor(stats, d, d.Model("sol-6.1")); len(got) != 4 {
		t.Fatalf("for sol: %+v", got)
	}
	var b bytes.Buffer
	Style{T: ZH}.Measured(&b, stats, d, true)
	got := b.String()
	for _, want := range []string{
		"▲ Codex · GPT-6.1 Sol\n  High            每轮 1分04秒 ×1.60（公布 ×1.40） · 2.0k token ×1.70 · 输出 58 tok/s · 12 轮\n",
		"  High ⚡          每轮 50秒 · 输出 81 tok/s ×1.40（公布约 ×1.5） · 6 轮\n",
		"  ★Med            每轮 40秒 · 1.2k token · 输出 60 tok/s · 首字 1.8秒 · 20 轮\n",
		"  Low             样本不足（2 轮，3 次请求）\n",
		"▲ Claude Code · claude-opus-5-5\n  high            每轮 2分37秒 · 输出 120 tok/s · 7 轮\n",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("missing %q in:\n%s", want, got)
		}
	}
	b.Reset()
	Style{T: EN}.Measured(&b, nil, d, true)
	if !strings.Contains(b.String(), "Nothing measured yet") {
		t.Error(b.String())
	}
}

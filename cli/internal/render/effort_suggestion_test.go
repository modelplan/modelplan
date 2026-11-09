// SPDX-License-Identifier: MIT
package render_test

import (
	"regexp"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/render"
)

func lowRung(d *digest.Digest) {
	cost := 1.0
	d.Models[0].Efforts = append([]digest.Effort{{Effort: "low", Label: "Low", Cost: &cost, CostBasisID: "synthetic-reference"}}, d.Models[0].Efforts...)
}

func TestEffortSuggestionLanguages(t *testing.T) {
	d, _ := contracttest.Public()
	lowRung(d)
	for _, tc := range []struct {
		direction, effort string
		uses              []float64
		en, zh, arrow     string
	}{
		{"up", "medium", []float64{40, 45, 50}, "Quota to spare · High is affordable", "额度富余 · 可升到 High", "↑"},
		{"down", "high", []float64{100, 95, 100}, "Quota running low · try Low", "额度偏紧 · 建议降到 Low", "↓"},
	} {
		v := history.SuggestEffort(contracttest.EffortLedger(contracttest.Now, tc.effort, false, tc.uses...), d, contracttest.Now)
		if v == nil || v.Direction != tc.direction {
			t.Fatalf("%s: %+v", tc.direction, v)
		}
		for style, want := range map[render.Style]string{{T: render.EN}: tc.en, {T: render.ZH}: tc.zh} {
			line := style.EffortSuggestionLine(v)
			if line != want || strings.ContainsAny(line, "\n\r") || regexp.MustCompile(`[0-9%×]`).MatchString(line) {
				t.Fatalf("line %q, want %q (one line, no numbers)", line, want)
			}
			// Status line: the same arrow as the headroom hints (↑ spare, ↓ tight), then the line.
			if short := style.EffortSuggestionShort(v); short != tc.arrow+" "+want || render.EffortSuggestionArrow(v) != tc.arrow {
				t.Fatalf("short %q", short)
			}
			// Never a model switch or a speed-mode suggestion.
			if strings.Contains(strings.ToLower(line), "fast") || strings.Contains(line, "→") {
				t.Fatalf("unexpected content: %q", line)
			}
		}
		if got := (render.Style{T: render.EN}).EffortSuggestionDetail(v); got != "based on 3 cycles" {
			t.Fatalf("detail %q", got)
		}
		if got := (render.Style{T: render.ZH}).EffortSuggestionDetail(v); got != "依据：过去 3 个周期" {
			t.Fatalf("detail %q", got)
		}
	}
	live := &history.EffortSuggestion{Direction: "down", ToEffort: "low", ToLabel: "Low", Recommended: "medium", BasisHours: 24}
	if got := (render.Style{T: render.EN}).EffortSuggestionDetail(live); got != "based on last 24h" {
		t.Fatal(got)
	}
	if got := (render.Style{T: render.ZH}).EffortSuggestionDetail(live); got != "依据：最近 24 小时" {
		t.Fatal(got)
	}
	live.Cycles = 3
	if got := (render.Style{T: render.EN}).EffortSuggestionDetail(live); got != "based on last 24h / 3 cycles" {
		t.Fatal(got)
	}
	if (render.Style{T: render.EN}).EffortSuggestionLine(nil) != "" || (render.Style{T: render.ZH}).EffortSuggestionShort(nil) != "" || (render.Style{T: render.EN}).EffortSuggestionDetail(nil) != "" {
		t.Fatal("unknown must be silent")
	}
}

func TestEffortSuggestionUnknownPlanLabel(t *testing.T) {
	d, _ := contracttest.Public()
	l := contracttest.EffortLedger(contracttest.Now, "medium", false, 40, 45, 50)
	for i := range l.Cycles {
		l.Cycles[i].Source, l.Cycles[i].Plan = "claude-code", ""
	}
	v := history.SuggestEffort(l, d, contracttest.Now)
	if v == nil || v.Plan != "" {
		t.Fatal("Claude Code meter without plan label must remain usable, without an invented plan")
	}
}

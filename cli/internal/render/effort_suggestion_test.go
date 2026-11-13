// SPDX-License-Identifier: MIT
package render_test

import (
	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/render"
	"strings"
	"testing"
)

func TestEffortSuggestionLanguages(t *testing.T) {
	d, _ := contracttest.Public()
	for _, direction := range []string{"up", "down"} {
		effort, uses := "medium", []float64{40, 45, 50}
		if direction == "down" {
			effort, uses = "high", []float64{100, 95, 100}
		}
		v := history.SuggestEffort(contracttest.EffortLedger(contracttest.Now, effort, false, uses...), d, contracttest.Now)
		for _, tc := range []struct {
			style render.Style
			words []string
		}{{render.Style{T: render.EN}, []string{"past 3 weeks", "published reference cost", direction, "★Med"}}, {render.Style{T: render.ZH}, []string{"过去 3 周", "参考成本", "★Med"}}} {
			line := tc.style.EffortSuggestionLine(v)
			for _, word := range tc.words {
				if !strings.Contains(line, word) {
					t.Fatalf("missing %s: %s", word, line)
				}
			}
			if strings.ContainsAny(line, "\n\r") {
				t.Fatal("not one line")
			}
		}
	}
	if (render.Style{T: render.EN}).EffortSuggestionLine(nil) != "" {
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
	if v == nil {
		t.Fatal("Claude Code meter without plan label must remain usable")
	}
	for _, style := range []render.Style{{T: render.EN}, {T: render.ZH}} {
		line := style.EffortSuggestionLine(v)
		if !strings.HasPrefix(line, "claude-code · ") || strings.Contains(line, " / ") {
			t.Fatalf("unknown plan was fabricated or left a separator: %s", line)
		}
	}
}

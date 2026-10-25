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

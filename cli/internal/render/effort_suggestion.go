// SPDX-License-Identifier: MIT
package render

import (
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/history"
)

func (s Style) EffortSuggestionLine(v *history.EffortSuggestion) string {
	if v == nil {
		return ""
	}
	from, to := v.FromLabel, v.ToLabel
	if v.FromEffort == v.Recommended {
		from = "★" + from
	}
	if v.ToEffort == v.Recommended {
		to = "★" + to
	}
	fast := ""
	if v.Fast {
		fast = " · Fast"
	}
	if s.T == EN {
		verb := "up"
		if v.Direction == "down" {
			verb = "down"
		}
		return fmt.Sprintf("%s / %s · %s%s: past %d weeks averaged %.0f%%; your default could go %s from %s to %s (published reference cost ×%.2f).", v.Source, v.Plan, v.ModelName, fast, v.Cycles, v.AverageUsed, verb, from, to, v.CostRatio)
	}
	verb := "提高"
	if v.Direction == "down" {
		verb = "降低"
	}
	return fmt.Sprintf("%s / %s · %s%s：过去 %d 周平均用了 %.0f%%，默认档位可以从 %s %s到 %s（已发布的参考成本 ×%.2f）。", v.Source, v.Plan, v.ModelName, fast, v.Cycles, v.AverageUsed, from, verb, to, v.CostRatio)
}

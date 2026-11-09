// SPDX-License-Identifier: MIT
package render

import (
	"fmt"

	"github.com/modelplan/modelplan/cli/internal/history"
)

// The weekly effort hint is one short line without numbers: the effort to move to,
// on the same model, starting from the published star effort. The basis goes in an
// optional detail line. It never mentions a model switch or Fast.

// EffortSuggestionArrow is the status-line arrow shared with the headroom hints:
// up for spare quota, down for tight quota.
func EffortSuggestionArrow(v *history.EffortSuggestion) string {
	if v != nil && v.Direction == "down" {
		return "↓"
	}
	return "↑"
}

func (s Style) EffortSuggestionLine(v *history.EffortSuggestion) string {
	if v == nil {
		return ""
	}
	to := v.ToLabel
	if v.ToEffort == v.Recommended {
		to = "★" + to
	}
	if s.T == EN {
		if v.Direction == "down" {
			return fmt.Sprintf("Quota running low · try %s", to)
		}
		return fmt.Sprintf("Quota to spare · %s is affordable", to)
	}
	if v.Direction == "down" {
		return fmt.Sprintf("额度偏紧 · 建议降到 %s", to)
	}
	return fmt.Sprintf("额度富余 · 可升到 %s", to)
}

// EffortSuggestionDetail is the optional basis line (hover or long form).
func (s Style) EffortSuggestionDetail(v *history.EffortSuggestion) string {
	if v == nil {
		return ""
	}
	switch {
	case v.BasisHours > 0 && v.Cycles > 0:
		if s.T == EN {
			return fmt.Sprintf("based on last %dh / %d cycles", v.BasisHours, v.Cycles)
		}
		return fmt.Sprintf("依据：最近 %d 小时 / 过去 %d 个周期", v.BasisHours, v.Cycles)
	case v.BasisHours > 0:
		if s.T == EN {
			return fmt.Sprintf("based on last %dh", v.BasisHours)
		}
		return fmt.Sprintf("依据：最近 %d 小时", v.BasisHours)
	case v.Cycles > 0:
		if s.T == EN {
			return fmt.Sprintf("based on %d cycles", v.Cycles)
		}
		return fmt.Sprintf("依据：过去 %d 个周期", v.Cycles)
	}
	return ""
}

// EffortSuggestionShort is the status-line form: the arrow, then the same line.
func (s Style) EffortSuggestionShort(v *history.EffortSuggestion) string {
	if v == nil {
		return ""
	}
	return EffortSuggestionArrow(v) + " " + s.EffortSuggestionLine(v)
}

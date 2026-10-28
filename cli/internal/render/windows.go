package render

import (
	"fmt"
	"io"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/advise"
)

func (s Style) ratePoint(p advise.RatePoint) string {
	if p.Multiplier == nil {
		if s.T.Pts == "pts" {
			return "unknown"
		}
		return "未知"
	}
	out := fmt.Sprintf("×%g", *p.Multiplier)
	if p.Status != "CONFIRMED" {
		if s.T.Pts == "pts" {
			out += " (unverified)"
		} else {
			out += "（未核实）"
		}
	}
	return out
}

// Windows displays absolute publication instants in the user's local timezone.
func (s Style) Windows(w io.Writer, groups []advise.WindowGroup) {
	if len(groups) == 0 {
		if s.T.Pts == "pts" {
			fmt.Fprintln(w, "No published windows match these filters.")
		} else {
			fmt.Fprintln(w, "没有匹配的公开计费时段。")
		}
		return
	}
	for _, g := range groups {
		plans := strings.Join(g.PlanIDs, ", ")
		if plans == "" {
			if s.T.Pts == "pts" {
				plans = "all plans"
			} else {
				plans = "所有套餐"
			}
		}
		title := g.Provider + " / " + plans
		for _, scope := range []string{g.Region, strings.Join(g.Generations, ", "), strings.Join(g.Clients, ", ")} {
			if scope != "" {
				title += " · " + scope
			}
		}
		if len(g.Qualifications) > 0 {
			if s.T.Pts == "pts" {
				title += " · conditions apply (see --json)"
			} else {
				title += " · 有适用条件（见 --json）"
			}
		}
		printed := false
		for _, series := range g.Series {
			label := title
			if printed {
				label = "  " + series.Model
			} else if series.Model != "" {
				fmt.Fprintln(w, title)
				label = "  " + series.Model
			}
			fmt.Fprintf(w, "%s: %s", label, s.ratePoint(series.Now))
			for _, change := range series.Changes {
				fmt.Fprintf(w, " → %s %s", change.At.Local().Format("Jan 02 15:04 MST"), s.ratePoint(change))
			}
			fmt.Fprintln(w)
			printed = true
		}
	}
}

func (s Style) BillingSuffix(cs []advise.BillingContext, model string) string {
	var parts []string
	for _, c := range cs {
		if c.Model != model {
			continue
		}
		rate := s.ratePoint(advise.RatePoint{Multiplier: c.MultiplierNow, Status: c.Status})
		base, effective := "—", "—"
		if c.BaseCost != nil {
			base = fmt.Sprintf("%.3g", *c.BaseCost)
		}
		if c.EffectiveCost != nil {
			effective = fmt.Sprintf("%.3g", *c.EffectiveCost)
		}
		if s.T.Pts == "pts" {
			parts = append(parts, fmt.Sprintf("%s: base %s × %s = %s now", c.PlanID, base, strings.TrimPrefix(rate, "×"), effective))
		} else {
			parts = append(parts, fmt.Sprintf("%s：基础 %s × %s = 当前 %s", c.PlanID, base, strings.TrimPrefix(rate, "×"), effective))
		}
	}
	if len(parts) == 0 {
		return ""
	}
	return "  [" + strings.Join(parts, "; ") + "]"
}

// BillingHint offers the first cheaper window once, without directing a setting change.
func (s Style) BillingHint(w io.Writer, cs []advise.BillingContext) {
	var first *advise.BillingContext
	for i := range cs {
		c := &cs[i]
		if c.NextCheaperAt != nil && c.NextMultiplier != nil && c.MultiplierNow != nil && *c.MultiplierNow > 0 && (first == nil || c.NextCheaperAt.Before(*first.NextCheaperAt)) {
			first = c
		}
	}
	if first == nil {
		return
	}
	c := first
	when := c.NextCheaperAt.Local().Format("Jan 02 15:04 MST")
	ratio := *c.NextMultiplier / *c.MultiplierNow
	unverified := ""
	if c.Status != "CONFIRMED" || c.NextStatus != "CONFIRMED" {
		if s.T.Pts == "pts" {
			unverified = " (unverified)"
		} else {
			unverified = "（未核实）"
		}
	}
	if s.T.Pts == "pts" {
		price := fmt.Sprintf("≈ ×%.2g the current reference cost", ratio)
		if ratio >= 0.45 && ratio <= 0.55 {
			price = "≈ half price"
		}
		fmt.Fprintf(w, "  %s / %s: %s after %s%s; waiting is an option.\n", c.PlanID, c.Model, price, when, unverified)
	} else {
		price := fmt.Sprintf("参考成本约为当前的 ×%.2g", ratio)
		if ratio >= 0.45 && ratio <= 0.55 {
			price = "约半价"
		}
		fmt.Fprintf(w, "  %s / %s：%s 后%s%s；可选择等待。\n", c.PlanID, c.Model, when, price, unverified)
	}
}

func (s Style) BillingFootnote(w io.Writer) {
	if s.T.Pts == "pts" {
		fmt.Fprintln(w, "  Base reference costs shown. Time-of-day plan rates: modelplan windows.")
	} else {
		fmt.Fprintln(w, "  显示基础参考成本。套餐分时倍率：modelplan windows。")
	}
}

// BillingBrief is optional agent context; displayed times include the local zone.
func BillingBrief(cs []advise.BillingContext) string {
	if len(cs) == 0 {
		return "Base API reference costs only; consult modelplan windows for time-of-day plan rates."
	}
	var lines []string
	style := Style{T: EN}
	for _, c := range cs {
		lines = append(lines, c.Model+style.BillingSuffix([]advise.BillingContext{c}, c.Model))
	}
	var hint strings.Builder
	style.BillingHint(&hint, cs)
	return "Time-of-day billing context only (reference cost × current rate; not a quota forecast): " + strings.Join(lines, "; ") + ". " + strings.TrimSpace(hint.String()) + " The user decides whether to wait or change settings; never switch automatically."
}

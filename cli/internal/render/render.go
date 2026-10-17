// Package render prints the hangar visual language in a terminal:
// amber values, gold only for ★ recommended and best value, same words as the website.
package render

import (
	"fmt"
	"io"
	"math"
	"sort"
	"strings"
	"unicode"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/lineup"
)

type Style struct {
	Color bool
	T     Text
	// Narrow: the status line has under StatuslineWide columns; it drops the ability and
	// shortens the quota bars.
	Narrow bool
}

// StatuslineWide is the width (COLUMNS) from which the status line shows its full form.
const StatuslineWide = 100

// ANSI 256 palette from clients/design-kit/README.md.
const (
	amber = "38;5;215"
	above = "38;5;221" // an effort above ★
	gold  = "38;5;222"
	cost  = "38;5;209"
	tcyan = "38;5;117"
	dim   = "38;5;244"
	hi    = "38;5;230"
	okc   = "38;5;120"
	warn  = "38;5;203"
	bold  = "1"
)

func (s Style) c(code, v string) string {
	if !s.Color || v == "" {
		return v
	}
	return "\x1b[" + code + "m" + v + "\x1b[0m"
}

// Text holds every user-visible string; zh is the default, en mirrors the website's English.
type Text struct {
	WhichEngine, AtRec, BaseIs, Ability, Cost, Time, Skip, SkipWhy, Strongest, BestValue, Cheapest,
	NotBetter, Equivalent, Recommended, AboveRec, Estimated, Stale, NotListed, Syncing, VsRec, Pts, SkipFmt, StepUp string
}

var ZH = Text{
	WhichEngine: "选哪台", AtRec: "各模型都在 ★推荐档", BaseIs: "成本以 %s 为 ×1",
	Ability: "能力", Cost: "成本", Time: "耗时", Skip: "跳过", SkipWhy: "又贵又不更强",
	Strongest: "最强", BestValue: "最划算", Cheapest: "最省", NotBetter: "不如 %s", Equivalent: "≈ %s 但更贵",
	Recommended: "推荐", AboveRec: "超推荐", Estimated: "估算", Stale: "数据过期", NotListed: "未核对型号",
	Syncing: "正在同步数据…", VsRec: "相对 ★推荐", Pts: "分", SkipFmt: "%s：%s（%s）", StepUp: "↑ 比低一档",
}

var EN = Text{
	WhichEngine: "Which engine", AtRec: "every model at its ★ recommended effort", BaseIs: "cost relative to %s = ×1",
	Ability: "ability", Cost: "cost", Time: "time", Skip: "Skip", SkipWhy: "costs more, not stronger",
	Strongest: "strongest", BestValue: "best value", Cheapest: "cheapest", NotBetter: "not better than %s", Equivalent: "≈ %s, costs more",
	Recommended: "recommended", AboveRec: "above rec.", Estimated: "estimate", Stale: "stale data", NotListed: "id not reviewed",
	Syncing: "syncing data…", VsRec: "vs ★", Pts: "pts", SkipFmt: "%s: %s (%s)", StepUp: "↑ vs one below",
}

// Short drops the developer prefix the website also drops in tight spaces ("Claude Opus 5.5" → "Opus 5.5").
func Short(name string) string {
	for _, p := range []string{"Claude ", "Gemini "} {
		if strings.HasPrefix(name, p) {
			return strings.TrimPrefix(name, p)
		}
	}
	return name
}

func X(v float64) string {
	switch {
	case v < 1:
		return fmt.Sprintf("×%.2f", v)
	case v < 10:
		return fmt.Sprintf("×%.1f", v)
	default:
		return fmt.Sprintf("×%.0f", v)
	}
}

// width counts East Asian wide runes as two cells.
func width(s string) int {
	n := 0
	for _, r := range s {
		if unicode.Is(unicode.Han, r) || (r >= 0x3000 && r <= 0x303f) || (r >= 0xff00 && r <= 0xffef) {
			n += 2
		} else {
			n++
		}
	}
	return n
}

func pad(s string, w int) string {
	if d := w - width(s); d > 0 {
		return s + strings.Repeat(" ", d)
	}
	return s
}

func bar(frac float64, cells int) string {
	parts := []rune(" ▏▎▍▌▋▊▉█")
	frac = math.Max(0, math.Min(1, frac))
	eighths := int(math.Round(frac * float64(cells*8)))
	s := strings.Repeat("█", eighths/8)
	if r := eighths % 8; r > 0 {
		s += string(parts[r])
	}
	return pad(s, cells)
}

func (s Style) Tag(l *lineup.Lineup, r *lineup.Row, name func(string) string) string {
	var out []string
	for _, t := range r.Tags {
		switch t {
		case "strongest":
			out = append(out, s.c(bold+";38;5;216", s.T.Strongest))
		case "best_value":
			out = append(out, s.c(bold+";"+gold, s.T.BestValue))
		case "cheapest":
			out = append(out, s.c(okc, s.T.Cheapest))
		case "dominated":
			out = append(out, s.c(warn, fmt.Sprintf(s.T.NotBetter, name(r.DominatedBy.ID))))
		case "equivalent_costlier":
			out = append(out, s.c(warn, fmt.Sprintf(s.T.Equivalent, name(r.DominatedBy.ID))))
		}
	}
	return strings.Join(out, " ")
}

// Lineup prints the WHICH ENGINE panel for one developer.
func (s Style) Lineup(w io.Writer, d *digest.Digest, dev string) error {
	ms := d.Developer(dev)
	l := d.Lineup(dev)
	if l == nil {
		return fmt.Errorf("%s: no published lineup (at least two complete comparable models required)", dev)
	}
	by := map[string]*digest.Model{}
	for _, m := range ms {
		by[m.ID] = m
	}
	name := func(id string) string { return Short(by[id].Name) }
	devName := digest.DeveloperNames[dev]
	if devName == "" {
		devName = dev
	}
	fmt.Fprintf(w, "%s · %s · %s · %s\n", s.c(bold+";"+amber, "WHICH ENGINE "+s.T.WhichEngine), devName, s.c(dim, s.T.AtRec), s.c(dim, fmt.Sprintf(s.T.BaseIs, name(l.Baseline))))
	for _, st := range l.Steps {
		fmt.Fprintf(w, "  %s  %s %s  %s %s\n", pad(name(st.From)+" → "+name(st.To), 26), s.c(dim, s.T.Ability), s.c(amber, fmt.Sprintf("%+.1f", st.AbilityDelta)), s.c(dim, s.T.Cost), s.c(cost, X(st.CostRatio)))
	}
	var skip []string
	for _, r := range l.Members {
		if r.DominatedBy != nil {
			skip = append(skip, name(r.ID))
		}
	}
	if len(skip) > 0 {
		fmt.Fprintf(w, "  %s\n", s.c(warn, fmt.Sprintf(s.T.SkipFmt, s.T.Skip, strings.Join(skip, sep(s.T)), s.T.SkipWhy)))
	}
	fmt.Fprintln(w)

	rows := append([]*lineup.Row(nil), l.Members...)
	sort.SliceStable(rows, func(i, j int) bool { return rows[i].Ability > rows[j].Ability })
	aMax, xMax := 0.0, 1.0
	for _, r := range rows {
		aMax, xMax = math.Max(aMax, r.Ability), math.Max(xMax, r.CostRelative)
	}
	for _, r := range rows {
		m := by[r.ID]
		eff := "—"
		if rec := m.Rec(); rec != nil {
			eff = "★" + rec.Label
		}
		if r.Status == "incomplete" {
			fmt.Fprintf(w, "  %s %s  %s\n", pad(name(r.ID), 18), s.c(gold, pad(eff, 8)), s.c(dim, "—"))
			continue
		}
		cells := int(math.Round((math.Log2(r.CostRelative) + 1) / (math.Log2(xMax) + 1) * 5))
		fuel := strings.Repeat("▰", max(1, cells)) + strings.Repeat("▱", 5-max(1, cells))
		fmt.Fprintf(w, "  %s %s %s %s %s  %s %s %s  %s\n",
			pad(name(r.ID), 18), s.c(gold, pad(eff, 8)),
			s.c(dim, s.T.Ability), s.c(hi, fmt.Sprintf("%5.1f", r.Ability)), s.c(amber, bar(r.Ability/aMax, 12)),
			s.c(dim, s.T.Cost), s.c(cost, pad(X(r.CostRelative), 6)), s.c(cost, fuel),
			s.Tag(l, r, name))
	}
	return nil
}

// Effort prints one model's ladder relative to its ★ recommended effort.
func (s Style) Effort(w io.Writer, m *digest.Model) {
	rec := m.Rec()
	fmt.Fprintf(w, "%s  %s\n", s.c(bold+";"+hi, m.Name), s.c(dim, fmt.Sprintf("%d · ★ %s %s · %s · %s", len(m.Efforts), labelOf(rec), s.T.Recommended, s.T.VsRec, s.T.StepUp)))
	ri := -1
	for i := range m.Efforts {
		if &m.Efforts[i] == rec {
			ri = i
		}
	}
	for i := len(m.Efforts) - 1; i >= 0; i-- {
		e := &m.Efforts[i]
		lever, label := "│", pad(e.Label, 8)
		switch {
		case i == ri:
			lever, label = s.c(gold, "◆"), s.c(bold+";"+gold, pad("★ "+e.Label, 8))
		case ri >= 0 && i > ri:
			lever = s.c(cost, "┆")
		}
		fmt.Fprintf(w, "  %s %s  %s %s  %s %s  %s %s  %s\n", lever, label,
			s.c(dim, s.T.Ability), s.c(hi, pad(num(e.Ability, rec, true, s.T.Pts), 14)),
			s.c(dim, s.T.Cost), s.c(cost, pad(num(e.Cost, rec, false, ""), 7)),
			s.c(dim, s.T.Time), s.c(tcyan, pad(timeOf(e, rec, s.T.Estimated), 6)),
			s.c(dim, step(m.Efforts, i, s.T.Pts)))
	}
}

// step is one effort against the next lower one: "↑ +3.7分 ×1.45". Empty for the lowest.
func step(es []digest.Effort, i int, pts string) string {
	if i == 0 {
		return ""
	}
	lo, hi := es[i-1], es[i]
	if lo.Ability == nil || hi.Ability == nil || lo.Cost == nil || hi.Cost == nil || *lo.Cost <= 0 {
		return "↑ —"
	}
	return fmt.Sprintf("↑ %+.1f%s ×%.2f", *hi.Ability-*lo.Ability, pts, *hi.Cost / *lo.Cost)
}

func sep(t Text) string {
	if t.Pts == "pts" {
		return ", "
	}
	return "、"
}

func labelOf(e *digest.Effort) string {
	if e == nil {
		return "—"
	}
	return e.Label
}

func num(v *float64, rec *digest.Effort, ability bool, pts string) string {
	if v == nil {
		return "—"
	}
	if ability {
		if rec == nil || rec.Ability == nil {
			return fmt.Sprintf("%.1f", *v)
		}
		return fmt.Sprintf("%.1f (%+.1f%s)", *v, *v-*rec.Ability, pts)
	}
	if rec == nil || rec.Cost == nil || *rec.Cost == 0 {
		return "—"
	}
	return X(*v / *rec.Cost)
}

func timeOf(e, rec *digest.Effort, est string) string {
	if e.Time == nil || rec == nil || rec.Time == nil || *rec.Time == 0 || e.TimeBasis == nil || rec.TimeBasis == nil || *e.TimeBasis != *rec.TimeBasis {
		return "—"
	}
	s := X(*e.Time / *rec.Time)
	if e.TimeEstimated || rec.TimeEstimated {
		s += " " + est
	}
	return s
}

// Statusline renders one line for a harness status bar. It never touches the network. With a
// quota segment to follow (withQuota) or a narrow bar it leaves out the cost and lineup tags;
// a narrow bar also drops the ability.
func (s Style) Statusline(d *digest.Digest, m *digest.Model, effort string, stale bool, raw string, withQuota bool) string {
	tail := ""
	if stale {
		tail = " │ " + s.c(warn, s.T.Stale)
	}
	if m == nil {
		label := "Model Plan"
		if raw != "" {
			label += " · " + s.T.NotListed + " " + raw
		}
		return s.c(amber, "▲ ") + s.c(dim, label) + tail
	}
	rec := m.Rec()
	cur := rec
	if effort != "" {
		if e := m.Effort(effort); e != nil {
			cur = e
		}
	}
	parts := []string{s.c(amber, "▲ ") + s.c(bold+";"+hi, Short(m.Name)) + " " + effTag(s, m, cur, rec)}
	if s.Narrow {
		return parts[0] + tail
	}
	if cur != nil && cur.Ability != nil {
		parts = append(parts, s.c(dim, s.T.Ability+" ")+s.c(amber, fmt.Sprintf("%.1f", *cur.Ability)))
	}
	ms := d.Developer(m.DeveloperID)
	if l := d.Lineup(m.DeveloperID); l != nil && cur == rec && !withQuota {
		by := map[string]*digest.Model{}
		for _, x := range ms {
			by[x.ID] = x
		}
		name := func(id string) string { return Short(by[id].Name) }
		if r := l.Row(m.ID); r != nil && r.Status == "" {
			parts = append(parts, s.c(dim, s.T.Cost+" ")+s.c(cost, X(r.CostRelative))+s.c(dim, " vs "+name(l.Baseline)))
			if t := s.Tag(l, r, name); t != "" {
				parts = append(parts, t)
			}
		}
	}
	return strings.Join(parts, s.c(dim, " │ ")) + tail
}

// effTag: ★ and the label at the recommended effort; otherwise the label, warm above ★ and cool
// below it, with ★ in brackets.
func effTag(s Style, m *digest.Model, cur, rec *digest.Effort) string {
	switch {
	case cur == nil:
		return ""
	case cur == rec:
		return s.c(gold, "★"+cur.Label)
	}
	colour := hi
	if rec != nil {
		if i, r := effortIndex(m, cur), effortIndex(m, rec); i > r {
			colour = above
		} else if i < r {
			colour = tcyan
		}
	}
	return s.c(colour, cur.Label) + s.c(dim, " (★"+labelOf(rec)+")")
}

func effortIndex(m *digest.Model, e *digest.Effort) int {
	for i := range m.Efforts {
		if &m.Efforts[i] == e {
			return i
		}
	}
	return -1
}

package render

import (
	"fmt"
	"io"
	"sort"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

type measuredText struct {
	Title, None, Turn, Tokens, Rate, TTFT, Turns, Few, Default, Published, PublishedAbout, PublishedUpTo, Sec, Min string
}

var measuredZH = measuredText{
	Title: "你的实测（只在这台电脑上，近 28 天；只读时间戳和 token 数）", None: "还没有实测：Claude Code 状态栏或插件钩子运行时、Codex 插件钩子运行时才会记。",
	Turn: "每轮 %s", Tokens: "%s token", Rate: "输出 %s tok/s", TTFT: "首字 %s", Turns: "%d 轮", Few: "样本不足（%d 轮，%d 次请求）",
	Default: "默认档", Published: "（公布 %s）", PublishedAbout: "（公布约 %s）", PublishedUpTo: "（公布最多 %s）", Sec: "秒", Min: "分",
}

var measuredEN = measuredText{
	Title: "Measured here (this machine only, last 28 days; timestamps and token counts only)", None: "Nothing measured yet: the Claude Code status line or plugin hooks, and the Codex plugin hook, measure as they run.",
	Turn: "turn %s", Tokens: "%s tokens", Rate: "%s tok/s out", TTFT: "first token %s", Turns: "%d turns", Few: "too few samples (%d turns, %d requests)",
	Default: "default", Published: " (published %s)", PublishedAbout: " (published about %s)", PublishedUpTo: " (published up to %s)", Sec: "s", Min: "m",
}

func (s Style) mt() measuredText {
	if s.T.Pts == "pts" {
		return measuredEN
	}
	return measuredZH
}

// MeasuredFor keeps the stats of one published model.
func MeasuredFor(stats []speed.Stat, d *digest.Digest, m *digest.Model) []speed.Stat {
	out := []speed.Stat{}
	for _, x := range stats {
		if m != nil && measuredModel(d, x) == m {
			out = append(out, x)
		}
	}
	return out
}

func measuredModel(d *digest.Digest, x speed.Stat) *digest.Model {
	if d == nil {
		return nil
	}
	if m := d.Model(x.Model); m != nil {
		return m
	}
	return d.MatchAt(x.Source, "", x.Model)
}

// Measured prints the user's own measured speed per harness and model: each effort and speed mode,
// turns and output tokens against the ★ effort in standard mode (with the published time multiple
// beside it), a speed mode's output rate against the same effort in standard mode (with the
// published speed-up). With header=false the title line is left out.
func (s Style) Measured(w io.Writer, stats []speed.Stat, d *digest.Digest, header bool) {
	t := s.mt()
	if header {
		fmt.Fprintln(w, s.c(dim, t.Title))
	}
	if len(stats) == 0 {
		fmt.Fprintln(w, s.c(dim, "  "+t.None))
		return
	}
	type group struct {
		source, model string
		m             *digest.Model
		xs            []speed.Stat
	}
	var gs []*group
	for _, x := range stats {
		m := measuredModel(d, x)
		var g *group
		for _, y := range gs {
			if y.source == x.Source && y.model == x.Model {
				g = y
			}
		}
		if g == nil {
			g = &group{source: x.Source, model: x.Model, m: m}
			gs = append(gs, g)
		}
		g.xs = append(g.xs, x)
	}
	q := s.qt()
	for _, g := range gs {
		name := g.model
		if g.m != nil {
			name = Short(g.m.Name)
		}
		fmt.Fprintf(w, "%s %s\n", s.c(amber, "▲"), s.c(bold+";"+hi, sourceName(q, g.source)+" · "+name))
		rank := func(x speed.Stat) int {
			if g.m != nil {
				for i := range g.m.Efforts {
					if strings.EqualFold(g.m.Efforts[i].Effort, x.Effort) {
						return i
					}
				}
			}
			return -1
		}
		sort.SliceStable(g.xs, func(i, j int) bool {
			if a, b := rank(g.xs[i]), rank(g.xs[j]); a != b {
				return a > b // the ladder's order: highest effort first
			}
			return g.xs[i].Speed < g.xs[j].Speed
		})
		var star *speed.Stat
		var rec *digest.Effort
		if g.m != nil {
			rec = g.m.Rec()
		}
		for i := range g.xs {
			if x := &g.xs[i]; rec != nil && x.Speed == "" && strings.EqualFold(x.Effort, rec.Effort) {
				star = x
			}
		}
		for _, x := range g.xs {
			fmt.Fprintf(w, "  %s  %s\n", pad(s.measuredLabel(g.m, x), 14), s.measuredLine(g.m, x, star, g.xs, d))
		}
	}
}

func (s Style) measuredLabel(m *digest.Model, x speed.Stat) string {
	t := s.mt()
	label := x.Effort
	if label == "" {
		label = t.Default
	}
	if m != nil {
		if e := m.Effort(x.Effort); e != nil && x.Effort != "" {
			label = e.Label
			if e == m.Rec() {
				label = "★" + label
			}
		}
	}
	if x.Speed != "" {
		label += " ⚡"
		if x.Speed != "fast" {
			label += x.Speed
		}
	}
	return label
}

func (s Style) measuredLine(m *digest.Model, x speed.Stat, star *speed.Stat, all []speed.Stat, d *digest.Digest) string {
	t := s.mt()
	if x.TurnSeconds == nil && x.OutputTokensPerSecond == nil {
		return s.c(dim, fmt.Sprintf(t.Few, x.Turns, x.Requests))
	}
	var parts []string
	vsStar := star != nil && x.Speed == "" && x.Effort != star.Effort
	if x.TurnSeconds != nil {
		p := fmt.Sprintf(t.Turn, s.seconds(*x.TurnSeconds))
		if vsStar && star.TurnSeconds != nil && *star.TurnSeconds > 0 {
			p += s.c(tcyan, fmt.Sprintf(" ×%.2f", *x.TurnSeconds / *star.TurnSeconds))
			if pub := publishedTime(m, x.Effort); pub > 0 {
				p += s.c(dim, fmt.Sprintf(t.Published, fmt.Sprintf("×%.2f", pub)))
			}
		}
		parts = append(parts, p)
	}
	if x.TurnOutputTokens != nil {
		p := fmt.Sprintf(t.Tokens, tokens(*x.TurnOutputTokens))
		if vsStar && star.TurnOutputTokens != nil && *star.TurnOutputTokens > 0 {
			p += s.c(tcyan, fmt.Sprintf(" ×%.2f", *x.TurnOutputTokens / *star.TurnOutputTokens))
		}
		parts = append(parts, p)
	}
	if x.OutputTokensPerSecond != nil {
		p := fmt.Sprintf(t.Rate, fmt.Sprintf("%.0f", *x.OutputTokensPerSecond))
		if x.Speed != "" {
			for _, y := range all {
				if y.Speed == "" && y.Effort == x.Effort && y.OutputTokensPerSecond != nil && *y.OutputTokensPerSecond > 0 {
					p += s.c(tcyan, fmt.Sprintf(" ×%.2f", *x.OutputTokensPerSecond / *y.OutputTokensPerSecond))
					p += s.c(dim, s.publishedSpeed(d, m, x))
				}
			}
		}
		parts = append(parts, p)
	}
	if x.TTFTSeconds != nil {
		parts = append(parts, fmt.Sprintf(t.TTFT, s.seconds(*x.TTFTSeconds)))
	}
	parts = append(parts, s.c(dim, fmt.Sprintf(t.Turns, x.Turns)))
	return strings.Join(parts, s.c(dim, " · "))
}

// publishedTime: the effort's published time multiple against ★, when both are timed.
func publishedTime(m *digest.Model, effort string) float64 {
	if m == nil {
		return 0
	}
	e, r := m.Effort(effort), m.Rec()
	if e == nil || r == nil || e.Time == nil || r.Time == nil || *r.Time <= 0 {
		return 0
	}
	return *e.Time / *r.Time
}

func (s Style) publishedSpeed(d *digest.Digest, m *digest.Model, x speed.Stat) string {
	if d == nil || m == nil {
		return ""
	}
	t := s.mt()
	for _, tier := range d.SpeedTiers(m.ID, x.Source) {
		if tier.Tier != x.Speed || tier.Model == nil || tier.Model.Speed.Ratio == nil {
			continue
		}
		v := fmt.Sprintf("×%s", g(*tier.Model.Speed.Ratio))
		if tier.Model.Speed.Qualifier == "up-to" {
			return fmt.Sprintf(t.PublishedUpTo, v)
		}
		return fmt.Sprintf(t.PublishedAbout, v)
	}
	return ""
}

func (s Style) seconds(v float64) string {
	t := s.mt()
	switch {
	case v < 10:
		return fmt.Sprintf("%.1f%s", v, t.Sec)
	case v < 60:
		return fmt.Sprintf("%.0f%s", v, t.Sec)
	}
	n := int(v + 0.5)
	return fmt.Sprintf("%d%s%02d%s", n/60, t.Min, n%60, t.Sec)
}

func tokens(v float64) string {
	if v < 1000 {
		return fmt.Sprintf("%.0f", v)
	}
	return fmt.Sprintf("%.1fk", v/1000)
}

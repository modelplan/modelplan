package render

import (
	"fmt"
	"io"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
)

type historyText struct {
	Title, Off, None, Running, Ended, Used, Full, Before, Summary string
}

var historyZH = historyText{
	Title: "本机额度记录（只存在这台电脑上，不上传；MODELPLAN_HISTORY=off 停止记录，删除 %s 清空）",
	Off:   "已关闭记录（MODELPLAN_HISTORY=off）。", None: "还没有记录：Claude Code 状态栏、插件钩子或 advise 运行时才会记。",
	Running: "进行中，%s重置", Ended: "%s 重置", Used: "用到 %.0f%%", Full: "（用满）", Before: "开始记录前 %.0f 点",
	Summary: "最近 %d 天 %d 个周期 · 平均用到 %.0f%% · 用满 %d 次",
}

var historyEN = historyText{
	Title: "Quota history on this machine (kept here, never uploaded; MODELPLAN_HISTORY=off stops it, deleting %s clears it)",
	Off:   "Recording is off (MODELPLAN_HISTORY=off).", None: "Nothing recorded yet: the Claude Code status line, the plugin hooks or advise record as they run.",
	Running: "running, resets in %s", Ended: "reset %s", Used: "used %.0f%%", Full: " (used up)", Before: "%.0f pts before recording",
	Summary: "last %d days, %d cycles · used %.0f%% on average · used up %d times",
}

func (s Style) ht() historyText {
	if s.T.Pts == "pts" {
		return historyEN
	}
	return historyZH
}

// History prints the ledger: each longer cycle (week) on its own line with where its points went,
// five-hour cycles as one summary line per source.
func (s Style) History(w io.Writer, l history.Ledger, d *digest.Digest, file string, now time.Time) {
	t, q := s.ht(), s.qt()
	fmt.Fprintln(w, s.c(dim, fmt.Sprintf(t.Title, file)))
	if history.Off() {
		fmt.Fprintln(w, t.Off)
	}
	if len(l.Cycles) == 0 {
		fmt.Fprintln(w, s.c(dim, t.None))
		return
	}
	type group struct{ source, kind string }
	var order []group
	by := map[group][]history.Cycle{}
	for _, c := range l.Cycles {
		g := group{c.Source, c.Kind}
		if _, ok := by[g]; !ok {
			order = append(order, g)
		}
		by[g] = append(by[g], c)
	}
	sort.SliceStable(order, func(i, j int) bool {
		if order[i].source != order[j].source {
			return order[i].source < order[j].source
		}
		return order[i].kind > order[j].kind // weekly before five_hour
	})
	for _, g := range order {
		cs := by[g]
		sort.SliceStable(cs, func(i, j int) bool { return cs[i].ResetsAt.After(cs[j].ResetsAt) })
		fmt.Fprintf(w, "%s %s\n", s.c(amber, "▲"), s.c(bold+";"+hi, sourceName(q, g.source)+" "+q.Kinds[g.kind]))
		if g.kind == "five_hour" {
			var n, full int
			var sum float64
			for _, c := range cs {
				if c.Done(now) {
					n, sum = n+1, sum+c.LastUsed
					if c.HitLimit {
						full++
					}
				}
			}
			if n > 0 {
				fmt.Fprintf(w, "  %s\n", fmt.Sprintf(t.Summary, int(now.Sub(cs[len(cs)-1].ResetsAt).Hours()/24)+1, n, sum/float64(n), full))
			}
			if c := cs[0]; !c.Done(now) {
				fmt.Fprintf(w, "  %s\n", s.cycleLine(c, d, now))
			}
			continue
		}
		for _, c := range cs {
			fmt.Fprintf(w, "  %s\n", s.cycleLine(c, d, now))
		}
	}
}

func (s Style) cycleLine(c history.Cycle, d *digest.Digest, now time.Time) string {
	t, q := s.ht(), s.qt()
	when := fmt.Sprintf(t.Ended, c.ResetsAt.Local().Format("01-02"))
	if !c.Done(now) {
		when = fmt.Sprintf(t.Running, q.Dur(int(c.ResetsAt.Sub(now).Minutes())+1))
	}
	parts := []string{s.c(tcyan, when), s.c(hi, fmt.Sprintf(t.Used, c.LastUsed))}
	if c.HitLimit {
		parts[1] += s.c(warn, t.Full)
	}
	spent := append([]history.Share(nil), c.Spent...)
	sort.SliceStable(spent, func(i, j int) bool { return spent[i].Points > spent[j].Points })
	for _, x := range spent {
		parts = append(parts, fmt.Sprintf("%s %.0f%s", configName(c.Source, x, d), x.Points, s.ptsUnit()))
	}
	if c.FirstUsed >= 1 {
		parts = append(parts, s.c(dim, fmt.Sprintf(t.Before, c.FirstUsed)))
	}
	return strings.Join(parts, s.c(dim, " · "))
}

func (s Style) ptsUnit() string {
	if s.T.Pts == "pts" {
		return " pts"
	}
	return " 点"
}

// configName: the model's published name and effort label (★ for the recommended one) when the
// publication knows them, else what the harness reported.
func configName(source string, x history.Share, d *digest.Digest) string {
	name, eff := x.Model, x.Effort
	if name == "" {
		name = "?"
	}
	if d != nil {
		m := d.Model(x.Model)
		if m == nil && x.Model != "" {
			m = d.MatchAt(source, "", x.Model)
		}
		if m != nil {
			name = Short(m.Name)
			e := m.Rec()
			if x.Effort != "" {
				e = m.Effort(x.Effort)
			}
			if e != nil {
				eff = e.Label
				if e == m.Rec() {
					eff = "★" + eff
				}
			}
		}
	}
	out := strings.TrimSpace(name + " " + eff)
	if x.Fast {
		out += " ⚡"
	}
	return out
}

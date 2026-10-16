package render

import (
	"fmt"
	"io"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

type quotaText struct {
	RecentThread                                              string // Codex model/effort read from the newest interactive thread, not necessarily this one
	Title, Observed, Stale, Reset, Remaining, Projected, None string
	Kinds, Source, Headroom, Pace                             map[string]string
	Day, Hour, Min                                            string
}

var quotaZH = quotaText{
	RecentThread: "最近本机会话，不一定是当前对话",
	Title:        "额度", Observed: "观测于", Stale: "读数较旧", Reset: "重置", Remaining: "剩", Projected: "按当前速度重置时用到", None: "没有可读的本机额度。",
	Kinds:    map[string]string{"five_hour": "5小时", "weekly": "每周", "monthly": "每月", "spend": "限额", "unknown": "窗口"},
	Source:   map[string]string{"claude-code": "Claude Code", "codex": "Codex", "user": "手填"},
	Headroom: map[string]string{"spend": "额度富余：重置前用不完，可以升档", "normal": "额度正常：按 ★ 推荐档用", "conserve": "额度偏紧：保持 ★ 或降一档", "exhausted": "额度已用完：等重置或换用其他套餐", "unknown": "额度未知"},
	Pace:     map[string]string{"surplus": "富余", "on_track": "正常", "tight": "偏紧", "exhausted": "用完", "reset_passed": "已过重置", "unknown": "—"},
	Day:      "天", Hour: "时", Min: "分",
}

var quotaEN = quotaText{
	RecentThread: "latest local thread, may not be this one",
	Title:        "Quota", Observed: "observed", Stale: "old reading", Reset: "resets", Remaining: "left", Projected: "at this pace, used by reset", None: "No local quota readings.",
	Kinds:    map[string]string{"five_hour": "5h", "weekly": "week", "monthly": "month", "spend": "spend", "unknown": "window"},
	Source:   map[string]string{"claude-code": "Claude Code", "codex": "Codex", "user": "manual"},
	Headroom: map[string]string{"spend": "Surplus: it resets unused, worth stepping up", "normal": "On track: use the ★ effort", "conserve": "Tight: stay at ★ or step down", "exhausted": "Exhausted: wait for the reset or use another plan", "unknown": "Quota unknown"},
	Pace:     map[string]string{"surplus": "surplus", "on_track": "on track", "tight": "tight", "exhausted": "exhausted", "reset_passed": "reset since", "unknown": "—"},
	Day:      "d", Hour: "h", Min: "m",
}

func (s Style) qt() quotaText {
	if s.T.Pts == "pts" {
		return quotaEN
	}
	return quotaZH
}

// Dur is a compact countdown: 42m, 3h12m, 3d4h.
func (q quotaText) Dur(min int) string {
	switch {
	case min < 60:
		return fmt.Sprintf("%d%s", min, q.Min)
	case min < 48*60:
		if min%60 == 0 {
			return fmt.Sprintf("%d%s", min/60, q.Hour)
		}
		return fmt.Sprintf("%d%s%d%s", min/60, q.Hour, min%60, q.Min)
	}
	d, h := min/1440, (min%1440)/60
	if h == 0 {
		return fmt.Sprintf("%d%s", d, q.Day)
	}
	return fmt.Sprintf("%d%s%d%s", d, q.Day, h, q.Hour)
}

func (s Style) paceColour(p string) string {
	switch p {
	case "surplus":
		return okc
	case "tight", "exhausted":
		return warn
	}
	return amber
}

// Quota prints every account with its windows and the headroom advice.
func (s Style) Quota(w io.Writer, r quota.Report) {
	q := s.qt()
	if len(r.Accounts) == 0 {
		fmt.Fprintln(w, s.c(dim, q.None))
	}
	for i, a := range r.Accounts {
		if i > 0 {
			fmt.Fprintln(w)
		}
		head := []string{s.c(bold+";"+hi, q.Source[a.Source])}
		if a.Plan != "" {
			head = append(head, a.Plan)
		}
		if h := a.Harness; h != nil {
			if h.Model != "" {
				head = append(head, h.Model)
			}
			if h.Effort != "" {
				head = append(head, h.Effort)
			}
			if (h.FastMode != nil && *h.FastMode) || h.ServiceTier == "fast" {
				head = append(head, "⚡fast")
			}
			if h.Attribution == "recent-thread" && (h.Model != "" || h.Effort != "") {
				head = append(head, s.c(dim, "("+q.RecentThread+")"))
			}
		}
		age := ""
		if a.Stale {
			age = " " + s.c(warn, q.Stale)
		}
		fmt.Fprintf(w, "%s %s%s\n", s.c(amber, "▲"), strings.Join(head, s.c(dim, " · ")), age)
		for _, x := range a.Windows {
			used, left, reset := "—", "", ""
			frac := 0.0
			if x.UsedPercent != nil {
				used = fmt.Sprintf("%.0f%%", *x.UsedPercent)
				frac = *x.UsedPercent / 100
			}
			if x.RemainingPercent != nil {
				left = fmt.Sprintf("%s %.0f%%", q.Remaining, *x.RemainingPercent)
			}
			if x.ResetsInMinutes != nil {
				reset = fmt.Sprintf("↻ %s", q.Dur(*x.ResetsInMinutes))
			}
			kind := q.Kinds[x.Kind]
			if x.Limit != "" {
				kind += " " + x.Limit
			}
			line := fmt.Sprintf("  %s %s %s  %s  %s  %s", pad(kind, 8), s.c(s.paceColour(x.Pace), bar(frac, 10)), s.c(hi, pad(used, 5)), s.c(dim, pad(left, 9)), s.c(tcyan, pad(reset, 10)), s.c(s.paceColour(x.Pace), q.Pace[x.Pace]))
			if x.ProjectedPercent != nil && x.Pace != "surplus" {
				line += s.c(dim, fmt.Sprintf(" · %s %.0f%%", q.Projected, *x.ProjectedPercent))
			}
			fmt.Fprintln(w, line)
		}
		for _, c := range a.Cards {
			if c.Count != nil && c.ExpiresAt != nil {
				fmt.Fprintf(w, "  %s %d × %s → %s\n", s.c(gold, "◆"), *c.Count, q.Kinds[c.Kind], c.ExpiresAt.Format("2006-01-02 15:04Z"))
			}
		}
		fmt.Fprintf(w, "  %s %s\n", s.c(dim, "→"), s.c(s.paceColour(map[string]string{"spend": "surplus", "conserve": "tight", "exhausted": "exhausted"}[a.Headroom]), q.Headroom[a.Headroom]))
	}
}

// QuotaSegment is the status-line part: "5h 39% ↻42m · week 41%" with a headroom arrow,
// or with the advice hint in its place ("↑High ×1.37").
func (s Style) QuotaSegment(a *quota.Account, hint string) string {
	if a == nil || len(a.Windows) == 0 {
		return ""
	}
	q := s.qt()
	var parts []string
	for _, x := range a.Windows {
		if x.UsedPercent == nil || x.Pace == "reset_passed" || x.Kind == "unknown" {
			continue
		}
		p := q.Kinds[x.Kind] + " " + s.c(s.paceColour(x.Pace), fmt.Sprintf("%.0f%%", *x.UsedPercent))
		if x.ResetsInMinutes != nil && (x.Kind == "five_hour" || *x.ResetsInMinutes < 24*60) {
			p += s.c(dim, " ↻"+q.Dur(*x.ResetsInMinutes))
		}
		parts = append(parts, p)
	}
	if len(parts) == 0 {
		return ""
	}
	arrow := map[string]string{"spend": s.c(okc, " ↑"), "conserve": s.c(warn, " ↓"), "exhausted": s.c(warn, " ✕")}[a.Headroom]
	if hint != "" {
		arrow = " " + hint
	}
	return strings.Join(parts, s.c(dim, " · ")) + arrow
}

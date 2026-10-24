package render

import (
	"fmt"
	"io"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// QuotaNotice is a single factual line for the prompt hook's model context.
func (s Style) QuotaNotice(n advise.QuotaNotice) string {
	q := s.qt()
	if s.T == EN {
		label := map[string]string{"five_hour": "5-hour quota", "weekly": "Weekly quota"}[n.Window]
		if n.Reset {
			label = map[string]string{"five_hour": "5-hour window reset", "weekly": "Weekly window reset"}[n.Window]
		}
		return fmt.Sprintf("%s: %g%% left, resets in %s.", label, n.Remaining, q.Dur(n.ResetsIn))
	}
	label := map[string]string{"five_hour": "5小时额度", "weekly": "每周额度"}[n.Window]
	if n.Reset {
		label = map[string]string{"five_hour": "5小时窗口已重置", "weekly": "每周窗口已重置"}[n.Window]
	}
	return fmt.Sprintf("%s：剩余%g%%，%s后重置。", label, n.Remaining, q.Dur(n.ResetsIn))
}

type quotaText struct {
	RecentThread                                              string // Codex model/effort read from the newest interactive thread, not necessarily this one
	Title, Observed, Stale, Reset, Remaining, Projected, None string
	Kinds, Source, Headroom, Pace                             map[string]string
	Day, Hour, Min                                            string
	RunsOut, RunsOutShort                                     string // at the recent rate: used up in …
	Left, WeekNarrow, RunsOutNarrow                           string // status line: "剩65%", the narrow week label, "≈35分"
	Requests                                                  string
	Credits, Unlimited, ReadAgo, OnCredits                    string // usage credits: "点数 73,172", "不限量", "3分前读取"
}

var quotaZH = quotaText{
	RecentThread: "最近本机会话，不一定是当前对话",
	Requests:     "请求",
	Title:        "额度", Observed: "观测于", Stale: "读数较旧", Reset: "重置", Remaining: "剩", Projected: "按当前速度重置时用到", None: "没有可读的本机额度。",
	Kinds:    map[string]string{"five_hour": "5小时", "weekly": "每周", "monthly": "每月", "spend": "限额", "full": "完整", "unknown": "窗口"},
	Source:   map[string]string{"claude-code": "Claude Code", "codex": "Codex", "user": "手填"},
	Headroom: map[string]string{"spend": "额度富余：重置前用不完，可以升档", "normal": "额度正常：按 ★ 推荐档用", "conserve": "额度偏紧：保持 ★ 或降一档", "exhausted": "额度已用完：等重置或换用其他套餐", "unknown": "额度未知"},
	Pace:     map[string]string{"surplus": "富余", "on_track": "正常", "tight": "偏紧", "exhausted": "用完", "reset_passed": "已过重置，等待读数", "unknown": "—"},
	Day:      "天", Hour: "时", Min: "分",
	RunsOut: "按最近的用量约 %s后用完", RunsOutShort: "≈%s用完",
	Left: "剩%s", WeekNarrow: "周", RunsOutNarrow: "≈%s",
	Credits: "点数", Unlimited: "不限量", ReadAgo: "%s前读取", OnCredits: "额度已用完：继续用会扣点数",
}

var quotaEN = quotaText{
	RecentThread: "latest local thread, may not be this one",
	Requests:     "requests",
	Title:        "Quota", Observed: "observed", Stale: "old reading", Reset: "resets", Remaining: "left", Projected: "at this pace, used by reset", None: "No local quota readings.",
	Kinds:    map[string]string{"five_hour": "5h", "weekly": "week", "monthly": "month", "spend": "spend", "full": "full", "unknown": "window"},
	Source:   map[string]string{"claude-code": "Claude Code", "codex": "Codex", "user": "manual"},
	Headroom: map[string]string{"spend": "Surplus: it resets unused, worth stepping up", "normal": "On track: use the ★ effort", "conserve": "Tight: stay at ★ or step down", "exhausted": "Exhausted: wait for the reset or use another plan", "unknown": "Quota unknown"},
	Pace:     map[string]string{"surplus": "surplus", "on_track": "on track", "tight": "tight", "exhausted": "exhausted", "reset_passed": "reset passed; awaiting reading", "unknown": "—"},
	Day:      "d", Hour: "h", Min: "m",
	RunsOut: "at the recent rate, used up in %s", RunsOutShort: "out ~%s",
	Left: "%s left", WeekNarrow: "wk", RunsOutNarrow: "~%s",
	Credits: "credits", Unlimited: "unlimited", ReadAgo: "read %s ago", OnCredits: "Exhausted: further use draws on credits",
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
		head := []string{s.c(bold+";"+hi, sourceName(q, a.Source))}
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
				kind += " " + LimitName(x.Limit)
			}
			line := fmt.Sprintf("  %s %s %s  %s  %s  %s", pad(kind, 8), s.c(s.paceColour(x.Pace), bar(frac, 10)), s.c(hi, pad(used, 5)), s.c(dim, pad(left, 9)), s.c(tcyan, pad(reset, 10)), s.c(s.paceColour(x.Pace), q.Pace[x.Pace]))
			if x.ProjectedPercent != nil && x.Pace != "surplus" {
				line += s.c(dim, fmt.Sprintf(" · %s %.0f%%", q.Projected, *x.ProjectedPercent))
			}
			if x.RunsOutInMinutes != nil {
				line += s.c(warn, " · "+fmt.Sprintf(q.RunsOut, q.Dur(*x.RunsOutInMinutes)))
			}
			if r := x.Requests; r != nil {
				used, limit := "—", "—"
				if r.Used != nil {
					used = strconv.FormatInt(*r.Used, 10)
				}
				if r.Limit != nil {
					limit = strconv.FormatInt(*r.Limit, 10)
				}
				if r.Unlimited {
					limit = q.Unlimited
				}
				line += fmt.Sprintf(" · %s %s / %s", q.Requests, used, limit)
			}
			fmt.Fprintln(w, line)
		}
		for _, c := range a.Cards {
			if c.Count != nil && c.ExpiresAt != nil {
				fmt.Fprintf(w, "  %s %d × %s → %s\n", s.c(gold, "◆"), *c.Count, q.Kinds[c.Kind], c.ExpiresAt.Format("2006-01-02 15:04Z"))
			} else if c.Count != nil {
				fmt.Fprintf(w, "  %s %d × %s\n", s.c(gold, "◆"), *c.Count, q.Kinds[c.Kind])
			}
		}
		if c := a.Credits; c != nil {
			bal := q.Unlimited
			if c.Balance != nil {
				bal = Thousands(*c.Balance)
			}
			line := fmt.Sprintf("  %s %s %s", s.c(gold, "◇"), q.Credits, s.c(hi, bal))
			if c.AgeMinutes != nil && *c.AgeMinutes >= int(quota.CreditsFresh/time.Minute) {
				line += s.c(dim, " · "+fmt.Sprintf(q.ReadAgo, q.Dur(*c.AgeMinutes)))
			}
			fmt.Fprintln(w, line)
		}
		verdict := q.Headroom[a.Headroom]
		if a.Headroom == "exhausted" && a.Credits != nil {
			verdict = q.OnCredits
		}
		if a.Pool != "" {
			verdict = LimitName(a.Pool) + " · " + verdict // the allowance the verdict is about
		}
		fmt.Fprintf(w, "  %s %s\n", s.c(dim, "→"), s.c(s.paceColour(map[string]string{"spend": "surplus", "conserve": "tight", "exhausted": "exhausted"}[a.Headroom]), verdict))
	}
}

// Thousands: a balance with digit grouping, whole units rounded down ("73,172").
func Thousands(v float64) string {
	n := int64(math.Floor(v))
	d := strconv.FormatInt(n, 10)
	var b strings.Builder
	for i, r := range d {
		if i > 0 && (len(d)-i)%3 == 0 {
			b.WriteByte(',')
		}
		b.WriteRune(r)
	}
	return b.String()
}

// sourceName: the harness, "manual", or another provider: "Cursor · CodexBar" when CodexBar read it,
// its plain name when a native reader did.
func sourceName(q quotaText, source string) string {
	if n, ok := q.Source[source]; ok {
		return n
	}
	if p, ok := strings.CutPrefix(source, "codexbar:"); ok {
		if x, ok := quota.CodexBarProviders[p]; ok {
			return x.Name + " · CodexBar"
		}
	}
	if p, ok := strings.CutPrefix(source, "native:"); ok {
		if x, ok := quota.CodexBarProviders[p]; ok {
			return x.Name
		}
	}
	return source
}

// QuotaSegment is the status-line part, with the advice hint after it ("↑High ×1.37") or else a
// headroom arrow. Wide: "5h ▓▓▓▓▓▓░░░░ 65% left ↻40m · week ▓▓▓▓▓▓▓░░░ 70% left"; narrow:
// "▓▓▓▓░░ 65%↻40m wk70%". The bars show what is left, coloured by it (and amber when the pace is
// tight with plenty left).
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
		left := math.Max(0, 100-*x.UsedPercent)
		tone := leftColour(left, x.Pace)
		pct := fmt.Sprintf("%.0f%%", left)
		reset := ""
		if x.ResetsInMinutes != nil && (x.Kind == "five_hour" || *x.ResetsInMinutes < 24*60) {
			reset = "↻" + q.Dur(*x.ResetsInMinutes)
		}
		var p string
		switch {
		case s.Narrow && x.Kind == "five_hour":
			p = s.leftBar(left, 6, tone) + " " + s.c(tone, pct) + s.c(dim, reset)
		case s.Narrow:
			kind := q.Kinds[x.Kind]
			if x.Kind == "weekly" {
				kind = q.WeekNarrow
			}
			p = s.c(dim, kind) + s.c(tone, pct) + s.c(dim, reset)
		default:
			p = q.Kinds[x.Kind] + " " + s.leftBar(left, 10, tone) + " " + s.c(tone, fmt.Sprintf(q.Left, pct))
			if reset != "" {
				p += s.c(dim, " "+reset)
			}
		}
		// Only a run-out soon enough to make the window tight; a long one over a week overstates a burst.
		if x.RunsOutInMinutes != nil && *x.RunsOutInMinutes <= quota.RunsOutTight {
			f := q.RunsOutShort
			if s.Narrow {
				f = q.RunsOutNarrow
			}
			p += " " + s.c(warn, fmt.Sprintf(f, q.Dur(*x.RunsOutInMinutes)))
		}
		parts = append(parts, p)
	}
	if len(parts) == 0 {
		return ""
	}
	gap, join := "  ", s.c(dim, " · ")
	if s.Narrow {
		gap, join = " ", " "
	}
	arrow := map[string]string{"spend": s.c(okc, "↑"), "conserve": s.c(warn, "↓"), "exhausted": s.c(warn, "✕")}[a.Headroom]
	if hint != "" {
		arrow = hint
	}
	if arrow != "" {
		arrow = gap + arrow
	}
	return strings.Join(parts, join) + arrow
}

// leftColour: green with 30% or more left, amber from 10%, red below; amber too when the pace
// says tight while plenty is left.
func leftColour(left float64, pace string) string {
	switch {
	case left < 10 || pace == "exhausted":
		return warn
	case left < 30 || pace == "tight":
		return above
	}
	return okc
}

func (s Style) leftBar(left float64, cells int, tone string) string {
	full := int(math.Round(left / 100 * float64(cells)))
	return s.c(tone, strings.Repeat("▓", full)) + s.c(dim, strings.Repeat("░", cells-full))
}

// LimitName labels an allowance kept apart from the main one: Codex's GPT Reserve, else its limit id.
func LimitName(limit string) string {
	if limit == "reserve" {
		return "Reserve"
	}
	return limit
}

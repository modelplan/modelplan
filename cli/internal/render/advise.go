package render

import (
	"fmt"
	"io"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/advise"
)

type adviceText struct {
	None, Tentative, Cards, Unknown   string
	Exhausted, Wait, UseCard          string
	Tight, Down, Stay, OrModel        string
	Surplus, Up, UpAny, Stronger, Top string
	Announced                         string
	OrFast, FastUnstated, FastUpTo    string
	Back, BackTo, BackNone            string
	Peak, Offpeak                     string
	CardsExpire                       string
	Public                            map[string]string
	PublicTail                        string
	Context                           string
}

var adviceZH = adviceText{
	None: "现在没有需要提醒的事。", Tentative: "（待确认）", Unknown: "未知",
	Exhausted: "%s额度已用完，%s后重置", Wait: "等重置或换用其他套餐", UseCard: "有重置卡可用（需要你自己兑换）",
	Tight: "%s额度偏紧（剩 %s，%s后重置）", Down: "降到 %s%s", Stay: "保持当前档，重活留给强模型", OrModel: "；或换 %s %s%s，能力不低于现在（除非这个任务确实需要当前模型）",
	Surplus: "%s还剩 %s，%s后重置，用不完就作废", OrFast: "；或开 %s（套餐额度 ×%s，%s）", FastUnstated: "提速未公布", FastUpTo: "提速最多 ×%s",
	Announced: "Codex 官方预告重置（%s）：如果包含你的账号，%s额度剩下的 %s 届时作废", Up: "可升到 %s%s", UpAny: "可以升一档或换更强的模型", Stronger: "可换 %s %s%s", Top: "已在最高档，照常用",
	Back: "%s已于 %s 重置", BackTo: "可换回 %s%s", BackNone: "额度已恢复",
	Peak: "%s %s后进入高峰：%s 额度消耗 %s → %s%s，重活可以提前做", Offpeak: "%s %s后进入优惠时段：%s 额度消耗 %s → %s%s，不急的活可以等",
	CardsExpire: "%s 有 %d 张%s重置卡 %s后过期",
	Public: map[string]string{
		"direct_reset_reported_complete": "Codex 官方刚重置了额度", "direct_reset_announced": "Codex 官方宣布将重置额度",
		"reset_credit_issued": "Codex 官方发放了重置卡", "": "Codex 官方有新的重置消息",
	},
	PublicTail: "，你的余量以本机读数为准",
	Context:    "Model Plan 本机额度提醒（只建议，不要改用户的设置；在回答开头用一句话转告即可。×是公开参考任务的 API 成本倍数：同一模型内大致对应额度消耗，跨模型只能作参考，不等于额度一定省这么多）：",
}

var adviceEN = adviceText{
	None: "Nothing to flag right now.", Tentative: " (tentative)", Unknown: "unknown",
	Exhausted: "%s used up, resets in %s", Wait: "wait for the reset or use another plan", UseCard: "a reset card is available (redeem it yourself)",
	Tight: "%s is tight (%s left, resets in %s)", Down: "step down to %s%s", Stay: "stay at this effort and keep the strong model for the hard parts", OrModel: "; or switch to %s %s%s, which scores at least as high (unless this task needs the current model)",
	Surplus: "%s has %s left and resets in %s; unused allowance is lost", OrFast: "; or turn on %s (plan quota ×%s, %s)", FastUnstated: "speed-up not stated", FastUpTo: "up to ×%s faster",
	Announced: "Codex announced a reset (%s): if it covers your account, the %s left in your %s is void then", Up: "step up to %s%s", UpAny: "worth a higher effort or a stronger model", Stronger: "switch to %s %s%s", Top: "already at the top effort",
	Back: "%s reset at %s", BackTo: "switch back to %s%s", BackNone: "the allowance is back",
	Peak: "%s enters peak hours in %s: %s quota rate %s → %s%s; do heavy work first", Offpeak: "%s enters off-peak in %s: %s quota rate %s → %s%s; work that can wait is cheaper then",
	CardsExpire: "%s: %d %s reset card(s) expire in %s",
	Public: map[string]string{
		"direct_reset_reported_complete": "Codex just reset usage limits", "direct_reset_announced": "Codex announced a usage reset",
		"reset_credit_issued": "Codex issued reset credits", "": "New Codex reset news",
	},
	PublicTail: "; your own balance is the local reading",
	Context:    "Model Plan local quota notice (advice only; do not change the user's settings; relay it in one sentence at the start of your reply. × is the published API cost of a reference task: within one model it roughly tracks plan usage; across models it is only a guide, not a promised quota saving):",
}

func (s Style) at() adviceText {
	if s.T.Pts == "pts" {
		return adviceEN
	}
	return adviceZH
}

func (s Style) who(e advise.Event) string {
	q := s.qt()
	src := q.Source[e.Source]
	if e.Source == "user" && e.Plan != "" {
		src = e.Plan
	}
	kind := q.Kinds[e.Window]
	if kind == "" {
		return src
	}
	if s.T.Pts == "pts" {
		return src + " " + kind + " window"
	}
	return src + " " + kind
}

func (s Style) stepTail(st *advise.Step) string {
	if st == nil || st.AbilityDelta == nil || st.CostRatio == nil {
		return ""
	}
	if s.T.Pts == "pts" {
		return fmt.Sprintf(" (%+.1f pts ×%.2f)", *st.AbilityDelta, *st.CostRatio)
	}
	return fmt.Sprintf("（%+.1f%s ×%.2f）", *st.AbilityDelta, s.T.Pts, *st.CostRatio)
}

func label(st *advise.Step) string {
	if st.Recommended {
		return "★" + st.Label
	}
	return st.Label
}

func pct(v *float64) string {
	if v == nil {
		return "—"
	}
	return fmt.Sprintf("%.0f%%", *v)
}

func (s Style) dur(m *int) string {
	if m == nil {
		return "—"
	}
	if *m < 1 {
		return s.qt().Dur(1)
	}
	return s.qt().Dur(*m)
}

func rateX(v *float64, unknown string) string {
	if v == nil {
		return unknown
	}
	return "×" + strings.TrimRight(strings.TrimRight(fmt.Sprintf("%.2f", *v), "0"), ".")
}

// AdviceLine is the full sentence for one event.
func (s Style) AdviceLine(e advise.Event) string {
	t := s.at()
	sep := "："
	if s.T.Pts == "pts" {
		sep = ": "
	}
	st := e.Suggest
	if st == nil {
		st = &advise.Step{Action: "none"}
	}
	tail := s.stepTail(st)
	switch e.Type {
	case advise.WindowExhausted:
		act := t.Wait
		if st.Action == "use_card" {
			act = t.UseCard
		}
		return fmt.Sprintf(t.Exhausted, s.who(e), s.dur(e.InMinutes)) + sep + act
	case advise.WindowTight:
		act := t.Stay
		if st.Action == "step_down" && st.Label != "" {
			act = fmt.Sprintf(t.Down, label(st), tail)
		}
		if alt := e.Alternative; alt != nil && alt.Label != "" {
			act += fmt.Sprintf(t.OrModel, Short(alt.ModelName), label(alt), s.stepTail(alt))
		}
		return fmt.Sprintf(t.Tight, s.who(e), pct(e.RemainingPercent), s.dur(e.InMinutes)) + sep + act
	case advise.ResetSoonSurplus, advise.AnnouncedSurplus:
		act := t.Top
		switch {
		case st.Action == "step_up" && st.Label != "":
			act = fmt.Sprintf(t.Up, label(st), tail)
		case st.Action == "step_up":
			act = t.UpAny
		case st.Action == "stronger_model":
			act = fmt.Sprintf(t.Stronger, Short(st.ModelName), label(st), tail)
		}
		if sp := e.Speed; sp != nil {
			speed := t.FastUnstated
			if sp.SpeedRatio != nil {
				speed = fmt.Sprintf(t.FastUpTo, g(*sp.SpeedRatio))
			}
			act += fmt.Sprintf(t.OrFast, sp.Label, g(sp.QuotaRatio), speed)
		}
		if e.Type == advise.AnnouncedSurplus {
			// The announcement's own time, in the user's zone; its label is in the publication's language.
			at := e.At.Local()
			if s.T.Pts == "pts" {
				return fmt.Sprintf(t.Announced, "by "+at.Format("Jan 2 15:04"), pct(e.RemainingPercent), s.who(e)) + sep + act
			}
			return fmt.Sprintf(t.Announced, fmt.Sprintf("%d月%d日 %s 前", at.Month(), at.Day(), at.Format("15:04")), s.who(e), pct(e.RemainingPercent)) + sep + act
		}
		return fmt.Sprintf(t.Surplus, s.who(e), pct(e.RemainingPercent), s.dur(e.InMinutes)) + sep + act
	case advise.SwitchBack:
		act := t.BackNone
		if st.Action == "switch_back" {
			act = strings.TrimSpace(fmt.Sprintf(t.BackTo, "★"+st.Label, tail))
			if st.Label == "" {
				act = strings.TrimSpace(fmt.Sprintf(t.BackTo, "★", ""))
			}
		}
		when := "—"
		if e.At != nil {
			when = e.At.Local().Format("15:04")
		}
		return fmt.Sprintf(t.Back, s.who(e), when) + sep + act
	case advise.PeakStartsSoon, advise.OffpeakStartsSoon:
		r := e.Rate
		tent := ""
		if r.Status != "CONFIRMED" {
			tent = t.Tentative
		}
		f := t.Peak
		if e.Type == advise.OffpeakStartsSoon {
			f = t.Offpeak
		}
		return fmt.Sprintf(f, e.Plan, s.dur(e.InMinutes), r.Model, rateX(r.From, t.Unknown), rateX(r.To, t.Unknown), tent)
	case advise.CardsExpiring:
		n := 0
		if e.Count != nil {
			n = *e.Count
		}
		return fmt.Sprintf(t.CardsExpire, e.Plan, n, s.qt().Kinds[e.Window], s.dur(e.InMinutes))
	case advise.PublicReset:
		msg, ok := t.Public[e.Public.EventType]
		if !ok {
			msg = t.Public[""]
		}
		return msg + t.PublicTail
	}
	return e.Type
}

// AdviceShort is the status-line hint, or "" when the quota segment already says it.
func (s Style) AdviceShort(e advise.Event) string {
	st := e.Suggest
	if st == nil {
		return ""
	}
	ratio := ""
	if st.CostRatio != nil {
		ratio = fmt.Sprintf(" ×%.2f", *st.CostRatio)
	}
	switch {
	case (e.Type == advise.ResetSoonSurplus || e.Type == advise.AnnouncedSurplus) && st.Action == "step_up" && st.Label != "":
		return s.c(okc, "↑"+label(st)) + s.c(dim, ratio)
	case (e.Type == advise.ResetSoonSurplus || e.Type == advise.AnnouncedSurplus) && st.Action == "stronger_model":
		return s.c(okc, "↑"+Short(st.ModelName)) + s.c(dim, ratio)
	case e.Type == advise.WindowTight && st.Action == "step_down" && st.Label != "":
		return s.c(warn, "↓"+label(st)) + s.c(dim, ratio)
	case e.Type == advise.SwitchBack && st.Action == "switch_back":
		return s.c(gold, "↺★"+st.Label)
	case e.Type == advise.SwitchBack:
		return s.c(okc, "↺")
	}
	return ""
}

// Advice prints every event, one per line.
func (s Style) Advice(w io.Writer, es []advise.Event) {
	if len(es) == 0 {
		fmt.Fprintln(w, s.c(dim, s.at().None))
		return
	}
	for _, e := range es {
		mark := s.c(okc, "↑")
		switch {
		case e.Severity == "warn":
			mark = s.c(warn, "!")
		case e.Type == advise.SwitchBack:
			mark = s.c(gold, "↺")
		case e.Type == advise.PublicReset:
			mark = s.c(tcyan, "◆")
		case e.Type == advise.PeakStartsSoon || e.Type == advise.OffpeakStartsSoon || e.Type == advise.CardsExpiring:
			mark = s.c(amber, "◷")
		}
		line := s.AdviceLine(e)
		if e.Stale {
			line += s.c(dim, " · "+s.qt().Stale)
		}
		fmt.Fprintf(w, "%s %s\n", mark, line)
	}
}

// AdviceContext is the plain text a hook hands to the model.
func (s Style) AdviceContext(es []advise.Event) string {
	if len(es) == 0 {
		return ""
	}
	plain := Style{T: s.T}
	lines := []string{plain.at().Context}
	for _, e := range es {
		lines = append(lines, "- "+plain.AdviceLine(e))
	}
	return strings.Join(lines, "\n")
}

func steps(ss []advise.BriefStep, base string) string {
	var out []string
	for _, s := range ss {
		l := s.Label
		if s.Recommended {
			l = "★" + l
		}
		switch {
		case s.Current && base == "★":
			out = append(out, l)
		case s.Current:
			out = append(out, l+" (current)")
		case s.AbilityDelta != nil && s.CostRatio != nil:
			out = append(out, fmt.Sprintf("%s %+.1f pts ×%.2f", l, *s.AbilityDelta, *s.CostRatio))
		default:
			out = append(out, l+" (no comparable data)")
		}
	}
	return strings.Join(out, " · ")
}

func contains(xs []string, x string) bool {
	for _, v := range xs {
		if v == x {
			return true
		}
	}
	return false
}

// TaskBrief is the start-of-task context a hook hands to the model: the closed set of published
// options and their arithmetic, plus when (not) to speak. English, for the model; it answers in
// the user's language.
func TaskBrief(b *advise.Brief) string {
	if b == nil {
		return ""
	}
	where, thread := "model, effort and Fast in Codex", "thread"
	if b.Harness == "claude-code" {
		where, thread = "model (/model), effort (/effort) and fast mode (/fast) in Claude Code", "session"
	}
	lines := []string{"Model Plan task-start brief (advice only: the user switches " + where + "; never say you changed them)."}
	now := "Now: the plugin could not read the current model; go by the model your own instructions name"
	if b.Model != "" {
		now = "Now: " + b.Model + " · " + b.Effort
		switch {
		case !b.EffortKnown:
			now = "Now: " + b.Model + " (effort not known)"
		case b.AtRec:
			now += " (★ recommended)"
		}
	}
	if b.Window != "" && b.Remaining != nil {
		now += fmt.Sprintf("; %s window %.0f%% left", map[string]string{"five_hour": "5h", "weekly": "weekly"}[b.Window], *b.Remaining)
		if b.ResetsIn != nil {
			now += ", resets in " + Style{T: EN}.dur(b.ResetsIn)
		}
	}
	if b.Headroom != "" {
		now += "; quota " + map[string]string{"spend": "surplus (unused allowance resets away)", "normal": "on track", "conserve": "tight", "exhausted": "used up", "unknown": "unknown"}[b.Headroom]
	}
	lines = append(lines, now+".")
	var ms []string
	for _, m := range b.Models {
		x := fmt.Sprintf("%s ★%s %.1f pts ×%.2f", m.Name, m.Rec, m.Ability, m.CostRelative)
		var tags []string
		for _, t := range m.Tags {
			if t == "strongest" || t == "best_value" || t == "cheapest" {
				tags = append(tags, strings.ReplaceAll(t, "_", " "))
			}
		}
		if m.Skip {
			tags = append(tags, "skip: a better option costs the same or less")
		}
		if len(tags) > 0 {
			x += " (" + strings.Join(tags, ", ") + ")"
		}
		ms = append(ms, x)
	}
	lines = append(lines, "Models at their ★ effort (ability, cost per task relative to the cheapest): "+strings.Join(ms, "; ")+".")
	data := "Costs are the published API cost of a reference task: within one model they roughly track plan usage; across models vendors weight usage their own way, so never promise a quota saving of that size."
	if b.PublishedAt != "" {
		data = "Data: Model Plan publication of " + b.PublishedAt[:min(10, len(b.PublishedAt))] + ". " + data
	}
	lines = append(lines, data)
	if df := b.Default; df != nil {
		why := "the published best value, within 3 pts of the strongest"
		if b.DefaultReason == "strongest" {
			why = "the strongest; the best value scores more than 3 pts lower"
		}
		if contains(df.Tags, "strongest") && contains(df.Tags, "best_value") {
			why = "both the strongest and the best value"
		}
		at := ""
		if b.AtDefault {
			at = " The " + thread + " is on it."
		}
		lines = append(lines, fmt.Sprintf("Default for ordinary tasks: %s ★%s (%s).%s", df.Name, df.Rec, why, at))
	}
	if len(b.Ladder) > 0 && b.EffortKnown {
		lines = append(lines, b.Model+" efforts against the current one: "+steps(b.Ladder, "current")+". A step that adds no ability for more cost is not worth it.")
	} else if len(b.Ladder) > 0 {
		lines = append(lines, b.Model+" efforts against its ★: "+steps(b.Ladder, "★")+". A step that adds no ability for more cost is not worth it.")
	}
	if len(b.DefaultLadder) > 0 {
		lines = append(lines, b.Default.Name+" efforts against its ★: "+steps(b.DefaultLadder, "★")+".")
	}
	if sp := b.Speed; sp != nil {
		speed := "speed-up not stated"
		if sp.SpeedRatio != nil {
			speed = "up to ×" + g(*sp.SpeedRatio) + " faster"
		}
		lines = append(lines, fmt.Sprintf("With the surplus, %s is an option: plan quota ×%s, %s.", sp.Label, g(sp.QuotaRatio), speed))
	}
	lines = append(lines, "Judge this task's difficulty from the request. The default fits most tasks. Only when the current setting clearly does not fit, suggest one configuration from the lines above in one sentence with its multipliers, then carry on: one step below the default for a small, well-bounded change; High or XHigh of the default model for a complex, cross-module task, and back to the default once it is done; the default itself when the "+thread+" is elsewhere and the task is ordinary. Otherwise say nothing about models or efforts.")
	return strings.Join(lines, "\n")
}

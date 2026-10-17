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
	Tight, TightOut, Down, Stay       string
	OrModel                           string
	EffortFree, WaitOffpeak           string
	Surplus, Up, UpAny, Stronger, Top string
	Announced                         string
	OrFast, FastUnstated, FastUpTo    string
	Back, BackTo, BackNone            string
	FastFirst, FastFirstThen          string
	BackFast, FastOff                 string
	Peak, Offpeak                     string
	CardsExpire                       string
	Public                            map[string]string
	PublicTail                        string
	Notice                            string
}

var adviceZH = adviceText{
	None: "现在没有需要提醒的事。", Tentative: "（待确认）", Unknown: "未知",
	Exhausted: "%s额度已用完，%s后重置", Wait: "等重置或换用其他套餐", UseCard: "有重置卡可用（需要你自己兑换）",
	Tight: "%s额度偏紧（剩 %s，%s后重置）", TightOut: "%s额度偏紧（剩 %s，按最近的用量约 %s后用完，%s后才重置）", Down: "降到 %s%s",
	EffortFree: "这个套餐按请求次数计，降档不省额度；重活可以留到重置后", WaitOffpeak: "这个套餐按请求次数计，降档不省额度；%s后进入低倍率时段（%s → %s），不急的活可以等", Stay: "保持当前档，重活留给强模型", OrModel: "；或换 %s %s%s，能力不低于现在（除非这个任务确实需要当前模型）",
	Surplus: "%s还剩 %s，%s后重置，用不完就作废", OrFast: "；或开 %s（套餐额度 ×%s，%s）", FastUnstated: "提速未公布", FastUpTo: "提速最多 ×%s",
	Announced: "Codex 官方预告重置（%s）：如果包含你的账号，%s额度剩下的 %s 届时作废", Up: "可升到 %s%s", UpAny: "可以升一档或换更强的模型", Stronger: "可换 %s %s%s", Top: "已在最高档，照常用",
	Back: "%s已于 %s 重置", BackTo: "可换回 %s%s", BackNone: "额度已恢复",
	FastFirst: "先关掉 %s（额度消耗 ×%s）；", FastFirstThen: "先关掉 %s（额度消耗 ×%s）；还不够再%s",
	BackFast: "，并关掉 %s（额度消耗 ×%s）", FastOff: "可以关掉 %s 了（额度消耗 ×%s）",
	Peak: "%s %s后进入高峰：%s 额度消耗 %s → %s%s，重活可以提前做", Offpeak: "%s %s后进入优惠时段：%s 额度消耗 %s → %s%s，不急的活可以等",
	CardsExpire: "%s 有 %d 张%s重置卡 %s后过期",
	Public: map[string]string{
		"direct_reset_reported_complete": "Codex 官方刚重置了额度", "direct_reset_announced": "Codex 官方宣布将重置额度",
		"reset_credit_issued": "Codex 官方发放了重置卡", "": "Codex 官方有新的重置消息",
	},
	PublicTail: "，你的余量以本机读数为准",
	Notice:     "ModelPlan：",
}

var adviceEN = adviceText{
	None: "Nothing to flag right now.", Tentative: " (tentative)", Unknown: "unknown",
	Exhausted: "%s used up, resets in %s", Wait: "wait for the reset or use another plan", UseCard: "a reset card is available (redeem it yourself)",
	Tight: "%s is tight (%s left, resets in %s)", TightOut: "%s is tight (%s left; at the recent rate it runs out in %s, before the reset in %s)", Down: "step down to %s%s",
	EffortFree: "this plan counts requests, so a lower effort saves no quota; save heavy work for after the reset", WaitOffpeak: "this plan counts requests, so a lower effort saves no quota; the rate drops in %s (%s → %s), so work that can wait is cheaper then", Stay: "stay at this effort and keep the strong model for the hard parts", OrModel: "; or switch to %s %s%s, which scores at least as high (unless this task needs the current model)",
	Surplus: "%s has %s left and resets in %s; unused allowance is lost", OrFast: "; or turn on %s (plan quota ×%s, %s)", FastUnstated: "speed-up not stated", FastUpTo: "up to ×%s faster",
	Announced: "Codex announced a reset (%s): if it covers your account, the %s left in your %s is void then", Up: "step up to %s%s", UpAny: "worth a higher effort or a stronger model", Stronger: "switch to %s %s%s", Top: "already at the top effort",
	Back: "%s reset at %s", BackTo: "switch back to %s%s", BackNone: "the allowance is back",
	FastFirst: "turn %s off first (it draws quota ×%s); ", FastFirstThen: "turn %s off first (it draws quota ×%s); if that is not enough, %s",
	BackFast: " and turn %s off (it draws quota ×%s)", FastOff: "turn %s off now (it draws quota ×%s)",
	Peak: "%s enters peak hours in %s: %s quota rate %s → %s%s; do heavy work first", Offpeak: "%s enters off-peak in %s: %s quota rate %s → %s%s; work that can wait is cheaper then",
	CardsExpire: "%s: %d %s reset card(s) expire in %s",
	Public: map[string]string{
		"direct_reset_reported_complete": "Codex just reset usage limits", "direct_reset_announced": "Codex announced a usage reset",
		"reset_credit_issued": "Codex issued reset credits", "": "New Codex reset news",
	},
	PublicTail: "; your own balance is the local reading",
	Notice:     "ModelPlan: ",
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
	if (e.Source == "user" || e.Basis != "") && e.Plan != "" {
		src = e.Plan // a session linked to a declared plan draws on that plan
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

// backLabel: the configuration a switch-back returns to, with the model when it is another one.
func backLabel(st *advise.Step) string {
	if st.ModelChange && st.ModelName != "" {
		return Short(st.ModelName) + " " + label(st)
	}
	return label(st)
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
		switch {
		case st.Action == "step_down" && st.Label != "":
			act = fmt.Sprintf(t.Down, label(st), tail)
		case st.Action == "effort_free":
			act = t.EffortFree
		case st.Action == "wait_offpeak":
			act = fmt.Sprintf(t.WaitOffpeak, s.dur(st.InMinutes), rateX(st.RateFrom, t.Unknown), rateX(st.RateTo, t.Unknown))
		}
		if fs := e.Fast; fs != nil {
			if st.Action == "step_down" && st.Label != "" {
				act = fmt.Sprintf(t.FastFirstThen, fs.Label, g(fs.QuotaRatio), act)
			} else {
				act = fmt.Sprintf(t.FastFirst, fs.Label, g(fs.QuotaRatio)) + act
			}
		}
		if alt := e.Alternative; alt != nil && alt.Label != "" {
			act += fmt.Sprintf(t.OrModel, Short(alt.ModelName), label(alt), s.stepTail(alt))
		}
		if e.RunsOutInMinutes != nil {
			return fmt.Sprintf(t.TightOut, s.who(e), pct(e.RemainingPercent), s.dur(e.RunsOutInMinutes), s.dur(e.InMinutes)) + sep + act
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
		switch {
		case st.Action == "switch_back" && st.Label != "":
			act = strings.TrimSpace(fmt.Sprintf(t.BackTo, backLabel(st), tail))
		case st.Action == "switch_back":
			act = strings.TrimSpace(fmt.Sprintf(t.BackTo, "★", ""))
		}
		if fs := e.Fast; e.FastOff && fs != nil {
			if st.Action == "switch_back" {
				act += fmt.Sprintf(t.BackFast, fs.Label, g(fs.QuotaRatio))
			} else {
				act = fmt.Sprintf(t.FastOff, fs.Label, g(fs.QuotaRatio))
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
	case e.Type == advise.WindowTight && st.Action == "wait_offpeak":
		return s.c(amber, "◷"+s.dur(st.InMinutes))
	case e.Type == advise.WindowTight && st.Action == "effort_free":
		return s.c(warn, "!") // tight, but a lower effort would not help: no ↓
	case e.Type == advise.SwitchBack && st.Action == "switch_back" && st.Label != "":
		return s.c(gold, "↺"+backLabel(st))
	case e.Type == advise.SwitchBack && st.Action == "switch_back":
		return s.c(gold, "↺★")
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

// AdviceNotice is what a hook shows the user (its systemMessage), one line per event. It never
// reaches the model: the user decides, and the model's answer stays about the task.
func (s Style) AdviceNotice(es []advise.Event) string {
	plain := Style{T: s.T}
	var lines []string
	for _, e := range es {
		lines = append(lines, plain.at().Notice+plain.AdviceLine(e))
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

// planLine: which declared plan pays for the session and how it counts use, in one line.
func planLine(p *advise.Plan, rates []advise.PlanRate) string {
	id := p.ID
	if p.Generation != "" {
		id += " (" + p.Generation + ")"
	}
	now := func(r advise.PlanRate) string {
		if r.Now == nil {
			return ", time-of-day rate now not published"
		}
		if *r.Now == 1 {
			return ""
		}
		return ", " + rateX(r.Now, "") + " now"
	}
	var rs []string
	for _, r := range rates {
		switch {
		case p.Basis == "per-request" && r.Multiplier != nil:
			rs = append(rs, r.Model+" ×"+g(*r.Multiplier)+" per request"+now(r))
		case p.Basis == "token-tariff" && r.UnitsPerUSD != nil:
			rs = append(rs, fmt.Sprintf("%s %s %s per API USD%s", r.Model, g(*r.UnitsPerUSD), p.Unit, now(r)))
		case p.Basis == "relative-multiplier" && r.Multiplier != nil:
			rs = append(rs, r.Model+" ×"+g(*r.Multiplier)+now(r))
		case p.Basis == "per-model-pool" && r.Amount != nil:
			rs = append(rs, fmt.Sprintf("%s its own %s %s pool%s", r.Model, g(*r.Amount), p.Unit, now(r)))
		}
	}
	how := map[string]string{
		"api-proportional":    "counts usage in step with the API price",
		"token-tariff":        "counts " + p.Unit + " per API dollar, per model",
		"relative-multiplier": "multiplies each model's API price",
		"per-request":         "counts requests: a prompt costs the same at any effort, so a lower effort saves no quota and the cost column below does not apply",
		"per-model-pool":      "gives each model its own allowance: another model draws on its own pool, not this one",
		"opaque":              "does not publish per-model rates, so the costs below are API prices only, not quota",
	}[p.Basis]
	if how == "" {
		how = "counts usage in a way the data does not describe"
	}
	line := "Plan paying for this session: " + id + ", declared by the user; it " + how
	if len(rs) > 0 {
		line += " (" + strings.Join(rs, "; ") + ")"
	}
	return line + "."
}

// TaskBrief is the start-of-task context a hook hands to the model, once per thread: the closed
// set of published options and their arithmetic, plus when (not) to speak. English, for the
// model; it answers in the user's language. Kept short: it rides on every thread's first prompt.
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
		now += "; quota " + map[string]string{"spend": "to spare", "normal": "on track", "conserve": "tight", "exhausted": "used up", "unknown": "unknown"}[b.Headroom]
	}
	lines = append(lines, now+".")
	if p := b.Plan; p != nil {
		lines = append(lines, planLine(p, b.PlanRates))
	}
	// Options a better one beats are left out, unless the thread is on one.
	var ms []string
	for _, m := range b.Models {
		if m.Skip && m.Name != b.Model {
			continue
		}
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
	lines = append(lines, "Models at their ★ effort (ability; × is the API cost of a reference task against the cheapest, a guide to quota within one model, never a promised saving across models): "+strings.Join(ms, "; ")+".")
	if df := b.Default; df != nil {
		at := ""
		if b.AtDefault {
			at = "; the " + thread + " is on it"
		}
		lines = append(lines, fmt.Sprintf("Default for ordinary tasks: %s ★%s%s.", df.Name, df.Rec, at))
	}
	if l := ladderLine(b); l != "" {
		lines = append(lines, l)
	}
	if len(b.DefaultLadder) > 0 {
		lines = append(lines, b.Default.Name+" efforts against its ★: "+steps(b.DefaultLadder, "★")+".")
	}
	lines = append(lines, "Say nothing about models or efforts unless the setting clearly does not fit this task; then suggest one configuration from these lines in one sentence with its multiplier and carry on (one step below the default for a small, bounded change; High or XHigh of the default for a complex, cross-module task, back to the default after). Do not bring up quota: the user sees it themselves.")
	return strings.Join(lines, "\n")
}

// TaskBriefUpdate is the one line a thread gets when it moves to a model it has no brief for:
// that model's ladder. The first brief's options and rules still stand.
func TaskBriefUpdate(b *advise.Brief) string {
	if b == nil || b.Model == "" {
		return ""
	}
	l := ladderLine(b)
	if l == "" {
		return ""
	}
	return "Model Plan: the " + map[bool]string{true: "session", false: "thread"}[b.Harness == "claude-code"] + " is now on " + b.Model + ". " + l + " The task-start brief's rules still apply."
}

func ladderLine(b *advise.Brief) string {
	switch {
	case len(b.Ladder) == 0:
		return ""
	case b.EffortKnown:
		return b.Model + " efforts against the current one: " + steps(b.Ladder, "current") + "."
	}
	return b.Model + " efforts against its ★: " + steps(b.Ladder, "★") + "."
}

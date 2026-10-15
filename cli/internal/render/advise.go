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
	Tight, Down, Stay                 string
	Surplus, Up, UpAny, Stronger, Top string
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
	Tight: "%s额度偏紧（剩 %s，%s后重置）", Down: "降到 %s%s", Stay: "保持当前档，重活留给强模型",
	Surplus: "%s还剩 %s，%s后重置，用不完就作废", OrFast: "；或开 %s（套餐额度 ×%s，%s）", FastUnstated: "提速未公布", FastUpTo: "提速最多 ×%s",
	Up: "可升到 %s%s", UpAny: "可以升一档或换更强的模型", Stronger: "可换 %s %s%s", Top: "已在最高档，照常用",
	Back: "%s已于 %s 重置", BackTo: "可换回 %s%s", BackNone: "额度已恢复",
	Peak: "%s %s后进入高峰：%s 额度消耗 %s → %s%s，重活可以提前做", Offpeak: "%s %s后进入优惠时段：%s 额度消耗 %s → %s%s，不急的活可以等",
	CardsExpire: "%s 有 %d 张%s重置卡 %s后过期",
	Public: map[string]string{
		"direct_reset_reported_complete": "Codex 官方刚重置了额度", "direct_reset_announced": "Codex 官方宣布将重置额度",
		"reset_credit_issued": "Codex 官方发放了重置卡", "": "Codex 官方有新的重置消息",
	},
	PublicTail: "，你的余量以本机读数为准",
	Context:    "Model Plan 本机额度提醒（只建议，不要改用户的设置；在回答开头用一句话转告即可）：",
}

var adviceEN = adviceText{
	None: "Nothing to flag right now.", Tentative: " (tentative)", Unknown: "unknown",
	Exhausted: "%s used up, resets in %s", Wait: "wait for the reset or use another plan", UseCard: "a reset card is available (redeem it yourself)",
	Tight: "%s is tight (%s left, resets in %s)", Down: "step down to %s%s", Stay: "stay at this effort and keep the strong model for the hard parts",
	Surplus: "%s has %s left and resets in %s; unused allowance is lost", OrFast: "; or turn on %s (plan quota ×%s, %s)", FastUnstated: "speed-up not stated", FastUpTo: "up to ×%s faster",
	Up: "step up to %s%s", UpAny: "worth a higher effort or a stronger model", Stronger: "switch to %s %s%s", Top: "already at the top effort",
	Back: "%s reset at %s", BackTo: "switch back to %s%s", BackNone: "the allowance is back",
	Peak: "%s enters peak hours in %s: %s quota rate %s → %s%s; do heavy work first", Offpeak: "%s enters off-peak in %s: %s quota rate %s → %s%s; work that can wait is cheaper then",
	CardsExpire: "%s: %d %s reset card(s) expire in %s",
	Public: map[string]string{
		"direct_reset_reported_complete": "Codex just reset usage limits", "direct_reset_announced": "Codex announced a usage reset",
		"reset_credit_issued": "Codex issued reset credits", "": "New Codex reset news",
	},
	PublicTail: "; your own balance is the local reading",
	Context:    "Model Plan local quota notice (advice only; do not change the user's settings; relay it in one sentence at the start of your reply):",
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
		return fmt.Sprintf(t.Tight, s.who(e), pct(e.RemainingPercent), s.dur(e.InMinutes)) + sep + act
	case advise.ResetSoonSurplus:
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
	case e.Type == advise.ResetSoonSurplus && st.Action == "step_up" && st.Label != "":
		return s.c(okc, "↑"+label(st)) + s.c(dim, ratio)
	case e.Type == advise.ResetSoonSurplus && st.Action == "stronger_model":
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

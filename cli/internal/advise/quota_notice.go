package advise

import (
	"math"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

// QuotaSession keeps factual model notices beside the brief state, with the same lifetime.
// Only reset boundaries and sent flags are stored, never quota percentages.
type QuotaSession struct {
	At      time.Time            `json:"at"`
	Windows map[string]QuotaMark `json:"windows"`
}

// QuotaMark is what one thread was told about one window cycle (ResetAt names the cycle).
type QuotaMark struct {
	ResetAt time.Time `json:"resetAt"`
	Level   int       `json:"level,omitempty"` // the lowest threshold sent: 20, 10 or 5
	Pace    bool      `json:"pace,omitempty"`  // the run-out notice was sent
	Surplus bool      `json:"surplus,omitempty"`
	// WasLow: the previous cycle had a low or run-out notice, so its reset is worth a line.
	WasLow    bool `json:"wasLow,omitempty"`
	Recovered bool `json:"recovered,omitempty"`
	// LowResetAt: CLI 0.5.49 and earlier marked one low line (below 15%) per thread, with the
	// reset of its cycle; read once into ResetAt and the 20% level so it is not repeated.
	LowResetAt time.Time `json:"lowResetAt,omitempty"`
}

// current is the mark in this schema.
func (m QuotaMark) current() QuotaMark {
	if !m.ResetAt.IsZero() || m.LowResetAt.IsZero() {
		return m
	}
	if m.Recovered {
		return QuotaMark{ResetAt: m.LowResetAt} // that cycle's reset line went out already
	}
	return QuotaMark{ResetAt: m.LowResetAt, Level: 20}
}

// QuotaNotice is a fresh local fact. Down and Cheaper are filled by NoticeSteps for low
// notices only.
type QuotaNotice struct {
	Kind      string // low | reset | surplus
	Window    string
	Remaining float64
	ResetsIn  int
	// RunsOutIn: minutes until the window runs out at the rate RateOver names, when that is
	// before its reset.
	RunsOutIn *int
	RateOver  string // day | recent
	Down      *Step
	Cheaper   *Step
}

// Low notices fire once per threshold and cycle, for the lowest one reached.
var lowLevels = []int{5, 10, 20}

// A reset later by more than this starts a new cycle (an early reset included); computed reset
// times jitter by seconds.
const cycleJitter = 30 * time.Minute

func lowLevel(left float64) int {
	for _, l := range lowLevels {
		if left <= float64(l) {
			return l
		}
	}
	return 0
}

// Runout is when the window runs out before its reset: the weekly window at the last day's
// rate (a burst is not the week's pace), the 5-hour window at the recent rate (runsOutInMinutes).
func Runout(w *quota.Window, now time.Time) (*int, string) {
	var out *int
	var over string
	switch w.Kind {
	case "weekly":
		out, over = w.LastDayRunout(now), "day"
	case "five_hour":
		out, over = w.RunsOutInMinutes, "recent"
	}
	if out == nil {
		return nil, ""
	}
	return out, over
}

// noticeWindow: a fresh reading of kind in the prompting harness's own pool, else nil.
func noticeWindow(a *quota.Account, kind string, now time.Time) (*quota.Window, float64) {
	w := windowNow(a, kind)
	if w == nil || w.RemainingPercent == nil || w.ResetsInMinutes == nil || w.ResetsAt == nil ||
		w.UnknownReason != "" || w.ObservedAt.IsZero() || w.ObservedAt.After(now) ||
		now.Sub(w.ObservedAt) > time.Hour || !w.ResetsAt.After(now) {
		return nil, 0
	}
	left := *w.RemainingPercent
	if math.IsNaN(left) || math.IsInf(left, 0) || left < 0 || left > 100 {
		return nil, 0
	}
	return w, left
}

func noticeAccount(thread string, a *quota.Account) bool {
	return thread != "" && a != nil && (a.Source == "claude-code" || a.Source == "codex") && !a.Stale
}

func noticeKey(a *quota.Account, w *quota.Window) string {
	return strings.Join([]string{a.Source, w.Kind, w.Limit}, "|")
}

// QuotaNotices emits, per window cycle and thread: a low notice for each threshold reached (20,
// 10, 5% left) and one when the recent rate runs the window out before its reset, in one line
// when both are due; else, when no window is tight, one surplus notice for a window resetting
// soon with a lot left (the brief's suggestion may then aim higher); and, after a
// cycle with a low notice, one reset notice. A reset needs a reading with a later reset boundary
// and more than half left; a rising percentage alone does not establish it.
func (s *State) QuotaNotices(thread string, a *quota.Account, now time.Time) []QuotaNotice {
	if !noticeAccount(thread, a) {
		return nil
	}
	q := s.Quotas[thread]
	var out []QuotaNotice
	marked := false
	for _, kind := range []string{"five_hour", "weekly"} {
		w, left := noticeWindow(a, kind, now)
		if w == nil {
			continue
		}
		key := noticeKey(a, w)
		mark, seen := q.Windows[key]
		mark = mark.current()
		before := mark
		if !seen {
			mark = QuotaMark{ResetAt: w.ResetsAt.UTC()}
		} else if w.ResetsAt.After(mark.ResetAt.Add(cycleJitter)) {
			mark = QuotaMark{ResetAt: w.ResetsAt.UTC(), WasLow: mark.Level > 0 || mark.Pace}
		}
		n := QuotaNotice{Window: kind, Remaining: left, ResetsIn: *w.ResetsInMinutes}
		level := lowLevel(left)
		lower := level > 0 && (mark.Level == 0 || level < mark.Level)
		runout, over := Runout(w, now)
		switch {
		case lower || runout != nil && !mark.Pace:
			n.Kind, n.RunsOutIn, n.RateOver = "low", runout, over
			if lower {
				mark.Level = level
			}
			mark.Pace = mark.Pace || runout != nil
		case mark.WasLow && !mark.Recovered && mark.Level == 0 && !mark.Pace && left > 50:
			n.Kind, mark.Recovered = "reset", true
		case level == 0 && !mark.Surplus && a.Headroom == "spend" && resetSoonSurplus(a, w):
			n.Kind, mark.Surplus = "surplus", true
		}
		if n.Kind != "" {
			out = append(out, n)
		}
		// A thread that was told nothing about a window keeps no mark for it.
		if n.Kind != "" || seen && mark != before {
			if q.Windows == nil {
				q.Windows = map[string]QuotaMark{}
			}
			q.Windows[key] = mark
			marked = true
		}
	}
	if marked || !q.At.IsZero() && now.Sub(q.At) > 24*time.Hour {
		if s.Quotas == nil {
			s.Quotas = map[string]QuotaSession{}
		}
		q.At = now.UTC()
		s.Quotas[thread] = q
		s.changed = true
	}
	return out
}

// QuotaResend is the low or run-out notice sent to this thread that still holds, for a context
// that lost it (compacted or resumed): the window's current figures, the lowest share left
// first. It marks nothing.
func (s *State) QuotaResend(thread string, a *quota.Account, now time.Time) *QuotaNotice {
	if !noticeAccount(thread, a) {
		return nil
	}
	var best *QuotaNotice
	for _, kind := range []string{"five_hour", "weekly"} {
		w, left := noticeWindow(a, kind, now)
		if w == nil {
			continue
		}
		mark, ok := s.Quotas[thread].Windows[noticeKey(a, w)]
		mark = mark.current()
		if !ok || w.ResetsAt.After(mark.ResetAt.Add(cycleJitter)) {
			continue
		}
		runout, over := Runout(w, now)
		if !(mark.Level > 0 && left <= float64(mark.Level)) && !(mark.Pace && runout != nil) {
			continue
		}
		if best == nil || left < best.Remaining {
			best = &QuotaNotice{Kind: "low", Window: kind, Remaining: left, ResetsIn: *w.ResetsInMinutes, RunsOutIn: runout, RateOver: over}
		}
	}
	return best
}

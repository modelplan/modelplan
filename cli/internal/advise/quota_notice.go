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

type QuotaMark struct {
	LowResetAt time.Time `json:"lowResetAt"`
	Recovered  bool      `json:"recovered,omitempty"`
}

// QuotaNotice is a fresh local fact, without advice or configuration suggestions.
type QuotaNotice struct {
	Window    string
	Remaining float64
	ResetsIn  int
	Reset     bool
}

// QuotaNotices emits at most one low and one recovery notice per window per thread.
// A recovery needs a reading taken after the low window's reset, with a later reset
// boundary; a rising percentage alone does not establish that the window reset.
func (s *State) QuotaNotices(thread string, a *quota.Account, now time.Time) []QuotaNotice {
	if thread == "" || a == nil || (a.Source != "claude-code" && a.Source != "codex") || a.Stale {
		return nil
	}
	q := s.Quotas[thread]
	var out []QuotaNotice
	for _, kind := range []string{"five_hour", "weekly"} {
		w := windowNow(a, kind)
		if w == nil || w.RemainingPercent == nil || w.ResetsInMinutes == nil || w.ResetsAt == nil ||
			w.UnknownReason != "" || w.ObservedAt.IsZero() || w.ObservedAt.After(now) ||
			now.Sub(w.ObservedAt) > time.Hour || !w.ResetsAt.After(now) {
			continue
		}
		left := *w.RemainingPercent
		if math.IsNaN(left) || math.IsInf(left, 0) || left < 0 || left > 100 {
			continue
		}
		key := strings.Join([]string{a.Source, kind, w.Limit}, "|")
		mark, low := q.Windows[key]
		reset := low && !mark.Recovered && left > 50 &&
			!w.ObservedAt.Before(mark.LowResetAt) && w.ResetsAt.After(mark.LowResetAt)
		if !low && left < 15 || reset {
			if q.Windows == nil {
				q.Windows = map[string]QuotaMark{}
			}
			if reset {
				mark.Recovered = true
			} else {
				mark.LowResetAt = w.ResetsAt.UTC()
			}
			q.Windows[key] = mark
			out = append(out, QuotaNotice{Window: kind, Remaining: left, ResetsIn: *w.ResetsInMinutes, Reset: reset})
		}
	}
	if len(out) > 0 || !q.At.IsZero() && now.Sub(q.At) > 24*time.Hour {
		if s.Quotas == nil {
			s.Quotas = map[string]QuotaSession{}
		}
		q.At = now.UTC()
		s.Quotas[thread] = q
		s.changed = true
	}
	return out
}

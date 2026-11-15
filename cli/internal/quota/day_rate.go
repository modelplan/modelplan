// SPDX-License-Identifier: MIT
package quota

import (
	"math"
	"os"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

const dayRateLook = 24 * time.Hour

// LastDayRunout projects from a full day of this cycle's local readings, never
// the short burst rate. Missing coverage, meter drops and stale readings abstain.
// A boundary between nearby samples is interpolated in percentage points only.
// Endpoint observations define the average; unobserved interior drops are unknown.
func (w Window) LastDayRunout(now time.Time) *int {
	if os.Getenv("MODELPLAN_HISTORY") == "off" || w.UsedPercent == nil || w.ResetsAt == nil ||
		w.ElapsedPercent == nil || w.ResetsInMinutes == nil || w.ResetMode == "rolling" ||
		w.ObservedAt.IsZero() || w.ObservedAt.After(now) || now.Sub(w.ObservedAt) > recentFresh ||
		!w.ResetsAt.After(now) || *w.UsedPercent >= 100 {
		return nil
	}
	samples := append([]Sample(nil), w.recent...)
	samples = append(samples, Sample{At: w.ObservedAt, Used: *w.UsedPercent, ResetsAt: w.ResetsAt})
	sort.SliceStable(samples, func(i, j int) bool { return samples[i].At.Before(samples[j].At) })
	boundary := w.ObservedAt.Add(-dayRateLook)
	var before, after, previous *Sample
	for i := range samples {
		sample := &samples[i]
		if !sameCycle(sample.ResetsAt, w.ResetsAt) || sample.At.After(w.ObservedAt) {
			continue
		}
		if math.IsNaN(sample.Used) || math.IsInf(sample.Used, 0) || sample.Used < 0 {
			return nil
		}
		if !sample.At.After(boundary) {
			before, previous = sample, sample
			continue
		}
		if before == nil || sample.Used < previous.Used {
			return nil
		}
		if after == nil {
			after = sample
		}
		previous = sample
	}
	if before == nil || after == nil || boundary.Sub(before.At) > time.Hour {
		return nil
	}
	used := before.Used
	if !before.At.Equal(boundary) {
		span := after.At.Sub(before.At)
		if span <= 0 || span > time.Hour || after.Used < used {
			return nil
		}
		used += (after.Used - used) * float64(boundary.Sub(before.At)) / float64(span)
	}
	rise := *w.UsedPercent - used
	if rise < recentMinRise {
		return nil
	}
	return projectedRunout(&w, rise/dayRateLook.Hours(), now)
}

// projectedRunout is shared by the short burst and full-day rates. Count from
// the latest reading; a forecast at or after reset is not a run-out warning.
// RunOutForecast is the window's outlook for a consumer that needs a stable moment rather
// than a countdown: it is derived from the reading, so it does not move with the clock. A
// recent rate wins over the cycle average, the same order evalWindow uses for its pace.
func (w Window) RunOutForecast() *rows.WindowForecast {
	switch w.Pace {
	case "tight", "on_track", "surplus", "exhausted":
	default:
		return nil
	}
	out := &rows.WindowForecast{Pace: w.Pace, Basis: "none"}
	if w.Pace == "exhausted" || w.UsedPercent == nil || w.ResetsAt == nil || w.ObservedAt.IsZero() {
		return out
	}
	left := 100 - *w.UsedPercent
	var minutes float64
	switch {
	case w.RunsOutInMinutes != nil && w.RecentPercentPerHour != nil && *w.RecentPercentPerHour > 0:
		out.Basis, minutes = "recent-rate", left / *w.RecentPercentPerHour * 60
	case w.Pace == "tight" && w.ProjectedPercent != nil && *w.ProjectedPercent > 100 && *w.UsedPercent > 0:
		elapsed := float64(w.WindowMinutes) - w.ResetsAt.Sub(w.ObservedAt).Minutes()
		if elapsed <= 0 {
			return out
		}
		out.Basis, minutes = "cycle-average", left*elapsed / *w.UsedPercent
	default:
		return out
	}
	at := w.ObservedAt.Add(time.Duration(minutes * float64(time.Minute)))
	if !at.Before(*w.ResetsAt) {
		out.Basis = "none"
		return out
	}
	out.RunsOutAt = &at
	return out
}

func projectedRunout(w *Window, rate float64, now time.Time) *int {
	if rate <= 0 || math.IsNaN(rate) || math.IsInf(rate, 0) || w.ResetsInMinutes == nil {
		return nil
	}
	out := int(math.Ceil((100-*w.UsedPercent)/rate*60 - now.Sub(w.ObservedAt).Minutes()))
	if out < 1 {
		out = 1
	}
	if out >= *w.ResetsInMinutes {
		return nil
	}
	return &out
}

// SPDX-License-Identifier: MIT
package quota

import (
	"testing"
	"time"
)

func forecastWindow(used float64, sinceStart, untilReset time.Duration, observedAgo time.Duration, now time.Time) Window {
	reset := now.Add(untilReset)
	return Window{Kind: "weekly", WindowMinutes: int((sinceStart + untilReset).Minutes()), UsedPercent: &used, ResetsAt: &reset, ResetMode: "fixed", ObservedAt: now.Add(-observedAgo)}
}

func TestRunOutForecastRecentRateIsTheReadingsMoment(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	w := forecastWindow(60, 100*time.Hour, 68*time.Hour, 0, now)
	w.recent = []Sample{{At: now.Add(-30 * time.Minute), Used: 50, ResetsAt: w.ResetsAt}}
	evalWindow(&w, now)
	f := w.RunOutForecast()
	if f == nil || f.Basis != "recent-rate" || f.RunsOutAt == nil {
		t.Fatalf("forecast = %+v", f)
	}
	// 10 points in 30 minutes leaves 40 points for two hours.
	if want := now.Add(2 * time.Hour); !f.RunsOutAt.Equal(want) {
		t.Fatalf("runsOutAt = %s, want %s", f.RunsOutAt, want)
	}
	// The moment comes from the reading, so re-evaluating later does not move it.
	later := now.Add(5 * time.Minute)
	evalWindow(&w, later)
	if g := w.RunOutForecast(); g == nil || g.RunsOutAt == nil || !g.RunsOutAt.Equal(*f.RunsOutAt) {
		t.Fatalf("later forecast = %+v", g)
	}
}

func TestRunOutForecastCycleAverageWithoutRecentReadings(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	// 60% used in 40 hours of a 100-hour window: 100% arrives at hour 66.67.
	w := forecastWindow(60, 40*time.Hour, 60*time.Hour, 0, now)
	evalWindow(&w, now)
	f := w.RunOutForecast()
	if f == nil || f.Basis != "cycle-average" || f.Pace != "tight" || f.RunsOutAt == nil {
		t.Fatalf("forecast = %+v", f)
	}
	want := now.Add(time.Duration(40.0 / 60.0 * 40 * float64(time.Hour)))
	if d := f.RunsOutAt.Sub(want); d < -time.Second || d > time.Second {
		t.Fatalf("runsOutAt = %s, want %s", f.RunsOutAt, want)
	}
}

func TestRunOutForecastAbstains(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	onTrack := forecastWindow(20, 40*time.Hour, 60*time.Hour, 0, now)
	evalWindow(&onTrack, now)
	if f := onTrack.RunOutForecast(); f == nil || f.Pace == "tight" || f.Basis != "none" || f.RunsOutAt != nil {
		t.Fatalf("on track = %+v", f)
	}
	exhausted := forecastWindow(100, 40*time.Hour, 60*time.Hour, 0, now)
	evalWindow(&exhausted, now)
	if f := exhausted.RunOutForecast(); f == nil || f.Pace != "exhausted" || f.RunsOutAt != nil {
		t.Fatalf("exhausted = %+v", f)
	}
	passed := forecastWindow(60, 100*time.Hour, -time.Minute, time.Hour, now)
	evalWindow(&passed, now)
	if f := passed.RunOutForecast(); f != nil {
		t.Fatalf("passed reset = %+v", f)
	}
	if f := (Window{}).RunOutForecast(); f != nil {
		t.Fatalf("empty window = %+v", f)
	}
}

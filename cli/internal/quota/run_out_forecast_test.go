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

// CKP-ENG-26 (D277): a window whose reset time is unknown still forecasts a run-out from its
// recent burn rate, so the cockpit can say "out in ~40m". With no reset to beat, every run-out
// counts; one within RunsOutTight makes the window tight.
func TestRunOutForecastWithoutAResetTime(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	used := 80.0
	w := Window{Kind: "five_hour", UsedPercent: &used, ObservedAt: now}
	// 10 points in 20 minutes: the last 20 points go in 40 minutes.
	w.recent = []Sample{{At: now.Add(-20 * time.Minute), Used: 70}}
	evalWindow(&w, now)
	if w.RunsOutInMinutes == nil || *w.RunsOutInMinutes != 40 || w.Pace != "tight" {
		t.Fatalf("run-out %v, pace %s", deref(w.RunsOutInMinutes), w.Pace)
	}
	f := w.RunOutForecast()
	if f == nil || f.Basis != "recent-rate" || f.Pace != "tight" || f.RunsOutAt == nil || !f.RunsOutAt.Equal(now.Add(40*time.Minute)) {
		t.Fatalf("forecast = %+v", f)
	}
	// The history keeps the unknown cycle's readings, so the rate survives a re-read.
	older := Window{Kind: "five_hour", UsedPercent: ptr(70.0), ObservedAt: now.Add(-20 * time.Minute)}
	fresh := Window{Kind: "five_hour", UsedPercent: &used, ObservedAt: now}
	fresh = withHistory(fresh, older)
	evalWindow(&fresh, now)
	if fresh.RunsOutInMinutes == nil || *fresh.RunsOutInMinutes != 40 {
		t.Fatalf("after history merge: run-out %v", deref(fresh.RunsOutInMinutes))
	}
}

// Without a reset time a drop in the readings may be an unseen reset: the rate starts after it.
func TestRunOutWithoutAResetTimeIgnoresReadingsBeforeADrop(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	used := 11.0
	w := Window{Kind: "five_hour", UsedPercent: &used, ObservedAt: now}
	// 90 then 10 (a reset), then 11: only the last rise counts, and it is under recentMinRise.
	w.recent = []Sample{{At: now.Add(-40 * time.Minute), Used: 0}, {At: now.Add(-30 * time.Minute), Used: 90}, {At: now.Add(-15 * time.Minute), Used: 10}}
	evalWindow(&w, now)
	if w.RunsOutInMinutes != nil {
		t.Fatalf("run-out across a drop: %v", deref(w.RunsOutInMinutes))
	}
	if f := w.RunOutForecast(); f != nil {
		t.Fatalf("forecast = %+v", f)
	}
}

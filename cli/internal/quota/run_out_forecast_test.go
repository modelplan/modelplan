// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
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

// The history merge must not thin away the peak just before an unseen reset: merging readings one
// by one (some under two minutes apart), only the rise after the drop counts.
func TestRunOutWithoutAResetTimeDropSurvivesHistoryThinning(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	reads := []struct {
		at   time.Duration
		used float64
	}{{-40 * time.Minute, 0}, {-39 * time.Minute, 90}, {-38 * time.Minute, 60}, {0, 62}}
	var w Window
	for i, r := range reads {
		cur := Window{Kind: "five_hour", UsedPercent: ptr(r.used), ObservedAt: now.Add(r.at)}
		if i > 0 {
			cur = withHistory(cur, w)
		}
		w = cur
	}
	evalWindow(&w, now)
	if w.Pace == "tight" || (w.RunsOutInMinutes != nil && *w.RunsOutInMinutes <= RunsOutTight) {
		t.Fatalf("run-out across a lost drop: %v, pace %s", deref(w.RunsOutInMinutes), w.Pace)
	}
	if f := w.RunOutForecast(); f != nil {
		t.Fatalf("forecast across a lost drop: %+v", f)
	}
}

// nilResetRollout writes a Codex rollout whose five-hour meter carries no reset time.
func nilResetRollout(t *testing.T, name string, now time.Time, reads ...[2]float64) *rollout {
	t.Helper()
	var b []byte
	for _, r := range reads {
		ts := now.Add(time.Duration(r[0]) * time.Minute).Format(time.RFC3339Nano)
		b = fmt.Appendf(b, `{"timestamp":%q,"type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":%g,"window_minutes":300},"plan_type":"plus"}}}`+"\n", ts, r[1])
	}
	p := filepath.Join(t.TempDir(), name)
	if err := os.WriteFile(p, b, 0o600); err != nil {
		t.Fatal(err)
	}
	r := scanRollout(p, codexRolloutFence())
	if r == nil {
		t.Fatalf("%s: no rollout", name)
	}
	return r
}

// S1 (post-merge sampling 2026-11-18): rollout A sees 0, 90, then 60 (an unseen reset), then 62.
// Rollout B holds only the 0 from before that reset. Merging B must not bring the earlier cycle
// back: 2 points in 38 minutes leaves ~722 minutes, not the ~25 a 0-to-62 rise would forecast.
func TestRunOutWithoutAResetTimeKeepsItsCycleStartAcrossRolloutMerges(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	a := nilResetRollout(t, "rollout-a.jsonl", now, [2]float64{-40, 0}, [2]float64{-39, 90}, [2]float64{-38, 60}, [2]float64{0, 62})
	b := nilResetRollout(t, "rollout-b.jsonl", now, [2]float64{-40, 0})
	for name, rs := range map[string][]*rollout{"a,b": {a, b}, "b,a": {b, a}} {
		acct := mergeCodex(rs)
		if acct == nil || len(acct.Windows) != 1 {
			t.Fatalf("%s: merged = %+v", name, acct)
		}
		w := acct.Windows[0]
		if w.ResetsAt != nil || !w.cycleStart.Equal(now.Add(-38*time.Minute)) {
			t.Fatalf("%s: resetsAt %v, cycle start %s", name, w.ResetsAt, w.cycleStart)
		}
		evalWindow(&w, now)
		if w.RunsOutInMinutes == nil || *w.RunsOutInMinutes < 720 || *w.RunsOutInMinutes > 724 || w.Pace == "tight" {
			t.Fatalf("%s: run-out %v, pace %s; want ~722 and not tight", name, deref(w.RunsOutInMinutes), w.Pace)
		}
	}
}

// A carried cycle start rejects earlier readings in every later merge, in either direction.
func TestHistoryMergeHonoursTheInferredCycleStart(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	start := now.Add(-38 * time.Minute)
	at := func(m float64) time.Time { return now.Add(time.Duration(m * float64(time.Minute))) }
	cur := func() Window {
		return Window{Kind: "five_hour", UsedPercent: ptr(62), ObservedAt: now, cycleStart: start, recent: []Sample{{At: start, Used: 60}}}
	}
	for _, tc := range []struct {
		name      string
		other     Window
		newer     bool // other replaces cur
		wantStart time.Time
		wantAt    []time.Time
	}{
		{"pre-reset reading from an older thread", Window{Kind: "five_hour", UsedPercent: ptr(0), ObservedAt: at(-40)}, false, start, []time.Time{start}},
		{"pre-reset history behind an older reading", Window{Kind: "five_hour", UsedPercent: ptr(5), ObservedAt: at(-39.5), recent: []Sample{{At: at(-44), Used: 1}}}, false, start, []time.Time{start}},
		{"reading at the cycle start", Window{Kind: "five_hour", UsedPercent: ptr(60), ObservedAt: start}, false, start, []time.Time{start}},
		{"same-cycle reading after the start", Window{Kind: "five_hour", UsedPercent: ptr(61), ObservedAt: at(-20)}, false, start, []time.Time{start, at(-20)}},
		{"a later drop moves the start forward", Window{Kind: "five_hour", UsedPercent: ptr(95), ObservedAt: at(-20)}, false, now, nil},
		{"a newer reading keeps the carried start", Window{Kind: "five_hour", UsedPercent: ptr(64), ObservedAt: at(5), recent: []Sample{{At: at(-40), Used: 0}}}, true, start, []time.Time{start, now}},
		{"a reset time replaces the inferred start", Window{Kind: "five_hour", UsedPercent: ptr(64), ObservedAt: at(5), ResetsAt: ptrTime(at(200))}, true, time.Time{}, nil},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var got Window
			if tc.newer {
				got = withHistory(tc.other, cur())
			} else {
				got = withHistory(cur(), tc.other)
			}
			if !got.cycleStart.Equal(tc.wantStart) {
				t.Fatalf("cycle start = %s, want %s", got.cycleStart, tc.wantStart)
			}
			var ats []time.Time
			for _, s := range got.recent {
				ats = append(ats, s.At)
			}
			if fmt.Sprint(ats) != fmt.Sprint(tc.wantAt) {
				t.Fatalf("samples at %v, want %v", ats, tc.wantAt)
			}
		})
	}
}

// Even samples attached outside a merge are cut at the cycle start when the rate is measured.
func TestUnknownCycleBaseIgnoresSamplesBeforeTheCycleStart(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	w := Window{Kind: "five_hour", UsedPercent: ptr(62), ObservedAt: now, cycleStart: now.Add(-38 * time.Minute)}
	w.addSample(Sample{At: now.Add(-40 * time.Minute), Used: 0})
	w.addSample(Sample{At: now.Add(-38 * time.Minute), Used: 60})
	if b := unknownCycleBase(&w); !b.At.Equal(now.Add(-38*time.Minute)) || b.Used != 60 {
		t.Fatalf("base = %+v", b)
	}
}

// S2 (post-merge sampling 2026-11-18): a window with no reset time that is tight from its burn rate
// gives a boundary where that rate lapses, so cached verdicts expire, and one where it goes stale.
func TestBoundariesOfAWindowWithoutAResetTime(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	a := Account{Source: "codex", ObservedAt: now, Windows: []Window{{Kind: "five_hour", UsedPercent: ptr(80), ObservedAt: now, recent: []Sample{{At: now.Add(-20 * time.Minute), Used: 70}}}}}
	Evaluate(&a, now)
	if a.Headroom != "conserve" || a.Windows[0].Pace != "tight" {
		t.Fatalf("headroom %s, pace %s", a.Headroom, a.Windows[0].Pace)
	}
	has := func(ts []time.Time, want time.Time) bool {
		for _, x := range ts {
			if x.Equal(want) {
				return true
			}
		}
		return false
	}
	bs := Boundaries(&a)
	for _, want := range []time.Time{now.Add(recentFresh), now.Add(staleAfter)} {
		if !has(bs, want) {
			t.Fatalf("boundaries %v lack %s", bs, want)
		}
	}
	// Past the first one the verdict really has changed: the rate lapsed, the warning with it.
	Evaluate(&a, now.Add(recentFresh+time.Second))
	if a.Headroom == "conserve" || a.Windows[0].RunsOutInMinutes != nil {
		t.Fatalf("after the rate lapsed: headroom %s, run-out %v", a.Headroom, deref(a.Windows[0].RunsOutInMinutes))
	}
	// A window with no reading still gives nothing.
	empty := Account{Windows: []Window{{Kind: "five_hour", ObservedAt: now}}}
	if bs := Boundaries(&empty); len(bs) != 0 {
		t.Fatalf("no reading: boundaries %v", bs)
	}
}

func ptrTime(t time.Time) *time.Time { return &t }

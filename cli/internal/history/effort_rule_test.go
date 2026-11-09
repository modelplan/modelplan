// SPDX-License-Identifier: MIT
package history_test

import (
	"math"
	"os"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
)

// ladder5 gives the synthetic model min, low, medium (★), high, maximum with the
// given costs; star is the recommended effort.
func ladder5(d *digest.Digest, star string, costs ...float64) {
	names := []string{"min", "low", "medium", "high", "maximum"}
	var ef []digest.Effort
	for i, n := range names {
		c := costs[i]
		ef = append(ef, digest.Effort{Effort: n, Label: n, Cost: &c, CostBasisID: "synthetic-reference"})
	}
	d.Models[0].Efforts, d.Models[0].Recommended = ef, star
}

func histInput(at time.Time, effort string, uses ...float64) history.EffortInput {
	l := contracttest.EffortLedger(at, effort, false, uses...)
	return history.EffortInput{Source: "codex", Plan: "synthetic-plan", Cycles: l.Cycles, Now: at}
}

func pub(t *testing.T) *digest.Digest {
	t.Helper()
	d, err := contracttest.Public()
	if err != nil {
		t.Fatal(err)
	}
	return d
}

func TestEffortRuleThresholds(t *testing.T) {
	at := contracttest.Now
	// Costs chosen so the next rung up costs 10% more and the rung below 50% less.
	for _, tc := range []struct {
		name   string
		uses   []float64
		hit    int // cycles flagged as a limit hit beyond use>=100
		effort string
		want   string // "", "up", "down"
		reason string
		to     string
	}{
		{"up at average 60 and max 75", []float64{60, 60, 60}, 0, "medium", "up", history.ReasonHeadroomHistory, "high"},
		{"up max exactly 75", []float64{45, 45, 75}, 0, "medium", "up", history.ReasonHeadroomHistory, "high"},
		{"no up above average 60", []float64{60, 60, 61}, 0, "medium", "", history.ReasonMiddleRange, ""},
		{"no up above max 75", []float64{45, 45, 76}, 0, "medium", "", history.ReasonMiddleRange, ""},
		{"no up with a limit hit", []float64{50, 50, 100}, 1, "medium", "", history.ReasonMiddleRange, ""},
		{"middle range abstains", []float64{70, 75, 80}, 0, "medium", "", history.ReasonMiddleRange, ""},
		{"down at average 90", []float64{90, 90, 90}, 0, "medium", "down", history.ReasonTightHistory, "low"},
		{"no down at average 89.67", []float64{89, 90, 90}, 0, "medium", "", history.ReasonMiddleRange, ""},
		{"down on two limit hits", []float64{100, 60, 100}, 0, "medium", "down", history.ReasonTightHistory, "low"},
		{"no down on one limit hit", []float64{100, 60, 60}, 0, "medium", "", history.ReasonMiddleRange, ""},
		{"up projection too high", []float64{56, 56, 56}, 0, "medium", "up", history.ReasonHeadroomHistory, "high"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			d := pub(t)
			ladder5(d, "medium", .5, 1, 2, 2.2, 3)
			dec := history.DecideEffort(histInput(at, tc.effort, tc.uses...), d)
			if dec.Reason == "" {
				t.Fatal("no reason")
			}
			if tc.want == "" {
				if dec.Suggestion != nil || dec.Reason != tc.reason {
					t.Fatalf("got %+v %s", dec.Suggestion, dec.Reason)
				}
				return
			}
			v := dec.Suggestion
			if v == nil || v.Direction != tc.want || v.Reason != tc.reason || dec.Reason != tc.reason || v.ToEffort != tc.to || v.FromEffort != "medium" {
				t.Fatalf("got %+v %s", v, dec.Reason)
			}
		})
	}
}

func TestEffortRuleUpProjectionGate(t *testing.T) {
	at := contracttest.Now
	d := pub(t)
	// High costs 2x the star: average 45 projects to 90 > 85, so nothing; 40 -> 80 is fine.
	ladder5(d, "medium", .5, 1, 2, 4, 6)
	if dec := history.DecideEffort(histInput(at, "medium", 45, 45, 45), d); dec.Suggestion != nil || dec.Reason != history.ReasonProjectionOver {
		t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
	}
	if dec := history.DecideEffort(histInput(at, "medium", 40, 40, 40), d); dec.Suggestion == nil || dec.Suggestion.ToEffort != "high" {
		t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
	}
	// Never more than one rung above the star even with lots of room.
	if dec := history.DecideEffort(histInput(at, "medium", 5, 5, 5), d); dec.Suggestion == nil || dec.Suggestion.ToEffort != "high" {
		t.Fatalf("%+v", dec)
	}
}

func TestEffortRuleRungCapAndLadderEnds(t *testing.T) {
	at := contracttest.Now
	tight := histInput(at, "maximum", 95, 95, 95)
	t.Run("smallest drop that fits", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "high", .5, 1, 2, 3, 6)
		// max -> medium costs 1/3: 95 -> 32, fits at the first rung below the star.
		dec := history.DecideEffort(tight, d)
		if dec.Suggestion == nil || dec.Suggestion.ToEffort != "medium" {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
	t.Run("second rung when the first does not fit", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "high", .5, 1, 5.5, 5.9, 6)
		// medium costs 5.5/6 -> 87% > 85; low costs 1/6 -> fits.
		dec := history.DecideEffort(tight, d)
		if dec.Suggestion == nil || dec.Suggestion.ToEffort != "low" {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
	t.Run("capped at two rungs", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "maximum", 1.0, 5.8, 5.9, 5.95, 6)
		// Nothing fits, the star is the top rung: still at most two rungs down.
		dec := history.DecideEffort(tight, d)
		if dec.Suggestion == nil || dec.Suggestion.ToEffort != "medium" {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
	t.Run("star at the bottom: no down", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "min", .5, 1, 2, 3, 6)
		if dec := history.DecideEffort(tight, d); dec.Suggestion != nil || dec.Reason != history.ReasonLadderEnd {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
	t.Run("star one above the bottom drops one", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "low", .5, 1, 2, 3, 6)
		dec := history.DecideEffort(tight, d)
		if dec.Suggestion == nil || dec.Suggestion.ToEffort != "min" {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
	t.Run("star at the top: no up", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "maximum", .5, 1, 2, 3, 6)
		if dec := history.DecideEffort(histInput(at, "maximum", 10, 10, 10), d); dec.Suggestion != nil || dec.Reason != history.ReasonLadderEnd {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
	t.Run("no star published", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "none", .5, 1, 2, 3, 6)
		if dec := history.DecideEffort(histInput(at, "medium", 10, 10, 10), d); dec.Suggestion != nil || dec.Reason != history.ReasonNoStar {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
}

func TestEffortRuleStarIsTheBaseNotTheCurrentEffort(t *testing.T) {
	at := contracttest.Now
	// History of any effort gives the same target.
	for _, past := range []string{"min", "low", "medium", "high"} {
		d := pub(t)
		ladder5(d, "medium", .5, 1, 2, 2.2, 3)
		dec := history.DecideEffort(histInput(at, past, 15, 15, 15), d)
		if dec.Suggestion == nil || dec.Suggestion.ToEffort != "high" || dec.Suggestion.FromEffort != "medium" {
			t.Fatalf("%s: %+v %s", past, dec.Suggestion, dec.Reason)
		}
	}
	// A live shortfall gives the same target whatever the current effort, until the
	// user is already at or below it.
	live := &history.Live{Used: 70, Elapsed: 40, ResetsAt: at.Add(61 * time.Hour), RunsOutIn: ptr(3600)}
	for cur, want := range map[string]string{"maximum": "low", "high": "low", "medium": "low", "low": "min", "min": ""} {
		d := pub(t)
		ladder5(d, "medium", .5, 1, 2, 2.2, 3)
		in := history.EffortInput{Source: "codex", Now: at, Live: live, Current: &history.Share{Model: "native-z", Effort: cur}}
		dec := history.DecideEffort(in, d)
		if want == "" {
			if dec.Suggestion != nil || dec.Reason != history.ReasonAlreadyThere {
				t.Fatalf("%s: %+v %s", cur, dec.Suggestion, dec.Reason)
			}
			continue
		}
		if dec.Suggestion == nil || dec.Suggestion.ToEffort != want {
			t.Fatalf("%s: %+v %s", cur, dec.Suggestion, dec.Reason)
		}
	}
	// Never a suggestion to a rung the user already sits above for "up".
	d := pub(t)
	ladder5(d, "medium", .5, 1, 2, 2.2, 3)
	in := histInput(at, "high", 30, 30, 30)
	in.Current = &history.Share{Model: "native-z", Effort: "maximum"}
	if dec := history.DecideEffort(in, d); dec.Suggestion != nil || dec.Reason != history.ReasonAlreadyThere {
		t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
	}
}

func ptr(i int) *int { return &i }

func TestEffortRuleForecast(t *testing.T) {
	at := contracttest.Now
	cases := []struct {
		name   string
		live   *history.Live
		want   bool
		reason string
	}{
		{"runs out before reset", &history.Live{Used: 60, Elapsed: 40, ResetsAt: at.Add(100 * time.Hour), RunsOutIn: ptr(48 * 60)}, true, history.ReasonLiveRunout},
		{"lasts to reset", &history.Live{Used: 60, Elapsed: 40, ResetsAt: at.Add(100 * time.Hour)}, false, history.ReasonLiveLasts},
		{"too little elapsed time", &history.Live{Used: 25, Elapsed: 5, ResetsAt: at.Add(150 * time.Hour), RunsOutIn: ptr(48 * 60)}, false, history.ReasonTooEarly},
		{"used not ten points over elapsed", &history.Live{Used: 49, Elapsed: 40, ResetsAt: at.Add(100 * time.Hour), RunsOutIn: ptr(48 * 60)}, false, history.ReasonLiveLasts},
		{"exactly ten points over", &history.Live{Used: 50, Elapsed: 40, ResetsAt: at.Add(100 * time.Hour), RunsOutIn: ptr(48 * 60)}, true, history.ReasonLiveRunout},
		{"reset already passed", &history.Live{Used: 60, Elapsed: 40, ResetsAt: at.Add(-time.Minute), RunsOutIn: ptr(48 * 60)}, false, history.ReasonLiveLasts},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			d := pub(t)
			ladder5(d, "medium", .5, 1, 2, 2.2, 3)
			in := history.EffortInput{Source: "codex", Now: at, Live: tc.live, Current: &history.Share{Model: "native-z", Effort: "high"}}
			dec := history.DecideEffort(in, d)
			if (dec.Suggestion != nil) != tc.want || dec.Reason != tc.reason {
				t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
			}
			if v := dec.Suggestion; v != nil && (v.Direction != "down" || v.Basis != "live" || v.BasisHours != 24 || v.Cycles != 0) {
				t.Fatalf("%+v", v)
			}
		})
	}
	// The forecast never triggers "up", and needs no finished cycles for "down".
	d := pub(t)
	ladder5(d, "medium", .5, 1, 2, 2.2, 3)
	in := history.EffortInput{Source: "codex", Now: at, Live: &history.Live{Used: 5, Elapsed: 50, ResetsAt: at.Add(80 * time.Hour)}, Current: &history.Share{Model: "native-z", Effort: "low"}}
	if dec := history.DecideEffort(in, d); dec.Suggestion != nil {
		t.Fatalf("forecast triggered up: %+v", dec.Suggestion)
	}
}

func TestEffortRuleResetGating(t *testing.T) {
	at := contracttest.Now
	scheduled := at.Add(100 * time.Hour)
	live := func() *history.Live {
		return &history.Live{Used: 60, Elapsed: 40, ResetsAt: scheduled, RunsOutIn: ptr(48 * 60)}
	}
	run := func(announced ...time.Time) history.EffortDecision {
		d := pub(t)
		ladder5(d, "medium", .5, 1, 2, 2.2, 3)
		return history.DecideEffort(history.EffortInput{Source: "codex", Now: at, Live: live(), Announced: announced,
			Current: &history.Share{Model: "native-z", Effort: "high"}}, d)
	}
	t.Run("scheduled reset after the run-out: down", func(t *testing.T) {
		if dec := run(); dec.Suggestion == nil || dec.Reason != history.ReasonLiveRunout {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
	t.Run("announced reset before the run-out: silent", func(t *testing.T) {
		if dec := run(at.Add(20 * time.Hour)); dec.Suggestion != nil || dec.Reason != history.ReasonResetBeforeRun {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
	t.Run("announced reset far away: normal down", func(t *testing.T) {
		// It lands after the scheduled reset, so only the scheduled one counts.
		dec := run(at.Add(200 * time.Hour))
		if dec.Suggestion == nil || !dec.Suggestion.ExpiresAt.Equal(scheduled) {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
		// And one between the run-out and the scheduled reset is later than the run-out.
		if dec := run(at.Add(60 * time.Hour)); dec.Suggestion == nil && dec.Reason != history.ReasonResetBeforeRun {
			t.Fatalf("%s", dec.Reason)
		}
	})
	t.Run("withdrawn announcement is not passed in: scheduled reset only", func(t *testing.T) {
		// The caller drops withdrawn and unconfirmed records (advise.AnnouncedResets);
		// with none left the rule behaves as without an announcement.
		if dec := run(nil...); dec.Suggestion == nil {
			t.Fatalf("%s", dec.Reason)
		}
	})
	t.Run("a past announced time is ignored", func(t *testing.T) {
		if dec := run(at.Add(-time.Hour)); dec.Suggestion == nil {
			t.Fatalf("%s", dec.Reason)
		}
	})
	t.Run("reset within an hour: silent", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "medium", .5, 1, 2, 2.2, 3)
		l := &history.Live{Used: 60, Elapsed: 40, ResetsAt: at.Add(50 * time.Minute), RunsOutIn: ptr(30)}
		dec := history.DecideEffort(history.EffortInput{Source: "codex", Now: at, Live: l, Current: &history.Share{Model: "native-z", Effort: "high"}}, d)
		if dec.Suggestion != nil || dec.Reason != history.ReasonResetImminent {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
		// An announced reset within the hour is as good as a scheduled one.
		if dec := run(at.Add(30 * time.Minute)); dec.Suggestion != nil || dec.Reason != history.ReasonResetImminent {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
	t.Run("history down is gated by an imminent reset too", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "medium", .5, 1, 2, 2.2, 3)
		in := histInput(at, "medium", 95, 95, 95)
		in.Announced = []time.Time{at.Add(20 * time.Minute)}
		if dec := history.DecideEffort(in, d); dec.Suggestion != nil || dec.Reason != history.ReasonResetImminent {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
	t.Run("near a reset with a lot left: up, no cycles needed", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "medium", .5, 1, 2, 2.2, 3)
		in := history.EffortInput{Source: "claude-code", Now: at, Surplus: true,
			Live: &history.Live{Used: 20, Elapsed: 90, ResetsAt: at.Add(10 * time.Hour)}, Current: &history.Share{Model: "native-z", Effort: "medium"}}
		dec := history.DecideEffort(in, d)
		v := dec.Suggestion
		if v == nil || v.Direction != "up" || v.Reason != history.ReasonResetUnused || v.ToEffort != "high" || v.Basis != "reset" || !v.ExpiresAt.Equal(in.Live.ResetsAt) {
			t.Fatalf("%+v %s", v, dec.Reason)
		}
		// Not when the user is already at or above the target.
		in.Current.Effort = "high"
		if dec := history.DecideEffort(in, d); dec.Suggestion != nil {
			t.Fatalf("%+v", dec.Suggestion)
		}
	})
	t.Run("a live shortfall beats the surplus verdict", func(t *testing.T) {
		d := pub(t)
		ladder5(d, "medium", .5, 1, 2, 2.2, 3)
		in := history.EffortInput{Source: "claude-code", Now: at, Surplus: true, Live: live(), Current: &history.Share{Model: "native-z", Effort: "medium"}}
		if dec := history.DecideEffort(in, d); dec.Suggestion == nil || dec.Suggestion.Direction != "down" {
			t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
		}
	})
}

func TestEffortRuleGoldenFixtures(t *testing.T) {
	at := contracttest.Now
	for _, tc := range []struct {
		name   string
		in     func() history.EffortInput
		edit   func(*history.EffortInput)
		want   string
		reason string
	}{
		{name: "three weeks idle", in: func() history.EffortInput { return histInput(at, "medium", 20, 25, 30) }, want: "up", reason: history.ReasonHeadroomHistory},
		{name: "three weeks tight", in: func() history.EffortInput { return histInput(at, "high", 95, 100, 98) }, want: "down", reason: history.ReasonTightHistory},
		{name: "mixed workload", in: func() history.EffortInput {
			in := histInput(at, "medium", 20, 25, 30)
			for i := range in.Cycles {
				p := in.Cycles[i].LastUsed / 2
				in.Cycles[i].Spent = []history.Share{{Model: "native-z", Effort: "medium", Points: p}, {Model: "native-z", Effort: "high", Points: p}}
			}
			return in
		}, reason: history.ReasonMixedWorkload},
		{name: "gap in the weeks", in: func() history.EffortInput {
			in := histInput(at, "medium", 20, 25, 30)
			in.Cycles[2].ResetsAt = in.Cycles[2].ResetsAt.Add(-14 * 24 * time.Hour)
			return in
		}, reason: history.ReasonCoverageGap},
		{name: "two weeks only", in: func() history.EffortInput { return histInput(at, "medium", 20, 25) }, reason: history.ReasonFewCycles},
		{name: "no data", in: func() history.EffortInput { return history.EffortInput{Source: "codex", Now: at} }, reason: history.ReasonNoData},
		{name: "outside the first day after a reset", in: func() history.EffortInput { return histInput(at.Add(3*24*time.Hour), "medium", 20, 25, 30) }, reason: history.ReasonOutsideWindow},
	} {
		t.Run(tc.name, func(t *testing.T) {
			d := pub(t)
			ladder5(d, "medium", .5, 1, 2, 2.2, 3)
			in := tc.in()
			if tc.name == "outside the first day after a reset" {
				in.Now = at.Add(3 * 24 * time.Hour)
				in.Cycles = histInput(at, "medium", 20, 25, 30).Cycles
			}
			dec := history.DecideEffort(in, d)
			if dec.Reason != tc.reason || (dec.Suggestion != nil) != (tc.want != "") || (tc.want != "" && dec.Suggestion.Direction != tc.want) {
				t.Fatalf("%+v %s", dec.Suggestion, dec.Reason)
			}
			for _, v := range []*history.EffortSuggestion{dec.Suggestion} {
				if v != nil && (v.Reason == "" || v.Basis == "" || v.ModelID != "synthetic-z" || math.IsNaN(v.CostRatio)) {
					t.Fatalf("incomplete: %+v", v)
				}
			}
		})
	}
}

func TestEffortRuleSameModelOnly(t *testing.T) {
	at := contracttest.Now
	d := pub(t)
	ladder5(d, "medium", .5, 1, 2, 2.2, 3)
	// History of one model, current default on another: silent, never a model switch.
	in := histInput(at, "medium", 20, 20, 20)
	in.Current = &history.Share{Model: "native-one", Effort: "native"}
	if dec := history.DecideEffort(in, d); dec.Suggestion != nil {
		t.Fatalf("%+v", dec.Suggestion)
	}
	// A suggestion never names a model other than the one in use, and never Fast.
	in = histInput(at, "medium", 20, 20, 20)
	if v := history.DecideEffort(in, d).Suggestion; v == nil || v.ModelID != "synthetic-z" {
		t.Fatalf("%+v", v)
	}
}

func TestLiveSuggestionClaim(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "")
	at := contracttest.Now
	d := pub(t)
	ladder5(d, "medium", .5, 1, 2, 2.2, 3)
	in := history.EffortInput{Source: "codex", Now: at, Live: &history.Live{Used: 60, Elapsed: 40, ResetsAt: at.Add(100 * time.Hour), RunsOutIn: ptr(2880)},
		Current: &history.Share{Model: "native-z", Effort: "high"}}
	v := history.DecideEffort(in, d).Suggestion
	cache := t.TempDir()
	if history.ClaimEffortSuggestion(cache, v, at) == nil {
		t.Fatal("live suggestion not claimed (default on)")
	}
	if history.ClaimEffortSuggestion(cache, v, at.Add(time.Hour)) != nil {
		t.Fatal("second notice inside the week")
	}
	// Expires at the reset it was gated on.
	if history.ClaimEffortSuggestion(t.TempDir(), v, v.ExpiresAt) != nil {
		t.Fatal("claimed after expiry")
	}
	// Dismissal persists.
	cache = t.TempDir()
	if err := history.SetEffortSuggestion(cache, "dismiss", at); err != nil {
		t.Fatal(err)
	}
	if history.ClaimEffortSuggestion(cache, v, at.Add(time.Hour)) != nil {
		t.Fatal("dismissed suggestion claimed")
	}
}

func TestEffortSuggestionDefaultOnAndSettingsToggle(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "")
	d := pub(t)
	at := contracttest.Now
	cache := t.TempDir()
	writeLedger(t, cache, contracttest.EffortLedger(at, "medium", false, 40, 45, 50))
	if !history.EffortSuggestionEnabled(cache) {
		t.Fatal("not on by default")
	}
	if history.ReadEffortSuggestion(cache, d, at).Suggestion == nil || history.NotifyEffortSuggestion(cache, d, at) == nil {
		t.Fatal("default-on suggestion missing")
	}
	// Old state files from the previous opt-in era still work.
	if err := os.WriteFile(history.EffortSuggestionPath(cache), []byte(`{"schemaVersion":1,"disabled":false}`), 0600); err != nil {
		t.Fatal(err)
	}
	if !history.EffortSuggestionEnabled(cache) {
		t.Fatal("old state turned it off")
	}
	if err := history.SetEffortSuggestion(cache, "off", at); err != nil {
		t.Fatal(err)
	}
	if history.EffortSuggestionEnabled(cache) || history.ReadEffortSuggestion(cache, d, at).Suggestion != nil || history.NotifyEffortSuggestion(cache, d, at.Add(30*24*time.Hour)) != nil {
		t.Fatal("Settings off ignored")
	}
	if err := history.SetEffortSuggestion(cache, "on", at); err != nil {
		t.Fatal(err)
	}
	if !history.EffortSuggestionEnabled(cache) {
		t.Fatal("Settings on ignored")
	}
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "off")
	if history.EffortSuggestionEnabled(cache) {
		t.Fatal("env off ignored")
	}
}

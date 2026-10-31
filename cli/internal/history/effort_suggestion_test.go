// SPDX-License-Identifier: MIT
package history_test

import (
	"encoding/json"
	"math"
	"os"
	"path/filepath"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/history"
)

func TestSuggestEffort(t *testing.T) {
	at := contracttest.Now
	for _, tc := range []struct {
		name, effort string
		uses         []float64
		edit         func(*history.Ledger, *digest.Digest)
		direction    string
		ratio        float64
	}{
		{name: "underused", effort: "medium", uses: []float64{40, 45, 50}, direction: "up", ratio: 1.5},
		{name: "hits", effort: "high", uses: []float64{100, 70, 100}, direction: "down", ratio: 2.0 / 3},
		{name: "tight", effort: "high", uses: []float64{90, 92, 91}, direction: "down", ratio: 2.0 / 3},
		{name: "zero", effort: "medium"},
		{name: "one", effort: "medium", uses: []float64{45}},
		{name: "short", effort: "medium", uses: []float64{40, 45}},
		{name: "mixed", effort: "medium", uses: []float64{40, 95, 70}},
		{name: "no ladder", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) { d.Models[0].Efforts = d.Models[0].Efforts[:1] }},
		{name: "different basis", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) { d.Models[0].Efforts[1].CostBasisID = "other" }},
		{name: "unknown cost", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) { d.Models[0].Efforts[1].Cost = nil }},
		{name: "unattributed", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) {
			l.Cycles[0].FirstUsed = 20
			l.Cycles[0].Spent[0].Points = 20
		}},
		{name: "boundary 40 percent unattributed", effort: "medium", uses: []float64{50, 50, 50}, direction: "up", ratio: 1.5, edit: func(l *history.Ledger, d *digest.Digest) {
			for i := range l.Cycles {
				l.Cycles[i].FirstUsed = 20
				l.Cycles[i].Spent[0].Points = 30
			}
		}},
		{name: "tiny observed", effort: "medium", uses: []float64{2, 2, 2}},
		{name: "missing effort", effort: "", uses: []float64{40, 45, 50}},
		{name: "Claude status-line has no plan label", effort: "medium", uses: []float64{40, 45, 50}, direction: "up", ratio: 1.5, edit: func(l *history.Ledger, d *digest.Digest) {
			for i := range l.Cycles {
				l.Cycles[i].Source, l.Cycles[i].Plan = "claude-code", ""
			}
		}},
		{name: "different plan", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) { l.Cycles[0].Plan = "other" }},
		{name: "different source", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) { l.Cycles[0].Source = "claude-code" }},
		{name: "different pool", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) { l.Cycles[0].Limit = "other" }},
		{name: "unfinished", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) { l.Cycles[0].ResetsAt = at.Add(time.Hour) }},
		{name: "stale", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) {
			for i := range l.Cycles {
				l.Cycles[i].ResetsAt = l.Cycles[i].ResetsAt.Add(-7 * 24 * time.Hour)
			}
		}},
		{name: "nonfinite", effort: "medium", uses: []float64{40, 45, math.NaN()}},
		{name: "fast", effort: "medium", uses: []float64{40, 45, 50}, direction: "up", ratio: 1.5, edit: func(l *history.Ledger, d *digest.Digest) {
			for i := range l.Cycles {
				l.Cycles[i].Spent[0].Fast = true
			}
		}},
		{name: "unknown fast", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) {
			for i := range l.Cycles {
				l.Cycles[i].Spent[0].Fast = true
			}
			d.Speed = nil
		}},
		{name: "credits fast", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) {
			for i := range l.Cycles {
				l.Cycles[i].Spent[0].Fast = true
			}
			d.Speed[0].Billing[0].BillsTo = "usage-credits"
		}},
		{name: "conditional alias", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) {
			d.Models[0].HarnessEvidence = &digest.HarnessEvidence{RequiredEndpoints: map[string]string{"codex": "https://example.test"}}
		}},
		{name: "mixed configurations", effort: "medium", uses: []float64{40, 45, 50}, edit: func(l *history.Ledger, d *digest.Digest) {
			for i := range l.Cycles {
				p := l.Cycles[i].LastUsed / 2
				l.Cycles[i].Spent = []history.Share{{Model: "native-z", Effort: "medium", Points: p}, {Model: "native-z", Effort: "high", Points: p}}
			}
		}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			d, err := contracttest.Public()
			if err != nil {
				t.Fatal(err)
			}
			l := contracttest.EffortLedger(at, tc.effort, false, tc.uses...)
			if tc.edit != nil {
				tc.edit(&l, d)
			}
			v := history.SuggestEffort(l, d, at)
			if tc.direction == "" {
				if v != nil {
					t.Fatalf("unexpected suggestion: %+v", v)
				}
				return
			}
			if v == nil || v.Direction != tc.direction || math.Abs(v.CostRatio-tc.ratio) > 1e-10 || v.Cycles != 3 || v.PublicationID != d.PublicationID {
				t.Fatalf("suggestion: %+v", v)
			}
		})
	}
}

func writeLedger(t *testing.T, cache string, l history.Ledger) {
	t.Helper()
	b, err := json.Marshal(l)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.MkdirAll(filepath.Dir(history.Path(cache)), 0700); err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(history.Path(cache), b, 0600); err != nil {
		t.Fatal(err)
	}
}

func TestEffortSuggestionLocalControls(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "on")
	cache, at := t.TempDir(), contracttest.Now
	d, _ := contracttest.Public()
	writeLedger(t, cache, contracttest.EffortLedger(at, "medium", false, 40, 45, 50))
	first := history.ReadEffortSuggestion(cache, d, at)
	if first.Suggestion == nil {
		t.Fatal("no initial suggestion")
	}
	if _, err := os.Stat(history.EffortSuggestionPath(cache)); !os.IsNotExist(err) {
		t.Fatal("read-only view wrote state")
	}
	var wg sync.WaitGroup
	var count atomic.Int32
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if history.NotifyEffortSuggestion(cache, d, at) != nil {
				count.Add(1)
			}
		}()
	}
	wg.Wait()
	if count.Load() != 1 {
		t.Fatalf("concurrent claims = %d", count.Load())
	}
	if history.NotifyEffortSuggestion(cache, d, at.Add(time.Minute)) != nil {
		t.Fatal("repeated inside week")
	}
	next := at.Add(7 * 24 * time.Hour)
	writeLedger(t, cache, contracttest.EffortLedger(next, "medium", false, 40, 45, 50))
	if history.NotifyEffortSuggestion(cache, d, next.Add(-time.Second)) != nil {
		t.Fatal("new reset bypassed rolling seven-day throttle")
	}
	if history.NotifyEffortSuggestion(cache, d, next) == nil {
		t.Fatal("not shown next week")
	}
	if err := history.SetEffortSuggestion(cache, "dismiss", next); err != nil {
		t.Fatal(err)
	}
	dismissed := history.ReadEffortSuggestion(cache, d, next)
	if dismissed.Suggestion != nil || dismissed.Revision == first.Revision {
		t.Fatal("dismiss ignored")
	}
	if err := history.SetEffortSuggestion(cache, "off", next); err != nil {
		t.Fatal(err)
	}
	writeLedger(t, cache, contracttest.EffortLedger(next.Add(14*24*time.Hour), "medium", false, 40, 45, 50))
	if history.ReadEffortSuggestion(cache, d, next.Add(14*24*time.Hour)).Suggestion != nil {
		t.Fatal("off ignored")
	}
	if err := history.SetEffortSuggestion(cache, "on", next); err != nil {
		t.Fatal(err)
	}
	if history.ReadEffortSuggestion(cache, d, next.Add(14*24*time.Hour)).Suggestion == nil {
		t.Fatal("on ignored")
	}
	info, err := os.Stat(history.EffortSuggestionPath(cache))
	if err != nil || info.Mode().Perm() != 0600 {
		t.Fatal("state permissions", err)
	}
}

func TestEffortSuggestionSwitchesAndClock(t *testing.T) {
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "on")
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, at := t.TempDir(), contracttest.Now
	d, _ := contracttest.Public()
	writeLedger(t, cache, contracttest.EffortLedger(at, "medium", false, 40, 45, 50))
	for _, key := range []string{"MODELPLAN_HISTORY", "MODELPLAN_EFFORT_SUGGESTION"} {
		t.Run(key, func(t *testing.T) {
			t.Setenv(key, "off")
			if history.ReadEffortSuggestion(cache, d, at).Suggestion != nil || history.NotifyEffortSuggestion(cache, d, at) != nil {
				t.Fatal("off ignored")
			}
		})
	}
	a := history.ReadEffortSuggestion(cache, d, at)
	b := history.ReadEffortSuggestion(cache, d, at.Add(7*24*time.Hour))
	if a.Suggestion == nil || b.Suggestion != nil || a.Revision != b.Revision {
		t.Fatal("clock changed observed revision or expiry ignored")
	}
	if err := os.WriteFile(history.EffortSuggestionPath(cache), []byte("corrupt"), 0600); err != nil {
		t.Fatal(err)
	}
	if history.NotifyEffortSuggestion(cache, d, at) != nil {
		t.Fatal("corrupt state must abstain")
	}
}

func TestEffortDismissalExpiresAndReadDoesNotConsumeNotice(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "on")
	cache, at := t.TempDir(), contracttest.Now
	d, _ := contracttest.Public()
	writeLedger(t, cache, contracttest.EffortLedger(at, "medium", false, 40, 45, 50))
	if err := history.SetEffortSuggestion(cache, "dismiss", at); err != nil {
		t.Fatal(err)
	}
	if history.ReadEffortSuggestion(cache, d, at.Add(6*24*time.Hour)).Suggestion != nil {
		t.Fatal("dismiss expired early")
	}
	next := at.Add(7 * 24 * time.Hour)
	writeLedger(t, cache, contracttest.EffortLedger(next, "medium", false, 40, 45, 50))
	if history.ReadEffortSuggestion(cache, d, next).Suggestion == nil {
		t.Fatal("dismiss did not expire")
	}
	if history.NotifyEffortSuggestion(cache, d, next) == nil {
		t.Fatal("manual view consumed notice")
	}
}

func TestSuggestDefaultEffortUsesCurrentDefault(t *testing.T) {
	at := contracttest.Now
	for _, tc := range []struct {
		name, past, current, from, to string
		uses                          []float64
	}{
		{"up from current", "medium", "high", "high", "maximum", []float64{40, 45, 50}},
		{"down from current", "maximum", "high", "high", "medium", []float64{90, 92, 91}},
		{"already highest", "medium", "maximum", "", "", []float64{40, 45, 50}},
		{"already lowest", "high", "medium", "", "", []float64{90, 92, 91}},
		{"unknown", "medium", "", "", "", []float64{40, 45, 50}},
	} {
		t.Run(tc.name, func(t *testing.T) {
			d, _ := contracttest.Public()
			cost := 6.0
			d.Models[0].Efforts = append(d.Models[0].Efforts, digest.Effort{Effort: "maximum", Label: "Max", Cost: &cost, CostBasisID: "synthetic-reference"})
			l := contracttest.EffortLedger(at, tc.past, false, tc.uses...)
			before, _ := json.Marshal(l)
			v := history.SuggestDefaultEffort(l.Cycles, history.Share{Model: "native-z", Effort: tc.current}, d, at)
			after, _ := json.Marshal(l)
			if string(before) != string(after) {
				t.Fatal("pure calculation mutated input")
			}
			if tc.from == "" {
				if v != nil {
					t.Fatalf("unexpected suggestion: %+v", v)
				}
				return
			}
			if v == nil || v.FromEffort != tc.from || v.ToEffort != tc.to || v.Fast {
				t.Fatalf("wrong current default or changed Fast: %+v", v)
			}
			want := 2.0
			if tc.to == "medium" {
				want = 2.0 / 3
			}
			if math.Abs(v.CostRatio-want) > 1e-10 {
				t.Fatalf("ratio = %v, want %v", v.CostRatio, want)
			}
		})
	}
}

func TestSuggestDefaultEffortRequiresOneKnownPool(t *testing.T) {
	at := contracttest.Now
	for _, tc := range []struct {
		name string
		edit func(*history.Ledger, *history.Share)
	}{
		{"source", func(l *history.Ledger, c *history.Share) { l.Cycles[0].Source = "claude-code" }},
		{"plan", func(l *history.Ledger, c *history.Share) { l.Cycles[0].Plan = "other" }},
		{"pool", func(l *history.Ledger, c *history.Share) { l.Cycles[0].Limit = "other" }},
		{"unfinished", func(l *history.Ledger, c *history.Share) { l.Cycles[0].ResetsAt = at.Add(time.Hour) }},
		{"model", func(l *history.Ledger, c *history.Share) { c.Model = "native-one" }},
		{"speed changed", func(l *history.Ledger, c *history.Share) { c.Fast = true }},
	} {
		t.Run(tc.name, func(t *testing.T) {
			d, _ := contracttest.Public()
			l := contracttest.EffortLedger(at, "medium", false, 40, 45, 50)
			current := history.Share{Model: "native-z", Effort: "medium"}
			tc.edit(&l, &current)
			if v := history.SuggestDefaultEffort(l.Cycles, current, d, at); v != nil {
				t.Fatalf("unexpected suggestion: %+v", v)
			}
		})
	}
}

func TestEffortSuggestionRolloutRequiresExplicitOptIn(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "")
	d, _ := contracttest.Public()
	// Neither the earliest go-live date nor a later date enables the default.
	for _, day := range []string{"2026-10-30", "2026-11-07", "2027-01-01"} {
		t.Run(day, func(t *testing.T) {
			at, err := time.Parse("2006-01-02", day)
			if err != nil {
				t.Fatal(err)
			}
			cache := t.TempDir()
			writeLedger(t, cache, contracttest.EffortLedger(at, "medium", false, 40, 45, 50))
			// Old state from the previously enabled version is not an opt-in.
			if err := os.WriteFile(history.EffortSuggestionPath(cache), []byte(`{"schemaVersion":1,"disabled":false}`), 0600); err != nil {
				t.Fatal(err)
			}
			before, _ := os.ReadFile(history.EffortSuggestionPath(cache))
			v := history.SuggestEffort(history.Load(cache), d, at)
			if v == nil {
				t.Fatal("synthetic history must be eligible")
			}
			if history.ReadEffortSuggestion(cache, d, at).Suggestion != nil || history.NotifyEffortSuggestion(cache, d, at) != nil || history.ClaimEffortSuggestion(cache, v, at) != nil {
				t.Fatal("default rollout gate ignored")
			}
			after, _ := os.ReadFile(history.EffortSuggestionPath(cache))
			if string(before) != string(after) {
				t.Fatal("disabled default consumed notice")
			}
			if err := history.SetEffortSuggestion(cache, "on", at); err != nil {
				t.Fatal(err)
			}
			if history.NotifyEffortSuggestion(cache, d, at) == nil {
				t.Fatal("explicit local opt-in ignored")
			}
		})
	}
}

func TestEffortSuggestionOnlyRightAfterReset(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "on")
	d, _ := contracttest.Public()
	at := contracttest.Now
	l := contracttest.EffortLedger(at, "medium", false, 40, 45, 50)
	reset := l.Cycles[0].ResetsAt
	for _, tc := range []struct {
		name   string
		offset time.Duration
		want   bool
	}{
		{"before reset", -time.Nanosecond, false},
		{"reset", 0, true},
		{"first day", 24*time.Hour - time.Nanosecond, true},
		{"day boundary", 24 * time.Hour, false},
		{"midweek", 3 * 24 * time.Hour, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			cache := t.TempDir()
			writeLedger(t, cache, l)
			now := reset.Add(tc.offset)
			v := history.NotifyEffortSuggestion(cache, d, now)
			if (v != nil) != tc.want {
				t.Fatalf("notice at %s = %+v", now, v)
			}
			if v != nil && !v.ExpiresAt.Equal(reset.Add(24*time.Hour)) {
				t.Fatal("incorrect expiry")
			}
			if !tc.want {
				if _, err := os.Stat(history.EffortSuggestionPath(cache)); !os.IsNotExist(err) {
					t.Fatal("ineligible time consumed notice", err)
				}
			}
		})
	}
	// A precomputed suggestion cannot retain an old full-week expiry and bypass
	// the reset window at the claim seam.
	v := history.SuggestEffort(l, d, at)
	v.ExpiresAt = reset.Add(7 * 24 * time.Hour)
	if history.ClaimEffortSuggestion(t.TempDir(), v, reset.Add(24*time.Hour)) != nil {
		t.Fatal("late claim bypassed reset window")
	}
}

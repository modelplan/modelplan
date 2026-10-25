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
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "")
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
	if history.NotifyEffortSuggestion(cache, d, at.Add(24*time.Hour)) != nil {
		t.Fatal("repeated inside week")
	}
	next := at.Add(7 * 24 * time.Hour)
	writeLedger(t, cache, contracttest.EffortLedger(next, "medium", false, 40, 45, 50))
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
	t.Setenv("MODELPLAN_EFFORT_SUGGESTION", "")
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

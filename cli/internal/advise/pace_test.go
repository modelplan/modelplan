// SPDX-License-Identifier: MIT
package advise_test

import (
	"encoding/json"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/advise"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
	"testing"
	"time"
)

func paceAccount(t *testing.T, at time.Time, used, before float64) quota.Account {
	t.Helper()
	cache := t.TempDir()
	reset := at.Add(time.Duration(float64(7*24*time.Hour) * .6)).Unix() // 40% elapsed
	var latest quota.StatuslineInput
	for _, reading := range []struct {
		at   time.Time
		used float64
	}{{at.Add(-24 * time.Hour), before}, {at, used}} {
		var in quota.StatuslineInput
		raw := fmt.Sprintf(`{"model":{"id":"synthetic-model"},"effort":{"level":"medium"},"rate_limits":{"seven_day":{"used_percentage":%g,"resets_at":%d}}}`, reading.used, reset)
		if err := json.Unmarshal([]byte(raw), &in); err != nil {
			t.Fatal(err)
		}
		if err := quota.RecordClaudeCode(cache, in, reading.at); err != nil {
			t.Fatal(err)
		}
		latest = in
	}
	a := latest.Account(at)
	quota.AttachRecent(cache, &a)
	quota.Evaluate(&a, at)
	return a
}

func paceOnly(es []advise.Event) []advise.Event {
	out := []advise.Event{}
	for _, e := range es {
		if e.Type == advise.WindowPace {
			out = append(out, e)
		}
	}
	return out
}

func TestPaceWarningConjunction(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	at := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	for _, tc := range []struct {
		name         string
		used, before float64
		want         bool
	}{
		{"on pace", 40, 20, false},
		{"ahead but lasting", 60, 55, false},
		{"ahead and running out", 60, 40, true},
		{"exactly ten points ahead", 50, 30, true},
		{"under ten points ahead", 49.9, 29.9, false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			a := paceAccount(t, at, tc.used, tc.before)
			es := paceOnly(advise.Derive(advise.Input{Report: quota.Report{Accounts: []quota.Account{a}}, Now: at}))
			if (len(es) == 1) != tc.want {
				t.Fatalf("pace events=%+v", es)
			}
			if tc.want && (es[0].RunsOutInMinutes == nil || *es[0].RunsOutInMinutes >= *es[0].InMinutes || es[0].Suggest != nil) {
				t.Fatal(es)
			}
		})
	}
}

func TestPaceWarningOncePerToolWindowAcrossModels(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	at := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	a := paceAccount(t, at, 60, 40)
	cache := t.TempDir()
	state := advise.Load(cache)
	derive := func(a quota.Account) []advise.Event {
		return paceOnly(advise.Derive(advise.Input{Report: quota.Report{Accounts: []quota.Account{a}}, State: state, Now: at}))
	}
	first := derive(a)
	if len(first) != 1 || advise.ConfigKey(first[0]) != first[0].Key {
		t.Fatal(first)
	}
	state.NoteShown(first[0], at)
	if err := state.Save(cache, at); err != nil {
		t.Fatal(err)
	}
	state = advise.Load(cache)
	a.Harness.Model, a.Harness.Effort = "different", "high"
	if len(derive(a)) != 0 {
		t.Fatal("model change repeated window warning")
	}
	a.Source = "codex"
	if len(derive(a)) != 1 {
		t.Fatal("one tool consumed another tool's window")
	}
	later := at.Add(7 * 24 * time.Hour)
	a = paceAccount(t, later, 60, 40)
	at = later
	if len(derive(a)) != 1 {
		t.Fatal("new window suppressed")
	}
}

func TestPaceWarningClaimLastsThroughMonthlyWindow(t *testing.T) {
	at := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	reset := at.Add(30 * 24 * time.Hour)
	key := advise.WindowPace + "|claude-code||monthly||" + reset.Format(time.RFC3339)
	cache := t.TempDir()
	state := advise.Load(cache)
	state.MarkSeen([]advise.Event{{Key: key}}, at)
	if err := state.Save(cache, at); err != nil {
		t.Fatal(err)
	}
	state = advise.Load(cache)
	later := at.Add(10 * 24 * time.Hour)
	state.Once("other event", later)
	if err := state.Save(cache, later); err != nil {
		t.Fatal(err)
	}
	if _, exists := advise.Load(cache).Seen[key]; !exists {
		t.Fatal("pace notice expired before its window")
	}
}

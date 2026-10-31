// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/json"
	"os"
	"testing"
	"time"
)

func dayFloat(v float64) *float64 { return &v }

func TestLastDayRateIsSeparateFromBurst(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	reset := now.Add(4 * 24 * time.Hour)
	w := Window{Kind: "weekly", UsedPercent: dayFloat(60), ObservedAt: now, ResetsAt: &reset, ResetMode: "fixed",
		recent: []Sample{{At: now.Add(-24 * time.Hour), Used: 40, ResetsAt: &reset}, {At: now.Add(-30 * time.Minute), Used: 50, ResetsAt: &reset}}}
	evalWindow(&w, now)
	if w.RunsOutInMinutes == nil || *w.RunsOutInMinutes != 120 {
		t.Fatalf("burst changed: %+v", w)
	}
	if out := w.LastDayRunout(now); out == nil || *out != 2880 {
		t.Fatalf("day rate=%v", out)
	}
}

func TestLastDayRateCoverageResetAndOptOut(t *testing.T) {
	for _, mode := range []string{"lasting", "incomplete day", "stale", "future", "other cycle", "drop", "rolling", "history off"} {
		t.Run(mode, func(t *testing.T) {
			t.Setenv("MODELPLAN_HISTORY", "")
			reset := now.Add(4 * 24 * time.Hour)
			w := Window{Kind: "weekly", UsedPercent: dayFloat(60), ObservedAt: now, ResetsAt: &reset, ResetMode: "fixed", recent: []Sample{{At: now.Add(-24 * time.Hour), Used: 40, ResetsAt: &reset}}}
			switch mode {
			case "lasting":
				w.recent[0].Used = 55
			case "incomplete day":
				w.recent[0].At = now.Add(-23 * time.Hour)
			case "stale":
				w.ObservedAt = now.Add(-11 * time.Minute)
			case "future":
				w.ObservedAt = now.Add(time.Minute)
			case "other cycle":
				other := reset.Add(-7 * 24 * time.Hour)
				w.recent[0].ResetsAt = &other
			case "drop":
				w.recent = append(w.recent, Sample{At: now.Add(-time.Hour), Used: 70, ResetsAt: &reset})
			case "rolling":
				w.ResetMode = "rolling"
			case "history off":
				t.Setenv("MODELPLAN_HISTORY", "off")
			}
			evalWindow(&w, now)
			if out := w.LastDayRunout(now); out != nil {
				t.Fatal("unjustified day forecast", *out)
			}
		})
	}
}

func TestLastDayRateInterpolatesBoundary(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	reset := now.Add(4 * 24 * time.Hour)
	w := Window{Kind: "weekly", UsedPercent: dayFloat(60), ObservedAt: now, ResetsAt: &reset,
		recent: []Sample{{At: now.Add(-24*time.Hour - 10*time.Minute), Used: 39, ResetsAt: &reset}, {At: now.Add(-24*time.Hour + 10*time.Minute), Used: 41, ResetsAt: &reset}}}
	evalWindow(&w, now)
	if out := w.LastDayRunout(now); out == nil || *out != 2880 {
		t.Fatal(out)
	}
}

func TestLastDayRateEndpointAverageAcrossInteriorGap(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "")
	reset := now.Add(4 * 24 * time.Hour)
	w := Window{Kind: "weekly", UsedPercent: dayFloat(60), ObservedAt: now, ResetsAt: &reset,
		recent: []Sample{{At: now.Add(-24 * time.Hour), Used: 40, ResetsAt: &reset}}}
	evalWindow(&w, now)
	// Two endpoints define the observed daily average. An unobserved drop
	// inside this gap cannot be detected and is not claimed to be excluded.
	if out := w.LastDayRunout(now); out == nil || *out != 2880 {
		t.Fatal("endpoint average changed", out)
	}
}

func TestStatuslineKeepsSparseDayWithinSnapshotBudget(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache := t.TempDir()
	reset := now.Add(4 * 24 * time.Hour)
	for i := 0; i <= 25*60; i++ {
		used := 20 + 40*float64(i)/(25*60)
		raw, _ := json.Marshal(map[string]any{"model": map[string]string{"id": "synthetic"}, "rate_limits": map[string]any{
			"seven_day":   map[string]any{"used_percentage": used, "resets_at": reset.Unix()},
			"spend_limit": map[string]any{"used_percentage": used, "resets_at": reset.Unix(), "period": "monthly"},
		}})
		var in StatuslineInput
		if err := json.Unmarshal(raw, &in); err != nil {
			t.Fatal(err)
		}
		if err := RecordClaudeCode(cache, in, now.Add(time.Duration(i-25*60)*time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	b, err := os.ReadFile(snapshotPath(cache))
	if err != nil || len(b) >= 64<<10 {
		t.Fatal("snapshot read budget exceeded", len(b), err)
	}
	accounts, _ := readClaudeCode(cache, "")
	if len(accounts) != 1 {
		t.Fatal("snapshot unreadable")
	}
	Evaluate(&accounts[0], now)
	if accounts[0].Windows[0].LastDayRunout(now) == nil {
		t.Fatal("full-day samples were not retained")
	}
	// Off restores the existing short retention and suppresses this warning.
	t.Setenv("MODELPLAN_HISTORY", "off")
	if out := accounts[0].Windows[0].LastDayRunout(now); out != nil {
		t.Fatal("off ignored")
	}
}

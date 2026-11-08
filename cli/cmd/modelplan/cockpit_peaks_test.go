// SPDX-License-Identifier: MIT
package main

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// D63: the declared plan's raised-rate window crosses to the cockpit under its row, from the verified client
// publication only, and never for a plan the projection does not show.
func TestCockpitPeaksCarryTheDeclaredPlansRaisedRateWindow(t *testing.T) {
	at := time.Date(2026, 11, 8, 6, 0, 0, 0, time.UTC)
	rate := func(v float64) *float64 { return &v }
	window := func(rule string, v float64, prio int, from, to time.Duration, status string) digest.MultiplierWindow {
		return digest.MultiplierWindow{RuleID: rule, Provider: "synthetic", PlanIDs: []string{"pro plan"}, Multiplier: rate(v), Priority: prio,
			StartsAt: at.Add(from).Format(time.RFC3339), EndsAt: at.Add(to).Format(time.RFC3339), Status: status}
	}
	published := &digest.Digest{Source: digest.ComponentClient,
		MultiplierHorizon: &digest.MultiplierHorizon{From: at.Add(-time.Hour).Format(time.RFC3339), To: at.Add(48 * time.Hour).Format(time.RFC3339), Selection: "highest-priority-no-stacking"},
		Multipliers:       []digest.MultiplierWindow{window("base", 1, 0, -time.Hour, 48*time.Hour, "CONFIRMED"), window("peak", 2, 10, 2*time.Hour, 5*time.Hour, "TENTATIVE")}}
	view := appserver.View{Projection: rows.Projection{Rows: []rows.Row{{ID: "declared:pro%20plan"}}},
		QuotaReport: quota.Report{Accounts: []quota.Account{{Source: "user", Plan: "pro plan"}}}}
	got := cockpitPeaks(published, view, at)
	if len(got) != 1 || got[0].RowID != "declared:pro%20plan" || !got[0].StartsAt.Equal(at.Add(2*time.Hour)) || got[0].EndsAt == nil ||
		!got[0].EndsAt.Equal(at.Add(5*time.Hour)) || got[0].Status != "tentative" {
		t.Fatalf("peak under the declared row: %+v", got)
	}
	if got := cockpitPeaks(published, appserver.View{QuotaReport: view.QuotaReport}, at); len(got) != 0 {
		t.Fatalf("no row, no peak: %+v", got)
	}
	foreign := *published
	foreign.Source = "other"
	if got := cockpitPeaks(&foreign, view, at); len(got) != 0 {
		t.Fatalf("only the verified client publication: %+v", got)
	}
	if got := cockpitPeaks(nil, view, at); len(got) != 0 {
		t.Fatalf("no publication: %+v", got)
	}
}

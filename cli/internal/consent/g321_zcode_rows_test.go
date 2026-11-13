// SPDX-License-Identifier: MIT
package consent

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

// G3-21 with the owner decision of 2026-11-06: a detected ZCode is a Dock row on a fresh
// profile, with its default-on standard routes, not a Settings-only consent prompt.
func TestG321FreshProfileZCodeIsADockRow(t *testing.T) {
	now := time.Date(2026, 11, 6, 12, 0, 0, 0, time.UTC)
	admission := NewAdmission(Empty(), Automatic)
	if !admission.Allows("zai", Local) || !admission.State().AllowsScope(ScopeZaiAccountUsageAPIKey, Automatic) {
		t.Fatal("ZCode's standard routes are not on by default")
	}
	in := admission.RowsInput(now)
	in.Catalogue = []rows.CatalogueEntry{{ToolID: "zai", Detected: true, ReaderExists: true, Status: "detected"}}
	observed, until := now.Add(-time.Minute), now.Add(time.Hour)
	percent := 75.0
	duration := int64(5 * 3600)
	reset := now.Add(2 * time.Hour)
	in.Profiles = []rows.ProfileState{{ToolID: "zai", ProfileKey: "p", LatestAttempt: rows.AttemptResultSucceeded, ObservedAt: &observed, WithinFreshness: true, FreshUntil: &until}}
	in.Accounts = []rows.AccountInput{{ToolID: "zai", ProfileKey: "p", Source: "native:zai", Route: rows.RouteAPIKeyAPI,
		Windows: []rows.WindowInput{{Source: rows.WindowSourceAPIKey, Kind: "five_hour", RemainingPercent: &percent, DurationSeconds: &duration, ResetsAt: &reset, ObservedAt: &observed, ResetMode: "fixed"}}}}
	projection := rows.Build(in)
	if err := rows.Validate(in, projection); err != nil {
		t.Fatal(err)
	}
	for _, row := range projection.Rows {
		if row.ID != "zai" {
			continue
		}
		dock := false
		for _, s := range row.Surfaces {
			dock = dock || s == rows.SurfaceDock
		}
		if !dock || len(row.Accounts) != 1 || row.Accounts[0].ValueState != rows.ValueStateCurrent {
			t.Fatalf("ZCode row consent=%s dock=%t accounts=%d", row.Consent, dock, len(row.Accounts))
		}
		return
	}
	t.Fatal("detected ZCode has no row")
}

// A recorded GLM refusal still hides ZCode's values.
func TestG321ZCodeRefusalWins(t *testing.T) {
	state := Empty()
	state.Tools["zai"] = Record{Allowed: false, ConsentTextVersion: TextVersion}
	admission := NewAdmission(state, Automatic)
	for _, c := range admission.RowsInput(time.Now()).Consents {
		if c.ToolID == "zai" && c.State != rows.ConsentDenied {
			t.Fatalf("refused ZCode consent state = %s", c.State)
		}
	}
	if admission.State().AllowsScope(ScopeZaiAccountUsageAPIKey, Automatic) {
		t.Fatal("refused ZCode key route still allowed")
	}
}

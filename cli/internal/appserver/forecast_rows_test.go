// SPDX-License-Identifier: MIT
package appserver

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestForecastTravelsFromReportToProjectionButNotOntoTheRowsWire(t *testing.T) {
	now := time.Now().UTC()
	ref := "0123456789abcdef"
	used, remaining := 60.0, 40.0
	reset := now.Add(60 * time.Hour)
	window := quota.Window{Kind: "weekly", WindowMinutes: 100 * 60, UsedPercent: &used, RemainingPercent: &remaining, ResetsAt: &reset, ResetMode: "fixed", ObservedAt: now, Pace: "tight"}
	projected := 150.0
	window.ProjectedPercent = &projected
	in := rows.Input{Now: now, ConsentGeneration: 1, Catalogue: []rows.CatalogueEntry{{ToolID: "codex", Detected: true, ReaderExists: true}}, Consents: []rows.ConsentRecord{{ToolID: "codex", Generation: 1, State: rows.ConsentAllowed}}}
	appendReportRows(&in, quota.Report{Accounts: []quota.Account{{Source: "codex", Via: "codex-account", ObservedAt: now, Subscription: &quota.Binding{Ref: ref, Status: "verified"}, Windows: []quota.Window{window}}}}, false)
	p := rows.Build(in)
	if err := rows.Validate(in, p); err != nil {
		t.Fatal(err)
	}
	got := p.Rows[0].Accounts[0].Windows[0].Forecast
	if got == nil || got.Basis != "cycle-average" || got.RunsOutAt == nil {
		t.Fatalf("forecast = %+v", got)
	}
	encoded, err := json.Marshal(wire.Project(p))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(encoded), "orecast") {
		t.Fatalf("forecast leaked onto the rows wire: %s", encoded)
	}
}

func TestRowsCarryForecastsOnlyWhenNegotiated(t *testing.T) {
	now := time.Now().UTC()
	ref, until, out := "0123456789abcdef", now.Add(time.Hour), now.Add(20*time.Minute)
	p := rows.Projection{Rows: []rows.Row{{ID: "codex", Accounts: []rows.Account{{SubscriptionRef: &ref, ValueState: rows.ValueStateCurrent, Windows: []rows.Window{
		{ID: "weekly:a", Current: true, ValidUntil: &until, ObservedAt: &now, Forecast: &rows.WindowForecast{RunsOutAt: &out, Pace: "tight", Basis: "recent-rate"}}}}}}}}
	if got := wire.ProjectWithEvents(p, nil, false, false, false, false, false, false).Forecasts; got != nil {
		t.Fatalf("forecasts without negotiation: %+v", got)
	}
	got := wire.ProjectWithEvents(p, nil, false, false, false, false, false, true).Forecasts
	if got == nil || len(*got) != 1 || (*got)[0].WindowID != "weekly:a" {
		t.Fatalf("forecasts = %+v", got)
	}
}

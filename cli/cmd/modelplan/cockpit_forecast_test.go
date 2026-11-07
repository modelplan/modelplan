// SPDX-License-Identifier: MIT
package main

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestCockpitForecastsOnlyCoverCurrentVerifiedWindows(t *testing.T) {
	now := time.Date(2026, 11, 4, 12, 0, 0, 0, time.UTC)
	ref, other := "0000000000000001", "0000000000000002"
	until, expired, observed, out := now.Add(time.Hour), now.Add(-time.Minute), now.Add(-2*time.Minute), now.Add(40*time.Minute)
	forecast := &rows.WindowForecast{RunsOutAt: &out, Pace: "tight", Basis: "recent-rate"}
	current := func(id string) rows.Window {
		return rows.Window{ID: id, Current: true, ValidUntil: &until, ObservedAt: &observed, Forecast: forecast}
	}
	stale := current("weekly:b")
	stale.ValidUntil = &expired
	noForecast := current("weekly:c")
	noForecast.Forecast = nil
	projection := rows.Projection{Rows: []rows.Row{{ID: "codex", Accounts: []rows.Account{
		{SubscriptionRef: &ref, ValueState: rows.ValueStateCurrent, Windows: []rows.Window{current("weekly:a"), stale, noForecast}},
		{SubscriptionRef: &ref, ValueState: rows.ValueStateRetained, Windows: []rows.Window{current("weekly:retained")}},
		{SubscriptionRef: &other, ValueState: rows.ValueStateCurrent, Windows: []rows.Window{current("weekly:unadmitted")}},
		{ValueState: rows.ValueStateCurrent, Windows: []rows.Window{current("weekly:unverified")}},
	}}}}
	got := wire.ProjectForecasts(projection, func(r string) bool { return r == ref }, now)
	if len(got) != 1 {
		t.Fatalf("forecasts = %+v", got)
	}
	f := got[0]
	if f.Source != "codex" || f.SubscriptionRef != ref || f.WindowID != "weekly:a" || f.Pace != wire.ForecastTight || f.Basis != wire.ForecastRecentRate || !f.RunsOutAt.Equal(out) || !f.ObservedAt.Equal(observed) {
		t.Fatalf("forecast = %+v", f)
	}
}

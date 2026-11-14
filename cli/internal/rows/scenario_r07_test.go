// SPDX-License-Identifier: MIT
package rows

// Spec-data scenario R-07 (tier-1 producer half): "Two windows have different
// sources and observation times / Open the card and inspect each / Source · age
// is derived from each actual reading and missing provenance stays unknown."
// Each exported window keeps its own source and observation time; a window with
// no provenance stays unknown and never borrows the account's or a sibling
// window's newer time.

import (
	"testing"
	"time"
)

func TestR07PerWindowProvenanceWithMissingTimeStaysUnknown(t *testing.T) {
	now := time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
	older := now.Add(-45 * time.Minute)
	newer := now.Add(-5 * time.Minute)
	fresh := now.Add(time.Hour)
	account := Account{ObservedAt: &now, FreshUntil: &fresh}
	windows := buildWindows([]WindowInput{
		{Kind: "five_hour", Source: WindowSourceLocalHistory, RemainingPercent: ptr(75.0), ObservedAt: ptr(older)},
		{Kind: "weekly", Source: WindowSourceRuntime, RemainingPercent: ptr(40.0), ObservedAt: ptr(newer)},
		{Kind: "monthly", Source: WindowSource("raw-provider-canary"), RemainingPercent: ptr(10.0), ObservedAt: nil},
	}, account, now)
	if len(windows) != 3 {
		t.Fatalf("windows missing, got %+v", windows)
	}
	byRole := map[Role]Window{}
	for _, w := range windows {
		byRole[w.Role] = w
	}
	session, ok := byRole[RoleSession]
	if !ok || session.Source == nil || *session.Source != WindowSourceLocalHistory || session.ObservedAt == nil || !session.ObservedAt.Equal(older) {
		t.Fatalf("session window lost its own provenance: %+v", session)
	}
	weekly, ok := byRole[RoleWeekly]
	if !ok || weekly.Source == nil || *weekly.Source != WindowSourceRuntime || weekly.ObservedAt == nil || !weekly.ObservedAt.Equal(newer) {
		t.Fatalf("weekly window lost its own provenance: %+v", weekly)
	}
	monthly, ok := byRole[RoleMonthly]
	if !ok {
		t.Fatalf("monthly window missing: %+v", windows)
	}
	if monthly.Source != nil {
		t.Fatalf("unknown provider source must stay unknown, got %+v", monthly.Source)
	}
	if monthly.ObservedAt != nil {
		t.Fatalf("missing provenance must stay unknown, got %+v (account observed at %v)", monthly.ObservedAt, *account.ObservedAt)
	}
}

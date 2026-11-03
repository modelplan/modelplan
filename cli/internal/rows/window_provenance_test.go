// SPDX-License-Identifier: MIT
package rows

import (
	"testing"
	"time"
)

func TestWindowProvenanceKeepsMixedSourcesAndRejectsUnknown(t *testing.T) {
	now := time.Date(2026, 11, 3, 12, 0, 0, 0, time.UTC)
	older := now.Add(-20*time.Minute)
	later := now.Add(time.Hour)
	account := Account{ObservedAt: &now, FreshUntil: &later}
	windows := buildWindows([]WindowInput{
		{Kind: "five_hour", Source: WindowSourceLocalHistory, ObservedAt: &older},
		{Kind: "weekly", Source: WindowSourceRuntime, ObservedAt: &now},
		{Kind: "monthly", Source: WindowSource("raw-provider-canary"), ObservedAt: &now},
	}, account, now)
	if len(windows) != 3 { t.Fatal("windows missing") }
	for _, window := range windows {
		switch window.Role {
		case RoleSession:
			if window.Source == nil || *window.Source != WindowSourceLocalHistory || window.ObservedAt == nil || !window.ObservedAt.Equal(older) { t.Fatal("local provenance lost") }
		case RoleWeekly:
			if window.Source == nil || *window.Source != WindowSourceRuntime || window.ObservedAt == nil || !window.ObservedAt.Equal(now) { t.Fatal("runtime provenance lost") }
		case RoleMonthly:
			if window.Source != nil { t.Fatal("unknown provider source escaped") }
		default: t.Fatalf("unexpected role: %s", window.Role)
		}
	}
}

// SPDX-License-Identifier: MIT
package rows

import (
	"testing"
	"time"
)

// D322 (owner 2026-11-19): a free Grok Build subscription ($0 balance, no usage percentage) gets no
// cockpit column and no widget ring, both of which follow the Dock surface. It stays on the Settings
// surface only, where the row says the X Subscription reports no usage percentage.
func TestD322FreeGrokHasSettingsSurfaceOnly(t *testing.T) {
	build := func(id string, balance float64) Row {
		in := sampleInput()
		in.Catalogue[0].ToolID, in.Consents[0].ToolID = id, id
		in.Profiles[0].ToolID, in.Accounts[0].ToolID = id, id
		in.Accounts[0].Windows = nil
		in.Accounts[0].Credits = &CreditsInput{Balance: &balance, Unit: "money", Currency: "USD"}
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatal(err)
		}
		return rowByID(t, out, id)
	}
	free := build("grok", 0)
	if len(free.Surfaces) != 1 || free.Surfaces[0] != SurfaceSettings {
		t.Fatalf("free grok surfaces %v", free.Surfaces)
	}
	if free.Reason.Code != CodeUsageNotReported {
		t.Fatalf("free grok code %s", free.Reason.Code)
	}
	if paid := build("grok", 12.5); !hasSurface(paid, SurfaceDock) {
		t.Fatalf("a funded grok balance lost its ring: %v", paid.Surfaces)
	}
	if other := build("codex", 0); !hasSurface(other, SurfaceDock) {
		t.Fatalf("only Grok is dropped at $0: %v", other.Surfaces)
	}
}

// An expired $0 reading is retained and the row goes stale; it must stay Settings-only, while a retained
// funded balance keeps its Dock surface.
func TestD322ExpiredFreeGrokStaysSettingsOnly(t *testing.T) {
	build := func(balance float64, expired bool) Row {
		in := sampleInput()
		in.Catalogue[0].ToolID, in.Consents[0].ToolID = "grok", "grok"
		in.Profiles[0].ToolID, in.Accounts[0].ToolID = "grok", "grok"
		in.Accounts[0].Windows = nil
		in.Accounts[0].Credits = &CreditsInput{Balance: &balance, Unit: "money", Currency: "USD"}
		if expired {
			in.Profiles[0].FreshUntil = ptr(testNow.Add(-time.Minute))
		}
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatal(err)
		}
		return rowByID(t, out, "grok")
	}
	if row := build(0, true); row.State != StateStale || row.Accounts[0].ValueState != ValueStateRetained {
		t.Fatalf("setup must retain the reading: %s %s", row.State, row.Accounts[0].ValueState)
	}
	for _, expired := range []bool{false, true} {
		if free := build(0, expired); len(free.Surfaces) != 1 || free.Surfaces[0] != SurfaceSettings {
			t.Fatalf("free grok (expired=%v) surfaces %v", expired, free.Surfaces)
		}
	}
	if paid := build(12.5, true); !hasSurface(paid, SurfaceDock) {
		t.Fatalf("a retained funded grok balance lost its ring: %v", paid.Surfaces)
	}
}

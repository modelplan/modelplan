// SPDX-License-Identifier: MIT
package rows

// Spec-data scenario R-06 (tier-1 producer half): "A stale Codex local reading
// remains subscribed / A fresh permitted local observation arrives without another
// click / The App receives the new reading automatically and leaves retained
// state." The producer keeps the stale reading subscribed and truthful, and a
// valid later observation recovers it to current with the new value and time.

import (
	"testing"
	"time"
)

func TestR06FreshObservationRecoversRetainedReading(t *testing.T) {
	stale := sampleInput()
	staleObserved := testNow.Add(-2 * time.Hour)
	stale.Profiles[0].ObservedAt = ptr(staleObserved)
	stale.Profiles[0].WithinFreshness = false
	stale.Profiles[0].FreshUntil = ptr(testNow.Add(-time.Minute))
	staleBuild := Build(stale)
	if err := Validate(stale, staleBuild); err != nil {
		t.Fatal(err)
	}
	a := rowByID(t, staleBuild, "codex").Accounts[0]
	if a.ValueState != ValueStateRetained {
		t.Fatalf("an expired reading must stay truthfully retained, got %q", a.ValueState)
	}
	if a.ObservedAt == nil || !a.ObservedAt.Equal(staleObserved) {
		t.Fatalf("source · age must describe the stale observation, got %+v", a.ObservedAt)
	}
	if len(a.Windows) != 1 || a.Windows[0].RemainingPercent == nil || *a.Windows[0].RemainingPercent != 75 {
		t.Fatalf("the subscribed stale reading must not be dropped, got %+v", a.Windows)
	}

	// A fresh permitted local observation arrives; no second click happened.
	recovered := stale
	obs := testNow.Add(-5 * time.Second)
	recovered.Profiles[0].AttemptedAt = ptr(obs)
	recovered.Profiles[0].ObservedAt = ptr(obs)
	recovered.Profiles[0].WithinFreshness = true
	recovered.Profiles[0].FreshUntil = ptr(testNow.Add(time.Hour))
	recovered.Accounts[0].Windows[0].RemainingPercent = ptr(3.0)
	recovered.Accounts[0].Windows[0].ObservedAt = ptr(obs)
	got := Build(recovered)
	if err := Validate(recovered, got); err != nil {
		t.Fatal(err)
	}
	b := rowByID(t, got, "codex").Accounts[0]
	if b.ValueState != ValueStateCurrent {
		t.Fatalf("a valid later observation must recover the retained reading, got %q", b.ValueState)
	}
	if b.Windows[0].RemainingPercent == nil || *b.Windows[0].RemainingPercent != 3 {
		t.Fatalf("the recovered reading must carry the new value, got %+v", b.Windows)
	}
	if b.ObservedAt == nil || !b.ObservedAt.Equal(obs) {
		t.Fatalf("the recovered reading must carry the new observation time, got %+v", b.ObservedAt)
	}
	if b.LastFailure != nil {
		t.Fatalf("recovery must leave no failure behind, got %+v", b.LastFailure)
	}
}

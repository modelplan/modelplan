// SPDX-License-Identifier: MIT
package rows

// Spec-data scenario R-05 (tier-1 producer half): "A previously valid reading
// expires or a read fails / Time advances or the reader fails / The App marks data
// stale or retained, with no fabricated fresh value." The producer must keep the
// last admitted values retained, record the failure truthfully, keep source · age
// on the last actual observation, and never extend freshness after a failure.

import (
	"testing"
	"time"
)

func TestR05FailedReadStaysRetainedWithoutFabricatedFresh(t *testing.T) {
	in := sampleInput()
	in.Profiles[0].LatestAttempt = AttemptResultFailed
	in.Profiles[0].LastFailure = &FailureInput{Code: string(CodeParseError), At: ptr(testNow)}
	in.Profiles[0].WithinFreshness = false
	in.Profiles[0].FreshUntil = ptr(testNow.Add(-time.Second))
	got := Build(in)
	if err := Validate(in, got); err != nil {
		t.Fatal(err)
	}
	a := rowByID(t, got, "codex").Accounts[0]
	if a.ValueState != ValueStateRetained {
		t.Fatalf("a failed read must stay retained, got %q", a.ValueState)
	}
	if a.LastFailure == nil || a.LastFailure.Code != CodeParseError {
		t.Fatalf("the failure must be recorded truthfully, got %+v", a.LastFailure)
	}
	if a.ObservedAt == nil || !a.ObservedAt.Equal(testNow.Add(-time.Minute)) {
		t.Fatalf("source · age must stay on the last actual observation, got %+v", a.ObservedAt)
	}
	if len(a.Windows) != 1 || a.Windows[0].RemainingPercent == nil || *a.Windows[0].RemainingPercent != 75 {
		t.Fatalf("retained values must not be dropped or zeroed, got %+v", a.Windows)
	}
	if a.Windows[0].Current {
		t.Fatal("an expired window must not present as current/fresh")
	}
	if a.FreshUntil == nil || !a.FreshUntil.Before(testNow) {
		t.Fatalf("freshness must not be fabricated after a failure, got %+v", a.FreshUntil)
	}
}

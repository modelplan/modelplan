// SPDX-License-Identifier: MIT
package appserver

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestRefreshDecisionRingBoundsCodesAndLifetime(t *testing.T) {
	var ring refreshDecisionRing
	now := time.Unix(1700000000, 0)
	for i := 0; i < 23; i++ {
		ring.add(now.Add(time.Duration(i)*time.Second), consent.ScopeCodexRuntimeUsage, refreshSucceeded, refreshCompleted)
	}
	ring.add(now, "private-path-canary", refreshFailed, refreshUnavailable)
	ring.add(now, consent.ScopeCodexRuntimeUsage, refreshOutcome("raw-error-canary"), refreshUnavailable)
	got := ring.snapshot(now.Add(24 * time.Second))
	if len(got) != 20 || got[0].AgoSeconds != 21 || got[19].AgoSeconds != 2 {
		t.Fatalf("unexpected bounded history: %+v", got)
	}
	for _, decision := range got {
		if decision.Scope != consent.ScopeCodexRuntimeUsage || decision.Outcome != refreshSucceeded || decision.Reason != refreshCompleted {
			t.Fatalf("unexpected decision: %+v", decision)
		}
	}
	if got := ring.snapshot(now); got[0].AgoSeconds != 0 {
		t.Fatalf("future times must not produce negative ages: %+v", got[0])
	}
	ring.clear()
	if got := ring.snapshot(now); len(got) != 0 {
		t.Fatalf("cleared history remains: %+v", got)
	}
}

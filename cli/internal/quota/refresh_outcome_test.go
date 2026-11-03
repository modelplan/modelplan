// SPDX-License-Identifier: MIT
package quota

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestRefreshOutcomeRequiresThisAttempt(t *testing.T) {
	cache := t.TempDir()
	now := time.Date(2026, 11, 3, 12, 0, 0, 0, time.UTC)
	p := Paths{Cache: cache}
	if err := save(cache, &accountSnap{SchemaVersion: 1, ObservedAt: now, Status: "error"}); err != nil {
		t.Fatal(err)
	}
	if got := ScopeRefreshOutcome(p, consent.ScopeCodexRuntimeUsage, now); got != "failed" {
		t.Fatal(got)
	}
	if got := ScopeRefreshOutcome(p, consent.ScopeCodexRuntimeUsage, now.Add(time.Minute)); got != "not_attempted" {
		t.Fatal(got)
	}
	if err := save(cache, &accountSnap{SchemaVersion: 1, ObservedAt: now, Status: "ok"}); err != nil {
		t.Fatal(err)
	}
	if got := ScopeRefreshOutcome(p, consent.ScopeCodexRuntimeUsage, now); got != "succeeded" {
		t.Fatal(got)
	}
}

// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// G3-85: a refresh read that never finishes kept a job pending, and observation waited for an idle
// scheduler, so the app's local sessions and rates were never written. Observation now has its
// own cadence; it runs while the read is still in flight and records what it did.
func TestObservationRunsWhileARefreshJobStaysPending(t *testing.T) {
	backend, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	var running atomic.Bool
	started := make(chan struct{}, 1)
	observedDuringRead := make(chan struct{}, 1)
	var calls atomic.Int32
	s := NewRefreshScheduler(context.Background(), RefreshConfig{
		Backend: backend, Paths: paths, ObserveEvery: 10 * time.Millisecond,
		Plan: func(_ quota.Paths, _ string, now time.Time) (quota.ScopeRefreshPlan, error) {
			return quota.ScopeRefreshPlan{At: now, Admitted: true, BudgetKnown: true}, nil
		},
		Run: func(ctx context.Context, _ quota.Paths, _ string, _ time.Time) error {
			running.Store(true)
			select {
			case started <- struct{}{}:
			default:
			}
			<-ctx.Done() // the read never returns on its own
			return ctx.Err()
		},
		Observe: func(time.Time) []ObserveResult {
			calls.Add(1)
			if running.Load() {
				select {
				case observedDuringRead <- struct{}{}:
				default:
				}
			}
			return []ObserveResult{{Source: "codex", Outcome: ObserveRan}, {Source: "claude", Outcome: ObserveSkippedConsent}}
		},
	})
	defer s.Close()
	s.StartAutomatic()
	select {
	case <-started:
	case <-time.After(5 * time.Second):
		t.Fatal("the refresh read did not start")
	}
	select {
	case <-observedDuringRead:
	case <-time.After(5 * time.Second):
		t.Fatalf("no observation while a refresh job was pending (observations: %d)", calls.Load())
	}
	s.mu.Lock()
	pending := len(s.pending)
	s.mu.Unlock()
	if pending == 0 {
		t.Fatal("the read was expected to keep its job pending")
	}
	got := map[string]ObserveOutcome{}
	for _, d := range s.ObserveDecisions() {
		got[d.Source] = d.Outcome
	}
	if got["codex"] != ObserveRan || got["claude"] != ObserveSkippedConsent {
		t.Fatalf("decisions = %+v", s.ObserveDecisions())
	}
	if n := len(s.ObserveDecisions()); n != 2 {
		t.Fatalf("repeated outcomes must move only their time, got %d entries", n)
	}
	raw, err := os.ReadFile(filepath.Join(cache, "observed", ObserveLogFile))
	if err != nil {
		t.Fatal(err)
	}
	var log struct {
		SchemaVersion int               `json:"schemaVersion"`
		Decisions     []ObserveDecision `json:"decisions"`
	}
	if json.Unmarshal(raw, &log) != nil || log.SchemaVersion != 1 || len(log.Decisions) != 2 {
		t.Fatalf("observation log = %s", raw)
	}
}

func TestObservationOffWhenOfflineOrReadOnly(t *testing.T) {
	for _, config := range []RefreshConfig{{Offline: true}, {ReadOnly: true}} {
		backend, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
		config.Backend, config.Paths, config.ObserveEvery = backend, paths, 10*time.Millisecond
		config.Observe = func(time.Time) []ObserveResult { t.Error("observed while offline or read-only"); return nil }
		s := NewRefreshScheduler(context.Background(), config)
		s.StartAutomatic()
		time.Sleep(50 * time.Millisecond)
		s.Close()
		if _, err := os.Stat(filepath.Join(cache, "observed", ObserveLogFile)); !os.IsNotExist(err) {
			t.Fatal("observation log written while offline or read-only")
		}
	}
}

func TestObserveRingKeepsOneEntryPerRepeatedOutcome(t *testing.T) {
	var r observeRing
	at := time.Unix(1000, 0)
	r.add(at, ObserveResult{Source: "codex", Outcome: ObserveSkippedLockBusy})
	r.add(at.Add(time.Second), ObserveResult{Source: "codex", Outcome: ObserveSkippedLockBusy})
	r.add(at.Add(2*time.Second), ObserveResult{Source: "codex", Outcome: ObserveRan})
	r.add(at.Add(3*time.Second), ObserveResult{Source: "nope", Outcome: ObserveRan})
	r.add(at.Add(3*time.Second), ObserveResult{Source: "codex", Outcome: "bogus"})
	got := r.snapshot()
	if len(got) != 2 || got[0].Outcome != ObserveSkippedLockBusy || !got[0].At.Equal(at.Add(time.Second)) || got[1].Outcome != ObserveRan {
		t.Fatalf("ring = %+v", got)
	}
}

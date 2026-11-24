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

// WP-17 (Fable perf plan 5.1 row 2): the first ledger observation walks every Claude and Codex
// log directory; at start it ran in the same moment as the first views and reads. It now waits
// ObserveAfter (the app: ObserveFirstDelay, 2-3 s) after the automatic start, then keeps its cadence.
func TestFirstObservationWaitsObserveAfter(t *testing.T) {
	if ObserveFirstDelay < 2*time.Second || ObserveFirstDelay > 3*time.Second {
		t.Fatalf("ObserveFirstDelay = %v, want 2-3 s", ObserveFirstDelay)
	}
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	first := make(chan time.Time, 1)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{
		Backend: backend, Paths: paths, ObserveEvery: time.Hour, ObserveAfter: 300 * time.Millisecond,
		Observe: func(time.Time) []ObserveResult {
			select {
			case first <- time.Now():
			default:
			}
			return []ObserveResult{{Source: "codex", Outcome: ObserveRan}}
		},
	})
	defer s.Close()
	started := time.Now()
	s.StartAutomatic()
	select {
	case at := <-first:
		if waited := at.Sub(started); waited < 300*time.Millisecond {
			t.Fatalf("the first observation ran after %v, before ObserveAfter", waited)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("no observation after ObserveAfter")
	}
}

// D397 (energy plan item 2): a pass that wrote no ledger signals no change, and repeating its
// outcomes does not rewrite observe-decisions.json, whose rename would move the watched observed
// directory. So an idle 30-second pass builds no view. A pass that writes a ledger still
// signals, and a changed outcome is still recorded.
func TestObservationSignalsOnlyWhatItWrote(t *testing.T) {
	backend, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	outcome, write := ObserveRan, false
	var changed int
	s := NewRefreshScheduler(context.Background(), RefreshConfig{
		Backend: backend, Paths: paths,
		Observe: func(time.Time) []ObserveResult {
			if write {
				if err := os.WriteFile(filepath.Join(cache, "observed", ".tmp-ledger"), []byte("{}"), 0o600); err != nil {
					t.Error(err)
				}
				if err := os.Rename(filepath.Join(cache, "observed", ".tmp-ledger"), filepath.Join(cache, "observed", "perf.json")); err != nil {
					t.Error(err)
				}
			}
			return []ObserveResult{{Source: "codex", Outcome: outcome}}
		},
		Changed: func() { changed++ },
	})
	defer s.Close()
	logFile := filepath.Join(cache, "observed", ObserveLogFile)
	at := time.Now()
	pass := func() (signalled bool, logInfo os.FileInfo, dirInfo os.FileInfo) {
		t.Helper()
		before := changed
		s.ObserveOnce(at)
		at = at.Add(30 * time.Second)
		var err error
		if logInfo, err = os.Stat(logFile); err != nil {
			t.Fatal(err)
		}
		if dirInfo, err = os.Stat(filepath.Dir(logFile)); err != nil {
			t.Fatal(err)
		}
		return changed > before, logInfo, dirInfo
	}
	_, firstLog, firstDir := pass()
	time.Sleep(20 * time.Millisecond) // a rename now would carry a later time
	for i := 0; i < 3; i++ {
		signalled, log, dir := pass()
		if signalled {
			t.Fatalf("pass %d wrote nothing and signalled a change", i)
		}
		if !os.SameFile(firstLog, log) || !dir.ModTime().Equal(firstDir.ModTime()) {
			t.Fatalf("pass %d rewrote the observation log with the same outcomes", i)
		}
	}
	write = true
	if signalled, _, _ := pass(); !signalled {
		t.Fatal("a pass that replaced a ledger signalled no change")
	}
	write, outcome = false, ObserveSkippedLockBusy
	if _, log, _ := pass(); os.SameFile(firstLog, log) {
		t.Fatal("a changed outcome was not recorded in the observation log")
	}
	raw, err := os.ReadFile(logFile)
	if err != nil {
		t.Fatal(err)
	}
	var got struct {
		Decisions []ObserveDecision `json:"decisions"`
	}
	if json.Unmarshal(raw, &got) != nil || len(got.Decisions) != 2 || got.Decisions[1].Outcome != ObserveSkippedLockBusy {
		t.Fatalf("observation log = %s", raw)
	}
}

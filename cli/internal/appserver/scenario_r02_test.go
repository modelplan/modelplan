// SPDX-License-Identifier: MIT
package appserver

// Spec-data scenario R-02 (tier-1 producer half): "A granted source is due while
// asleep / Wake starts a new client session / Eligible read resumes subject to
// budget and floor; no duplicate concurrent read." Launch requests the eligible
// reading; a wake session must not read before the persisted floor and must not
// duplicate the resumed read.

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// r02RecordRun persists the observation the way the real reader would, so the
// default plan (quota.PlanScopeRefresh) sees the budget across sessions.
func r02RecordRun(calls chan string, mu *sync.Mutex, runs *map[string]int) func(context.Context, quota.Paths, string, time.Time) error {
	return func(_ context.Context, paths quota.Paths, _ string, at time.Time) error {
		path := filepath.Join(paths.Cache, "observed", "codex-account.json")
		if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
			return err
		}
		data, err := json.Marshal(map[string]any{"schemaVersion": 1, "observedAt": at.UTC(), "status": "ok"})
		if err != nil {
			return err
		}
		if err := os.WriteFile(path, data, 0600); err != nil {
			return err
		}
		mu.Lock()
		(*runs)["codex"]++
		mu.Unlock()
		calls <- "codex"
		return nil
	}
}

func TestR02WakeResumesEligibleReadWithoutDuplicate(t *testing.T) {
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	mu := sync.Mutex{}
	runs := map[string]int{}
	calls := make(chan string, 4)
	clock := &syntheticRefreshClock{now: time.Now().UTC().Truncate(time.Second)}
	start := clock.read()
	config := RefreshConfig{Backend: backend, Paths: paths, Now: clock.read, Run: r02RecordRun(calls, &mu, &runs)}
	s := NewRefreshScheduler(context.Background(), config)
	s.StartAutomatic()
	select {
	case got := <-calls:
		if got != "codex" {
			t.Fatalf("launch read the wrong provider: %s", got)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("launch did not request the eligible reading")
	}
	waitAutomaticFloor(t, s, "codex", start)

	// Wake starts a new client session; the floor persisted by the first read holds.
	s.Close()
	s = NewRefreshScheduler(context.Background(), config)
	defer s.Close()
	s.StartAutomatic()
	clock.set(start.Add(3 * time.Minute))
	signalAutomatic(s)
	select {
	case got := <-calls:
		t.Fatalf("wake read %s before the persisted floor elapsed", got)
	case <-time.After(10 * time.Millisecond):
	}
	clock.set(start.Add(5 * time.Minute))
	signalAutomatic(s)
	select {
	case got := <-calls:
		if got != "codex" {
			t.Fatalf("wake resumed the wrong provider: %s", got)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("wake did not resume the eligible read at its floor")
	}
	waitAutomaticFloor(t, s, "codex", start.Add(5*time.Minute))
	signalAutomatic(s)
	select {
	case got := <-calls:
		t.Fatalf("duplicate concurrent read %s", got)
	case <-time.After(10 * time.Millisecond):
	}
	mu.Lock()
	defer mu.Unlock()
	if runs["codex"] != 2 {
		t.Fatalf("expected exactly launch + wake reads, got %+v", runs)
	}
}

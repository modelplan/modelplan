// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestR03IndependentProviderDeadlines(t *testing.T) {
	const failing = consent.ScopeCodexRuntimeUsage
	const healthy = consent.ScopeKimiAccountUsageSavedLogin
	backend, paths, _ := refreshFixture(t, failing)
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		state.Scopes[failing] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		state.Scopes[healthy] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	backend.view.Stamp = stampOfFence(consent.Capture().Fence())
	backend.view.Projection.ConsentGeneration = backend.view.Stamp.Generation
	backend.view.Scopes = []string{failing, healthy}
	start := time.Now().UTC()
	clock := &syntheticRefreshClock{now: start}
	var mu sync.Mutex
	counts := map[string]int{}
	attempts := make(chan string, 8)
	plan := func(_ quota.Paths, scope string, now time.Time) (quota.ScopeRefreshPlan, error) {
		mu.Lock()
		count := counts[scope]
		mu.Unlock()
		at := start
		if count > 0 && scope == healthy {
			at = start.Add(10 * time.Minute)
		}
		if at.Before(now) {
			at = now
		}
		return quota.ScopeRefreshPlan{At: at, Admitted: true, BudgetKnown: true}, nil
	}
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Now: clock.read, Plan: plan,
		Run: func(_ context.Context, _ quota.Paths, scope string, _ time.Time) error {
			mu.Lock()
			counts[scope]++
			mu.Unlock()
			attempts <- scope
			if scope == failing {
				return errors.New("synthetic failure")
			}
			return nil
		}})
	defer s.Close()
	s.StartAutomatic()
	got := map[string]int{}
	for len(got) < 2 {
		select {
		case scope := <-attempts:
			got[scope]++
		case <-time.After(5 * time.Second):
			t.Fatalf("startup attempts: %v", got)
		}
	}
	if got[failing] != 1 || got[healthy] != 1 {
		t.Fatalf("startup attempts: %v", got)
	}
	waitAutomaticFloor(t, s, "codex", start)
	waitAutomaticFloor(t, s, "kimi", start)
	clock.set(start.Add(10 * time.Minute))
	signalAutomatic(s)
	select {
	case scope := <-attempts:
		if scope != healthy {
			t.Fatalf("failure backoff bypassed: %s", scope)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("healthy provider not due")
	}
	mu.Lock()
	defer mu.Unlock()
	if counts[failing] != 1 || counts[healthy] != 2 {
		t.Fatalf("attempts at 10m: %v", counts)
	}
}

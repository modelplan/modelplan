// SPDX-License-Identifier: MIT
package appserver

// Spec-data scenario R-03 (tier-1 producer half): "Multiple granted routes have
// different success intervals / Advance synthetic time across each due time /
// Each route is requested at its own due time, with single-in-flight and
// back-off." Two granted providers must be planned and read independently: one
// provider's due time must not drag the other, and one in-flight read must not
// postpone another route's due read.

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func r03GrantSecondScope(t *testing.T, backend *memoryBackend) {
	t.Helper()
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		state.Scopes[consent.ScopeClaudeAccountUsageSavedLogin] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	backend.view.Stamp = stampOfFence(consent.Capture().Fence())
	backend.view.Projection.ConsentGeneration = backend.view.Stamp.Generation
	backend.view.Scopes = []string{consent.ScopeCodexRuntimeUsage, consent.ScopeClaudeAccountUsageSavedLogin}
}

func TestR03EachRouteRunsAtItsOwnDueTime(t *testing.T) {
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	r03GrantSecondScope(t, backend)
	mu := sync.Mutex{}
	runs := map[string]int{}
	next := map[string]time.Time{}
	calls := make(chan string, 4)
	clock := &syntheticRefreshClock{now: time.Now().UTC().Truncate(time.Second)}
	start := clock.read()
	next[consent.ScopeCodexRuntimeUsage] = start
	next[consent.ScopeClaudeAccountUsageSavedLogin] = start.Add(4 * time.Minute)
	config := RefreshConfig{Backend: backend, Paths: paths, Now: clock.read,
		Plan: func(_ quota.Paths, scope string, now time.Time) (quota.ScopeRefreshPlan, error) {
			mu.Lock()
			at := next[scope]
			mu.Unlock()
			if at.Before(now) {
				at = now
			}
			return quota.ScopeRefreshPlan{At: at, Admitted: true, BudgetKnown: true}, nil
		},
		Run: func(_ context.Context, _ quota.Paths, scope string, at time.Time) error {
			mu.Lock()
			runs[scope]++
			next[scope] = at.Add(30 * time.Minute)
			mu.Unlock()
			calls <- scope
			return nil
		}}
	s := NewRefreshScheduler(context.Background(), config)
	defer s.Close()
	s.StartAutomatic()
	select {
	case got := <-calls:
		if got != consent.ScopeCodexRuntimeUsage {
			t.Fatalf("first due route was %s, want codex", got)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("codex due time missed")
	}
	select {
	case got := <-calls:
		t.Fatalf("claude ran at codex's due time: %s", got)
	case <-time.After(10 * time.Millisecond):
	}
	clock.set(start.Add(4 * time.Minute))
	signalAutomatic(s)
	select {
	case got := <-calls:
		if got != consent.ScopeClaudeAccountUsageSavedLogin {
			t.Fatalf("second due route was %s, want claude", got)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("claude due time missed")
	}
	select {
	case got := <-calls:
		t.Fatalf("unexpected extra read %s", got)
	case <-time.After(10 * time.Millisecond):
	}
	mu.Lock()
	defer mu.Unlock()
	if runs[consent.ScopeCodexRuntimeUsage] != 1 || runs[consent.ScopeClaudeAccountUsageSavedLogin] != 1 {
		t.Fatalf("each route must run once at its own due time, got %+v", runs)
	}
}

func TestR03InFlightReadDoesNotBlockOtherRoute(t *testing.T) {
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	r03GrantSecondScope(t, backend)
	mu := sync.Mutex{}
	runs := map[string]int{}
	next := map[string]time.Time{}
	calls := make(chan string, 4)
	release := make(chan struct{})
	clock := &syntheticRefreshClock{now: time.Now().UTC().Truncate(time.Second)}
	start := clock.read()
	next[consent.ScopeCodexRuntimeUsage] = start
	next[consent.ScopeClaudeAccountUsageSavedLogin] = start.Add(4 * time.Minute)
	config := RefreshConfig{Backend: backend, Paths: paths, Now: clock.read,
		Plan: func(_ quota.Paths, scope string, now time.Time) (quota.ScopeRefreshPlan, error) {
			mu.Lock()
			at := next[scope]
			mu.Unlock()
			if at.Before(now) {
				at = now
			}
			return quota.ScopeRefreshPlan{At: at, Admitted: true, BudgetKnown: true}, nil
		},
		Run: func(ctx context.Context, _ quota.Paths, scope string, at time.Time) error {
			mu.Lock()
			runs[scope]++
			next[scope] = at.Add(30 * time.Minute)
			mu.Unlock()
			if scope == consent.ScopeCodexRuntimeUsage {
				select {
				case <-release:
				case <-ctx.Done():
					return ctx.Err()
				}
			}
			calls <- scope
			return nil
		}}
	s := NewRefreshScheduler(context.Background(), config)
	defer s.Close()
	s.StartAutomatic()
	select {
	case <-calls:
	case <-time.After(3 * time.Second):
		t.Fatal("codex due time missed")
	}
	// Advance across claude's due time while the codex read is still in flight.
	clock.set(start.Add(4 * time.Minute))
	signalAutomatic(s)
	select {
	case got := <-calls:
		if got != consent.ScopeClaudeAccountUsageSavedLogin {
			t.Fatalf("unexpected reader %s", got)
		}
	case <-time.After(time.Second):
		close(release)
		t.Fatal("claude route was not requested at its own due time while another provider read was in flight (worker serializes runs)")
	}
	close(release)
	mu.Lock()
	defer mu.Unlock()
	if runs[consent.ScopeCodexRuntimeUsage] != 1 || runs[consent.ScopeClaudeAccountUsageSavedLogin] != 1 {
		t.Fatalf("each route must run exactly once, got %+v", runs)
	}
}

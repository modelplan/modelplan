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

func TestAutomaticRefreshStartsGrantedCodexOnce(t *testing.T) {
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	calls := make(chan string, 2)
	scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{
		Backend: backend, Paths: paths,
		Run: func(_ context.Context, _ quota.Paths, scope string, _ time.Time) error {
			calls <- scope
			return nil
		},
	})
	defer scheduler.Close()
	scheduler.StartAutomatic()
	scheduler.StartAutomatic()
	select {
	case scope := <-calls:
		if scope != consent.ScopeCodexRuntimeUsage { t.Fatalf("unexpected scope %s", scope) }
	case <-time.After(5 * time.Second):
		t.Fatal("granted runtime was not scheduled")
	}
	select {
	case scope := <-calls:
		t.Fatalf("duplicate request before floor: %s", scope)
	case <-time.After(100 * time.Millisecond):
	}
}

type syntheticRefreshClock struct {
	mu sync.Mutex
	now time.Time
}
func (c *syntheticRefreshClock) read() time.Time { c.mu.Lock(); defer c.mu.Unlock(); return c.now }
func (c *syntheticRefreshClock) set(at time.Time) { c.mu.Lock(); c.now = at; c.mu.Unlock() }
func signalAutomatic(s *RefreshScheduler) {
	s.signal()
	select { case s.autoWake <- struct{}{}: default: }
}
func waitAutomaticFloor(t *testing.T, s *RefreshScheduler, key string, after time.Time) {
	t.Helper()
	deadline := time.Now().Add(3*time.Second)
	for time.Now().Before(deadline) {
		s.mu.Lock(); until := s.autoNext[key]; s.mu.Unlock()
		if until.After(after) { return }
		time.Sleep(time.Millisecond)
	}
	t.Fatal("automatic completion was not recorded")
}

func TestAutomaticRefreshSyntheticClockProviders(t *testing.T) {
	for _, scope := range []string{
		consent.ScopeCodexRuntimeUsage, consent.ScopeClaudeAccountUsageSavedLogin,
		consent.ScopeGeminiAccountUsageSavedLogin, consent.ScopeCursorAccountUsageSavedLogin,
		consent.ScopeCopilotRuntimeUsage, consent.ScopeKimiAccountUsageSavedLogin,
		consent.ScopeGrokAccountUsageSavedLogin, consent.ScopeKiroRuntimeUsage,
		consent.ScopeAntigravityRuntimeUsage, consent.ScopeZaiAccountUsageAPIKey,
		consent.ScopeMiniMaxAccountUsageAPIKey, consent.ScopeOpenCodeGoAccountUsageAPIKey,
	} {
		t.Run(scope, func(t *testing.T) {
			backend, paths, _ := refreshFixture(t, scope)
			if err := consent.Change(consent.Path(), func(state *consent.State) error {
				state.Scopes[scope] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
				return nil
			}); err != nil { t.Fatal(err) }
			backend.view.Stamp = stampOfFence(consent.Capture().Fence())
			backend.view.Scopes = []string{scope}
			clock := &syntheticRefreshClock{now: time.Now().UTC()}
			start := clock.read()
			var mu sync.Mutex
			next := start
			attempts := 0
			calls := make(chan int, 4)
			release := make(chan struct{})
			plan := func(_ quota.Paths, _ string, now time.Time) (quota.ScopeRefreshPlan, error) {
				mu.Lock(); at := next; mu.Unlock()
				if at.Before(now) { at = now }
				return quota.ScopeRefreshPlan{At: at, Admitted: true, BudgetKnown: true}, nil
			}
			config := RefreshConfig{Backend: backend, Paths: paths, Now: clock.read, Plan: plan,
				Run: func(ctx context.Context, _ quota.Paths, _ string, at time.Time) error {
					mu.Lock(); attempts++; n := attempts
					if n == 1 { next = at.Add(10*time.Minute) } else { next = at.Add(30*time.Minute) }
					mu.Unlock()
					calls <- n
					if n == 2 { select { case <-release: case <-ctx.Done(): }; return errors.New("synthetic failure") }
					return nil
				},
			}
			s := NewRefreshScheduler(context.Background(), config)
			defer s.Close()
			s.StartAutomatic()
			select { case <-calls: case <-time.After(3*time.Second): t.Fatal("startup did not read") }
			definition, _ := consent.Definition(scope)
			waitAutomaticFloor(t, s, definition.Tool, start)
			clock.set(start.Add(4*time.Minute)); signalAutomatic(s)
			select { case n := <-calls: t.Fatalf("read %d bypassed floor", n); case <-time.After(10*time.Millisecond): }
			// A new app-server session represents wake; the provider budget survives it.
			s.Close()
			s = NewRefreshScheduler(context.Background(), config)
			defer s.Close()
			s.StartAutomatic()
			select { case n := <-calls: t.Fatalf("wake read %d bypassed budget", n); case <-time.After(10*time.Millisecond): }
			clock.set(start.Add(10*time.Minute)); signalAutomatic(s)
			select { case n := <-calls: if n != 2 { t.Fatalf("unexpected attempt %d", n) }; case <-time.After(3*time.Second): t.Fatal("provider due time missed") }
			signalAutomatic(s)
			select { case n := <-calls: t.Fatalf("concurrent read %d", n); case <-time.After(10*time.Millisecond): }
			close(release)
			waitAutomaticFloor(t, s, definition.Tool, start.Add(10*time.Minute))
			clock.set(start.Add(39*time.Minute)); signalAutomatic(s)
			select { case n := <-calls: t.Fatalf("read %d bypassed failure budget", n); case <-time.After(10*time.Millisecond): }
			clock.set(start.Add(40*time.Minute)); signalAutomatic(s)
			select { case n := <-calls: if n != 3 { t.Fatalf("unexpected attempt %d", n) }; case <-time.After(3*time.Second): t.Fatal("failure budget did not expire") }
		})
	}
}

func TestAutomaticNeverSchedulesImplicitGrant(t *testing.T) {
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		state.Scopes = map[string]consent.Record{}
		state.Tools = map[string]consent.Record{}
		return nil
	}); err != nil { t.Fatal(err) }
	backend.view.Stamp = stampOfFence(consent.Capture().Fence())
	backend.view.Scopes = []string{consent.ScopeCodexRuntimeUsage}
	calls := make(chan struct{}, 1)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths,
		Run: func(context.Context, quota.Paths, string, time.Time) error { calls <- struct{}{}; return nil },
	})
	defer s.Close()
	s.StartAutomatic()
	select { case <-calls: t.Fatal("implicit consent scheduled a live read"); case <-time.After(100*time.Millisecond): }
}

func TestAutomaticFallsBackToGrantedCodexHistory(t *testing.T) {
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexLocalHistory)
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		delete(state.Scopes, consent.ScopeCodexRuntimeUsage)
		state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil { t.Fatal(err) }
	backend.view.Stamp = stampOfFence(consent.Capture().Fence())
	backend.view.Scopes = []string{consent.ScopeCodexLocalHistory}
	calls := make(chan string, 1)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths,
		Plan: func(_ quota.Paths, _ string, now time.Time) (quota.ScopeRefreshPlan, error) { return quota.ScopeRefreshPlan{At: now, Admitted: true, BudgetKnown: true}, nil },
		Run: func(_ context.Context, _ quota.Paths, scope string, _ time.Time) error { calls <- scope; return nil },
	})
	defer s.Close()
	s.StartAutomatic()
	select { case scope := <-calls: if scope != consent.ScopeCodexLocalHistory { t.Fatalf("wrong fallback: %s", scope) }; case <-time.After(3*time.Second): t.Fatal("local fallback was not scheduled") }
}

// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// stubObserveBackend is enough of a backend for the scheduler to admit the Codex scopes.
type stubObserveBackend struct{}

func (stubObserveBackend) Get(ctx context.Context) (appserver.View, error) {
	f := consent.Capture().Fence()
	return appserver.View{Stamp: appserver.Stamp{Epoch: f.StoreEpoch, Generation: f.Generation},
		Scopes: []string{consent.ScopeCodexLocalHistory, consent.ScopeCodexRuntimeUsage}}, ctx.Err()
}
func (stubObserveBackend) Publish(_ context.Context, _ appserver.Stamp, write func() error) error {
	return write()
}
func (stubObserveBackend) Grant(context.Context, wire.ConsentGrantParams) (appserver.GrantResult, error) {
	return appserver.GrantResult{}, nil
}
func (stubObserveBackend) Changes(context.Context) <-chan struct{} { return nil }

// observeCadenceHome: an isolated home with one Codex rollout holding token_count events, and the
// Codex grant set as asked (without it, every local observer is refused).
func observeCadenceHome(t *testing.T, codexAllowed bool) *store.Store {
	t.Helper()
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	for name, value := range map[string]string{"MODELPLAN_CACHE": filepath.Join(home, "cache"), "MODELPLAN_HISTORY": "", "MODELPLAN_READERS": "automatic",
		"MODELPLAN_CODEXBAR": "off", "MODELPLAN_CODEX": filepath.Join(home, "no-real-codex")} {
		t.Setenv(name, value)
	}
	now := time.Now().UTC()
	log := filepath.Join(home, ".codex", "sessions", now.Format("2006"), now.Format("01"), now.Format("02"), "rollout-g385.jsonl")
	if err := os.MkdirAll(filepath.Dir(log), 0o700); err != nil {
		t.Fatal(err)
	}
	var body []byte
	for i, at := range []time.Time{now.Add(-2 * time.Minute), now.Add(-time.Minute)} {
		line, err := json.Marshal(map[string]any{"timestamp": at, "type": "event_msg", "payload": map[string]any{"type": "token_count",
			"info":        map[string]any{"last_token_usage": map[string]any{"input_tokens": 100, "output_tokens": 40 + i}, "total_token_usage": map[string]any{"input_tokens": 100 * (i + 1), "output_tokens": 40 * (i + 1)}},
			"rate_limits": map[string]any{"limit_id": "codex", "plan_type": "plus", "primary": map[string]any{"used_percent": 20, "window_minutes": 10080, "resets_at": now.Add(24 * time.Hour).Unix()}}}})
		if err != nil {
			t.Fatal(err)
		}
		body = append(append(body, line...), '\n')
	}
	if err := os.WriteFile(log, body, 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := changeConsentWhenFree(func(s *consent.State) error {
		if err := consent.Set(s, "codex", codexAllowed, "native:codex", "native", now); err != nil {
			return err
		}
		s.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: codexAllowed, ConsentTextVersion: consent.TextVersion}
		s.Scopes[consent.ScopeCodexRuntimeUsage] = consent.Record{Allowed: codexAllowed, ConsentTextVersion: consent.TextVersion}
		if !codexAllowed {
			// The other local observers write perf.json too: refuse them so nothing may be written.
			for _, tool := range []string{"claude", "zai", "opencodego"} {
				if err := consent.Set(s, tool, false, "native:"+tool, "native", now); err != nil {
					return err
				}
			}
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	return st
}

// startObserveScheduler starts the app-server scheduler with the production observer and a refresh
// read that never returns, so one job stays pending for the whole test.
func startObserveScheduler(t *testing.T, st *store.Store) (*appserver.RefreshScheduler, <-chan struct{}) {
	t.Helper()
	started := make(chan struct{}, 1)
	s := appserver.NewRefreshScheduler(context.Background(), appserver.RefreshConfig{
		Backend: stubObserveBackend{}, ObserveEvery: 20 * time.Millisecond,
		Paths: func(a consent.Admission) quota.Paths { return quota.ProductionPathsWithAdmission(st.Dir, "test", a) },
		Plan: func(_ quota.Paths, _ string, now time.Time) (quota.ScopeRefreshPlan, error) {
			return quota.ScopeRefreshPlan{At: now, Admitted: true, BudgetKnown: true}, nil
		},
		Run: func(ctx context.Context, _ quota.Paths, _ string, _ time.Time) error {
			select {
			case started <- struct{}{}:
			default:
			}
			<-ctx.Done()
			return ctx.Err()
		},
		Observe: observeForApp(st),
	})
	t.Cleanup(s.Close)
	s.StartAutomatic()
	return s, started
}

func codexObserveOutcome(s *appserver.RefreshScheduler) appserver.ObserveOutcome {
	var outcome appserver.ObserveOutcome
	for _, d := range s.ObserveDecisions() {
		if d.Source == "codex" {
			outcome = d.Outcome
		}
	}
	return outcome
}

// G3-85: Codex local history allowed and heavily used, yet observed/ had no perf.json because
// observation waited for an idle scheduler that a stuck refresh read never gave it.
func TestAppObservationWritesPerfWhileARefreshJobIsPending(t *testing.T) {
	st := observeCadenceHome(t, true)
	s, started := startObserveScheduler(t, st)
	select {
	case <-started:
	case <-time.After(5 * time.Second):
		t.Fatal("the refresh read did not start")
	}
	perf := filepath.Join(st.Dir, "observed", "perf.json")
	deadline := time.Now().Add(5 * time.Second)
	for {
		_, err := os.Stat(perf)
		if err == nil && codexObserveOutcome(s) == appserver.ObserveRan {
			break
		}
		if time.Now().After(deadline) {
			t.Fatalf("perf.json was not written within the cadence (stat: %v, decisions: %+v)", err, s.ObserveDecisions())
		}
		time.Sleep(10 * time.Millisecond)
	}
	if _, err := os.Stat(filepath.Join(st.Dir, "observed", appserver.ObserveLogFile)); err != nil {
		t.Fatalf("observation log: %v", err)
	}
}

func TestAppObservationRecordsConsentSkipAndWritesNothing(t *testing.T) {
	st := observeCadenceHome(t, false)
	s, _ := startObserveScheduler(t, st)
	deadline := time.Now().Add(5 * time.Second)
	for len(s.ObserveDecisions()) < 5 || codexObserveOutcome(s) != appserver.ObserveSkippedConsent {
		if time.Now().After(deadline) {
			t.Fatalf("no consent skip recorded: %+v", s.ObserveDecisions())
		}
		time.Sleep(10 * time.Millisecond)
	}
	// Let a few more passes run before checking nothing was written.
	time.Sleep(100 * time.Millisecond)
	for _, d := range s.ObserveDecisions() {
		if d.Outcome != appserver.ObserveSkippedConsent {
			t.Fatalf("%s observed without its grant: %+v", d.Source, d)
		}
	}
	for _, name := range []string{"perf.json", "speed.json"} {
		if _, err := os.Stat(filepath.Join(st.Dir, "observed", name)); !os.IsNotExist(err) {
			t.Fatalf("%s written without the Codex grant: %v %+v", name, err, s.ObserveDecisions())
		}
	}
}

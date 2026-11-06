// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// G3-13: an old successful runtime capture cannot suppress the explicitly
// granted local fallback while the next runtime attempt is deferred.
func TestAutomaticFallsBackWhenCodexRuntimeIsThreeHoursOld(t *testing.T) {
	backend, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		state.Scopes[consent.ScopeCodexRuntimeUsage] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	admission := consent.Capture()
	backend.view.Stamp = stampOfFence(admission.Fence())
	backend.view.Scopes = []string{consent.ScopeCodexRuntimeUsage, consent.ScopeCodexLocalHistory}
	now := time.Now().UTC()
	old := now.Add(-3 * time.Hour)
	snapshot := map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": old, "admission": admission.State().CaptureStamp(consent.ScopeCodexRuntimeUsage), "windows": []any{map[string]any{"kind": "weekly", "usedPercent": 20, "observedAt": old}}}
	b, err := json.Marshal(snapshot)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(cache, "observed", "codex-account.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, b, 0600); err != nil {
		t.Fatal(err)
	}
	calls := make(chan string, 2)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Now: func() time.Time { return now },
		Plan: func(_ quota.Paths, scope string, at time.Time) (quota.ScopeRefreshPlan, error) {
			if scope == consent.ScopeCodexRuntimeUsage {
				at = at.Add(30 * time.Minute)
			}
			return quota.ScopeRefreshPlan{At: at, Admitted: true, BudgetKnown: true}, nil
		},
		Run: func(_ context.Context, _ quota.Paths, scope string, _ time.Time) error { calls <- scope; return nil },
	})
	defer s.Close()
	s.StartAutomatic()
	select {
	case scope := <-calls:
		if scope != consent.ScopeCodexLocalHistory {
			t.Fatalf("wrong scope: %s", scope)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("three-hour-old runtime capture suppressed permitted local fallback")
	}
}

// A usable, explicitly granted runtime suppresses the local fallback at the
// scheduler boundary, even when both routes are granted.
func TestAutomaticFreshCodexRuntimeSuppressesLocalFallback(t *testing.T) {
	backend, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		state.Scopes[consent.ScopeCodexRuntimeUsage] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	admission := consent.Capture()
	backend.view.Stamp = stampOfFence(admission.Fence())
	backend.view.Scopes = []string{consent.ScopeCodexRuntimeUsage, consent.ScopeCodexLocalHistory}
	now := time.Now().UTC()
	snapshot := map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": now, "admission": admission.State().CaptureStamp(consent.ScopeCodexRuntimeUsage), "windows": []any{map[string]any{"kind": "weekly", "usedPercent": 20, "observedAt": now}}}
	b, err := json.Marshal(snapshot)
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(cache, "observed", "codex-account.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, b, 0600); err != nil {
		t.Fatal(err)
	}
	planned := make(chan string, 4)
	calls := make(chan string, 4)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Now: func() time.Time { return now },
		Plan: func(_ quota.Paths, scope string, at time.Time) (quota.ScopeRefreshPlan, error) {
			planned <- scope
			return quota.ScopeRefreshPlan{At: at.Add(30 * time.Minute), Admitted: true, BudgetKnown: true}, nil
		},
		Run: func(_ context.Context, _ quota.Paths, scope string, _ time.Time) error { calls <- scope; return nil },
	})
	defer s.Close()
	s.StartAutomatic()
	select {
	case scope := <-planned:
		if scope != consent.ScopeCodexRuntimeUsage {
			t.Fatalf("unexpected planned scope: %s", scope)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("runtime was not considered")
	}
	select {
	case scope := <-planned:
		t.Fatalf("fresh runtime did not suppress another scope: %s", scope)
	case scope := <-calls:
		t.Fatalf("unexpected read: %s", scope)
	case <-time.After(150 * time.Millisecond):
	}
}

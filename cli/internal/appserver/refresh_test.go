// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func refreshFixture(t *testing.T, scope string) (*memoryBackend, func(consent.Admission) quota.Paths, string) {
	t.Helper()
	testenv.IsolateHome(t)
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	definition, _ := consent.Definition(scope)
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		return consent.Set(state, definition.Tool, true, "native:"+definition.Tool, quota.BackendNative, time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	paths := func(admission consent.Admission) quota.Paths {
		return quota.ProductionPathsWithAdmission(cache, "1.0.0", admission)
	}
	backend := newMemoryBackend()
	backend.view.Stamp = stampOfFence(consent.Capture().Fence())
	backend.view.Projection.ConsentGeneration = backend.view.Stamp.Generation
	backend.view.Scopes = []string{scope}
	return backend, paths, cache
}
func TestRefreshDeferralIsNormalAndDoesNotRun(t *testing.T) {
	for _, test := range []struct {
		name              string
		offline, readOnly bool
		scope             string
		reason            wire.RefreshDisabledReason
	}{
		{"offline", true, false, consent.ScopeCodexRuntimeUsage, wire.RefreshOffline}, {"read only", false, true, consent.ScopeCodexRuntimeUsage, wire.RefreshReadOnly}, {"pending POST", false, false, consent.ScopeGeminiAccountUsageSavedLogin, wire.RefreshReadOnly},
	} {
		t.Run(test.name, func(t *testing.T) {
			backend, paths, cache := refreshFixture(t, test.scope)
			scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Offline: test.offline, ReadOnly: test.readOnly, Run: func(context.Context, quota.Paths, string, time.Time) error { t.Error("deferred scope ran"); return nil }})
			defer scheduler.Close()
			result, _, err := scheduler.Request(context.Background(), wire.RefreshRequestParams{Scopes: []string{test.scope}})
			if err != nil || len(result) != 1 || result[0].DisabledReason == nil || *result[0].DisabledReason != test.reason {
				t.Fatalf("deferral was not a normal scheduled result: %+v %v", result, err)
			}
			if _, err := os.Stat(filepath.Join(cache, "observed")); !os.IsNotExist(err) {
				t.Fatal("deferred refresh wrote a reservation or capture")
			}
		})
	}
}
func TestRefreshQueueCoalescesProviderBeforeBudgetReservation(t *testing.T) {
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	started := make(chan struct{})
	release := make(chan struct{})
	scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Run: func(ctx context.Context, _ quota.Paths, _ string, _ time.Time) error {
		close(started)
		select {
		case <-release:
		case <-ctx.Done():
		}
		return nil
	}})
	defer scheduler.Close()
	first, _, err := scheduler.Request(context.Background(), wire.RefreshRequestParams{Scopes: []string{consent.ScopeCodexRuntimeUsage}})
	if err != nil || len(first) != 1 || first[0].DisabledReason != nil {
		t.Fatal(first, err)
	}
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("first job did not run")
	}
	second, _, err := scheduler.Request(context.Background(), wire.RefreshRequestParams{Scopes: []string{consent.ScopeCodexRuntimeUsage}})
	if err != nil || len(second) != 1 || second[0].DisabledReason == nil || *second[0].DisabledReason != wire.RefreshCooldown {
		t.Fatal("queued duplicate was not deferred", second, err)
	}
	close(release)
}
func TestRefreshPlanPreservesSharedCooldownWithoutCapture(t *testing.T) {
	backend, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	next := time.Now().Add(20 * time.Minute).UTC()
	path := filepath.Join(cache, "observed", "reader-attempts", "codex.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	body, _ := json.Marshal(map[string]any{"schemaVersion": 1, "nextAttemptAt": next})
	if err := os.WriteFile(path, body, 0600); err != nil {
		t.Fatal(err)
	}
	scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Run: func(context.Context, quota.Paths, string, time.Time) error { t.Error("closed budget ran"); return nil }})
	defer scheduler.Close()
	result, _, err := scheduler.Request(context.Background(), wire.RefreshRequestParams{Scopes: []string{consent.ScopeCodexRuntimeUsage}})
	if err != nil || len(result) != 1 || result[0].DisabledReason == nil || *result[0].DisabledReason != wire.RefreshCooldown || !result[0].At.Equal(next) {
		t.Fatal("persisted cooldown not returned", result, err)
	}
}
func TestRefreshReadersOffIsReadOnly(t *testing.T) {
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	t.Setenv("MODELPLAN_READERS", "off")
	scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Run: func(context.Context, quota.Paths, string, time.Time) error { t.Error("readers off ran"); return nil }})
	defer scheduler.Close()
	result, _, err := scheduler.Request(context.Background(), wire.RefreshRequestParams{Scopes: []string{consent.ScopeCodexRuntimeUsage}})
	if err != nil || len(result) != 1 || result[0].DisabledReason == nil || *result[0].DisabledReason != wire.RefreshReadOnly {
		t.Fatal("readers off was not deferred", result, err)
	}
}

func TestRefreshKnownDeferralRunsWhenDueWithoutBlockingAnotherProvider(t *testing.T) {
	backend, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		return consent.Set(state, "kiro", true, "native:kiro", quota.BackendNative, time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	backend.view.Stamp = stampOfFence(consent.Capture().Fence())
	backend.view.Projection.ConsentGeneration = backend.view.Stamp.Generation
	backend.view.Scopes = append(backend.view.Scopes, consent.ScopeKiroRuntimeUsage)
	due := time.Now().Add(time.Second).UTC()
	path := filepath.Join(cache, "observed", "reader-attempts", "codex.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(map[string]any{"schemaVersion": 1, "nextAttemptAt": due})
	if err := os.WriteFile(path, raw, 0600); err != nil {
		t.Fatal(err)
	}
	type event struct {
		scope string
		at    time.Time
	}
	events := make(chan event, 2)
	scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Run: func(_ context.Context, _ quota.Paths, scope string, _ time.Time) error {
		events <- event{scope: scope, at: time.Now()}
		return nil
	}})
	defer scheduler.Close()
	deferred, _, err := scheduler.Request(context.Background(), wire.RefreshRequestParams{Scopes: []string{consent.ScopeCodexRuntimeUsage}})
	if err != nil || deferred[0].DisabledReason == nil || *deferred[0].DisabledReason != wire.RefreshCooldown {
		t.Fatal("known cooldown not deferred", deferred, err)
	}
	immediate, _, err := scheduler.Request(context.Background(), wire.RefreshRequestParams{Scopes: []string{consent.ScopeKiroRuntimeUsage}})
	if err != nil || immediate[0].DisabledReason != nil {
		t.Fatal("independent due provider not scheduled", immediate, err)
	}
	select {
	case got := <-events:
		if got.scope != consent.ScopeKiroRuntimeUsage {
			t.Fatalf("cooldown blocked independent provider: %+v", got)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("independent provider stalled")
	}
	select {
	case got := <-events:
		if got.scope != consent.ScopeCodexRuntimeUsage || got.at.Before(due) {
			t.Fatalf("deferred job did not honor due time: %+v", got)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("accepted deferred job never ran")
	}
}

func TestDeferredRefreshRejectsRevokeAndEqualGenerationReset(t *testing.T) {
	for _, kind := range []string{"revoke", "equal-generation reset"} {
		t.Run(kind, func(t *testing.T) {
			backend, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
			before := consent.Capture().Fence()
			due := time.Now().Add(time.Second).UTC()
			path := filepath.Join(cache, "observed", "reader-attempts", "codex.json")
			if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
				t.Fatal(err)
			}
			body, _ := json.Marshal(map[string]any{"schemaVersion": 1, "nextAttemptAt": due})
			if err := os.WriteFile(path, body, 0600); err != nil {
				t.Fatal(err)
			}
			called := make(chan struct{}, 1)
			scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Run: func(context.Context, quota.Paths, string, time.Time) error { called <- struct{}{}; return nil }})
			defer scheduler.Close()
			if _, _, err := scheduler.Request(context.Background(), wire.RefreshRequestParams{Scopes: []string{consent.ScopeCodexRuntimeUsage}}); err != nil {
				t.Fatal(err)
			}
			if kind == "revoke" {
				if err := consent.Change(consent.Path(), func(state *consent.State) error { return consent.Set(state, "codex", false, "", "", time.Now()) }); err != nil {
					t.Fatal(err)
				}
			} else {
				after, err := consent.Reset(consent.Path())
				if err != nil {
					t.Fatal(err)
				}
				if after.Generation != before.Generation || after.StoreEpoch == before.StoreEpoch {
					t.Fatal("reset did not establish the equal-generation/different-epoch seam")
				}
			}
			select {
			case <-called:
				t.Fatal("queued read ran after permission context changed")
			case <-time.After(time.Until(due) + 50*time.Millisecond):
			}
		})
	}
}

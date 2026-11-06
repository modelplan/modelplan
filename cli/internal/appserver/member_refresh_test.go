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
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func memberFixture(t *testing.T) (*memoryBackend, func(consent.Admission) quota.Paths, string, wire.RefreshMember) {
	t.Helper()
	backend, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	ref := "0123456789abcdef"
	backend.view.Projection.Rows = []rows.Row{{ID: "codex", State: rows.StateFresh, Accounts: []rows.Account{{Route: rows.RouteRuntimeRPC, SubscriptionRef: &ref}}}}
	return backend, paths, cache, wire.RefreshMember{RowID: "codex", Route: rows.RouteRuntimeRPC, SubscriptionRef: ref}
}

func TestMemberRefreshStartsAndDefersFloor(t *testing.T) {
	backend, paths, _, member := memberFixture(t)
	called := make(chan string, 1)
	release := make(chan struct{})
	changed := make(chan struct{}, 1)
	now := time.Date(2026, time.January, 2, 12, 0, 0, 0, time.UTC)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Now: func() time.Time { return now }, Changed: func() {
		select {
		case changed <- struct{}{}:
		default:
		}
	}, Run: func(ctx context.Context, _ quota.Paths, scope string, _ time.Time) error {
		called <- scope
		select {
		case <-release:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	}})
	defer s.Close()
	result, _, err := s.RequestMember(context.Background(), member)
	if err != nil || result.Outcome != wire.MemberRefreshStarted {
		t.Fatalf("fresh member not started: %+v %v", result, err)
	}
	select {
	case scope := <-called:
		if scope != consent.ScopeCodexRuntimeUsage {
			t.Fatalf("wrong scope: %s", scope)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("member reader did not run")
	}
	result, _, err = s.RequestMember(context.Background(), member)
	if err != nil || result.Outcome != wire.MemberRefreshDeferred || result.Reason == nil || *result.Reason != wire.MemberRefreshBudget || result.NotBefore == nil || !result.NotBefore.Equal(now.Add(5*time.Minute)) {
		t.Fatalf("in-flight refresh not deferred: %+v %v", result, err)
	}
	close(release)
	deadline := time.NewTimer(10 * time.Second)
	defer deadline.Stop()
	for {
		s.mu.Lock()
		_, pending := s.pending["codex"]
		until := s.autoNext["codex"]
		s.mu.Unlock()
		if !pending && until.Equal(now.Add(5*time.Minute)) {
			break
		}
		select {
		case <-changed:
		case <-deadline.C:
			t.Fatal("member refresh did not finish and record its floor")
		}
	}
	result, _, err = s.RequestMember(context.Background(), member)
	if err != nil || result.Outcome != wire.MemberRefreshDeferred || result.Reason == nil || *result.Reason != wire.MemberRefreshFloor || result.NotBefore == nil || !result.NotBefore.Equal(now.Add(5*time.Minute)) {
		t.Fatalf("floor not enforced: %+v %v", result, err)
	}
}

func TestMemberRefreshDeniesUngrantedAndAmbiguous(t *testing.T) {
	backend, paths, _, member := memberFixture(t)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Run: func(context.Context, quota.Paths, string, time.Time) error {
		t.Error("ungranted member read")
		return nil
	}})
	defer s.Close()
	backend.view.Scopes = nil
	result, _, err := s.RequestMember(context.Background(), member)
	if err != nil || result.Outcome != wire.MemberRefreshDeferred || result.Reason == nil || *result.Reason != wire.MemberRefreshNotGranted {
		t.Fatalf("ungranted member: %+v %v", result, err)
	}
	backend.view.Scopes = []string{consent.ScopeCodexRuntimeUsage}
	other := "fedcba9876543210"
	backend.view.Projection.Rows[0].Accounts = append(backend.view.Projection.Rows[0].Accounts, rows.Account{Route: rows.RouteRuntimeRPC, SubscriptionRef: &other})
	result, _, err = s.RequestMember(context.Background(), member)
	if err != nil || result.Reason == nil || *result.Reason != wire.MemberRefreshNotGranted {
		t.Fatalf("ambiguous provider route: %+v %v", result, err)
	}
}

func TestMemberRefreshUsesPersistedFloor(t *testing.T) {
	backend, paths, cache, member := memberFixture(t)
	now := time.Now().UTC().Truncate(time.Second)
	path := filepath.Join(cache, "observed", "codex-account.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	data, _ := json.Marshal(map[string]any{"schemaVersion": 1, "observedAt": now, "status": "ok"})
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Now: func() time.Time { return now }, Run: func(context.Context, quota.Paths, string, time.Time) error { t.Error("floor bypassed"); return nil }})
	defer s.Close()
	result, _, err := s.RequestMember(context.Background(), member)
	if err != nil || result.Reason == nil || *result.Reason != wire.MemberRefreshFloor || result.NotBefore == nil || !result.NotBefore.Equal(now.Add(5*time.Minute)) {
		t.Fatalf("persisted floor lost: %+v %v", result, err)
	}
}

func TestMemberRefreshRejectsVariantWithoutCapabilityOrWithScopes(t *testing.T) {
	backend, paths, _, member := memberFixture(t)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths})
	defer s.Close()
	data, _ := json.Marshal(map[string]any{"member": member})
	if _, err := s.Handler().Handle(context.Background(), data, Stamp{}); err == nil {
		t.Fatal("member variant accepted without capability")
	}
	ctx := context.WithValue(context.Background(), memberRefreshContextKey{}, true)
	data, _ = json.Marshal(map[string]any{"member": member, "scopes": []string{}})
	if _, err := s.Handler().Handle(ctx, data, Stamp{}); err == nil {
		t.Fatal("mixed variants accepted")
	}
	if _, err := s.Handler().Handle(ctx, json.RawMessage(`{"member":null}`), Stamp{}); err == nil {
		t.Fatal("null member treated as all scopes")
	}
}

func TestMemberRefreshPreservesPersistedBackoff(t *testing.T) {
	backend, paths, cache, member := memberFixture(t)
	now := time.Now().UTC().Truncate(time.Second)
	path := filepath.Join(cache, "observed", "codex-account.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	data, _ := json.Marshal(map[string]any{"schemaVersion": 1, "observedAt": now, "status": "error"})
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Now: func() time.Time { return now }, Run: func(context.Context, quota.Paths, string, time.Time) error { t.Error("backoff bypassed"); return nil }})
	defer s.Close()
	result, _, err := s.RequestMember(context.Background(), member)
	if err != nil || result.Reason == nil || *result.Reason != wire.MemberRefreshBackoff || result.NotBefore == nil || !result.NotBefore.Equal(now.Add(30*time.Minute)) {
		t.Fatalf("persisted backoff lost: %+v %v", result, err)
	}
}

func TestMatchingMemberCountSeparatesAccountsAndRoutes(t *testing.T) {
	first, second := "0123456789abcdef", "fedcba9876543210"
	view := View{Projection: rows.Projection{Rows: []rows.Row{{ID: "claude", Accounts: []rows.Account{
		{Route: rows.RouteSavedLoginAPI, AccountLocator: &first},
		{Route: rows.RouteSavedLoginAPI, AccountLocator: &second},
		{Route: rows.RouteLocalLog, AccountLocator: &second},
	}}}}}
	member := wire.RefreshMember{RowID: "claude", Route: rows.RouteSavedLoginAPI, AccountLocator: second}
	matches, routes := matchingMemberCount(view, member)
	if matches != 1 || routes != 2 {
		t.Fatalf("wrong member selection: matches=%d routes=%d", matches, routes)
	}
	member.AccountLocator = "aaaaaaaaaaaaaaaa"
	if matches, _ := matchingMemberCount(view, member); matches != 0 {
		t.Fatal("unknown member matched")
	}
}

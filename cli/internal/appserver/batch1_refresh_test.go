package appserver

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Exercise the report's stated interleaving: the running job is no longer in
// scheduled when automatic refresh processes a new consent generation.
func TestRunningRefreshRetainsPendingAcrossConsentChange(t *testing.T) {
	backend, paths, _, member := memberFixture(t)
	started := make(chan struct{})
	release := make(chan struct{})
	autoPass := make(chan struct{}, 1)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths,
		Plan: func(p quota.Paths, scope string, at time.Time) (quota.ScopeRefreshPlan, error) {
			if scope == consent.ScopeKiroRuntimeUsage {
				select {
				case autoPass <- struct{}{}:
				default:
				}
			}
			return quota.PlanScopeRefresh(p, scope, at)
		},
		Run: func(ctx context.Context, _ quota.Paths, _ string, _ time.Time) error {
			close(started)
			select {
			case <-release:
			case <-ctx.Done():
			}
			return nil
		},
	})
	defer s.Close()
	result, _, err := s.RequestMember(context.Background(), member)
	if err != nil || result.Outcome != wire.MemberRefreshStarted {
		t.Fatalf("initial request: %+v %v", result, err)
	}
	select {
	case <-started:
	case <-time.After(3 * time.Second):
		t.Fatal("reader did not start")
	}
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		return consent.Set(state, "kiro", true, "native:kiro", quota.BackendNative, time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	backend.mu.Lock()
	backend.view.Stamp = stampOfFence(consent.Capture().Fence())
	backend.view.Scopes = append(backend.view.Scopes, consent.ScopeKiroRuntimeUsage)
	backend.mu.Unlock()
	s.StartAutomatic()
	select {
	case <-autoPass:
	case <-time.After(3 * time.Second):
		t.Fatal("automatic pass did not run")
	}
	result, _, err = s.RequestMember(context.Background(), member)
	if err != nil || result.Outcome != wire.MemberRefreshDeferred {
		t.Fatalf("running request lost pending: %+v %v", result, err)
	}
	close(release)
}

func TestExpiredCredentialWaitDoesNotClearReplacement(t *testing.T) {
	backend, basePaths, _ := refreshFixture(t, consent.ScopeClaudeAccountUsageSavedLogin)
	home, err := os.UserHomeDir()
	if err != nil {
		t.Fatal(err)
	}
	paths := func(a consent.Admission) quota.Paths {
		p := basePaths(a)
		p.ReaderAccess = &quota.ReaderAccess{Grants: map[string]quota.ReaderGrant{"claude": {SavedLogin: true, Keychain: true, Generation: "synthetic", Profiles: []quota.ReaderProfile{{Root: filepath.Join(home, ".claude")}}}}}
		return p
	}
	var clock atomic.Int64
	clock.Store(time.Now().Unix())
	entered, release, cleaned, proceed := make(chan struct{}), make(chan struct{}), make(chan struct{}), make(chan struct{})
	var waitCleanup atomic.Bool
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths,
		Now: func() time.Time { return time.Unix(clock.Load(), 0) },
		Plan: func(_ quota.Paths, _ string, at time.Time) (quota.ScopeRefreshPlan, error) {
			return quota.ScopeRefreshPlan{Admitted: true, BudgetKnown: true, At: at}, nil
		},
		Run: func(context.Context, quota.Paths, string, time.Time) error { return nil },
		CredentialRequest: func(CredentialNeed) (string, error) {
			close(entered)
			<-release
			return "", errors.New("synthetic timeout")
		},
		Changed: func() {
			if waitCleanup.Load() {
				close(cleaned)
				<-proceed
			}
		},
	})
	defer s.Close()
	params := wire.RefreshRequestParams{Scopes: []string{consent.ScopeClaudeAccountUsageSavedLogin}}
	first, _, err := s.Request(context.Background(), params)
	if err != nil || first[0].DisabledReason != nil {
		t.Fatalf("first: %+v %v", first, err)
	}
	select {
	case <-entered:
	case <-time.After(3 * time.Second):
		t.Fatal("credential request did not start")
	}
	clock.Add(int64(wire.RequestTimeout/time.Second) + 1)
	second, _, err := s.Request(context.Background(), params)
	if err != nil || second[0].DisabledReason != nil {
		t.Fatalf("replacement not queued: %+v %v", second, err)
	}
	waitCleanup.Store(true)
	close(release)
	select {
	case <-cleaned:
	case <-time.After(3 * time.Second):
		t.Fatal("old cleanup did not finish")
	}
	s.mu.Lock()
	_, pending := s.pending["claude"]
	_, queued := s.scheduled["claude"]
	s.mu.Unlock()
	waitCleanup.Store(false)
	close(proceed)
	if !pending || !queued {
		t.Fatalf("replacement lost guard: pending=%v queued=%v", pending, queued)
	}
}

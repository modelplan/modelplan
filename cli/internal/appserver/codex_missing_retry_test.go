// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

// A first read that finds no Codex executable records a failure without returning an error;
// the scheduler still follows the first-read retry schedule, not the success floor (audit C, P2).
func TestMissingCodexFollowsFirstReadRetry(t *testing.T) {
	backend, paths, cache, member := memberFixture(t)
	now := time.Now().UTC().Truncate(time.Second)
	changed := make(chan struct{}, 1)
	ran := make(chan error, 1)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Now: func() time.Time { return now }, Changed: func() {
		select {
		case changed <- struct{}{}:
		default:
		}
	}, Run: func(ctx context.Context, _ quota.Paths, _ string, started time.Time) error {
		err := quota.RefreshCodexAccount(ctx, cache, "", started) // no executable found
		ran <- err
		return err
	}})
	defer s.Close()
	if _, _, err := s.RequestMember(context.Background(), member); err != nil {
		t.Fatal(err)
	}
	select {
	case err := <-ran:
		if err != nil {
			t.Fatalf("missing executable returned %v; the fixture expects the cached failure", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("reader did not run")
	}
	want := now.Add(quota.CodexFailureWait(cache))
	if want != now.Add(20*time.Second) {
		t.Fatalf("fixture: first-read retry = %v", want.Sub(now))
	}
	deadline := time.NewTimer(10 * time.Second)
	defer deadline.Stop()
	for {
		s.mu.Lock()
		_, pending := s.pending["codex"]
		until := s.autoNext["codex"]
		s.mu.Unlock()
		if !pending && !until.IsZero() {
			if !until.Equal(want) {
				t.Fatalf("next automatic read at +%v, want +%v", until.Sub(now), want.Sub(now))
			}
			return
		}
		select {
		case <-changed:
		case <-deadline.C:
			t.Fatal("refresh did not record its next read")
		}
	}
}

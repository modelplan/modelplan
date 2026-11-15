// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// G3-103 on the desktop (#911): after failed reads the scheduler queues Grok's next read at the
// back-off deadline. Signing in to Grok again changes no consent, so nothing dropped that job:
// the automatic pass skipped it as pending and a click was answered "cooldown" until the old
// deadline. A queued job now moves up when its plan becomes earlier. The plan itself is
// quota.PlanScopeRefresh, covered by TestG3103PlanScopeRefreshHonoursEarlyRetry.
func TestG3103QueuedReadMovesUpAfterNewSignIn(t *testing.T) {
	scope := consent.ScopeGrokAccountUsageSavedLogin
	for _, test := range []struct {
		name      string
		automatic bool
	}{{"clicked refresh", false}, {"automatic pass", true}} {
		t.Run(test.name, func(t *testing.T) {
			backend, paths, _ := refreshFixture(t, scope)
			clock := &syntheticRefreshClock{now: time.Date(2026, 10, 27, 12, 35, 0, 0, time.UTC)}
			var mu sync.Mutex
			deadline := clock.read().Add(35 * time.Minute) // the failure back-off ends at minute 70
			runs := make(chan string, 8)
			s := NewRefreshScheduler(context.Background(), RefreshConfig{
				Backend: backend, Paths: paths, Now: clock.read,
				Plan: func(_ quota.Paths, planned string, at time.Time) (quota.ScopeRefreshPlan, error) {
					mu.Lock()
					defer mu.Unlock()
					if deadline.After(at) {
						at = deadline
					}
					definition, _ := consent.Definition(planned)
					return quota.ScopeRefreshPlan{Provider: definition.Tool, At: at, Admitted: true, BudgetKnown: true}, nil
				},
				Run: func(_ context.Context, _ quota.Paths, ran string, _ time.Time) error {
					runs <- ran
					return nil
				},
			})
			defer s.Close()
			result, _, err := s.Request(context.Background(), wire.RefreshRequestParams{Scopes: []string{scope}})
			if err != nil || len(result) != 1 || result[0].DisabledReason == nil || *result[0].DisabledReason != wire.RefreshCooldown || !result[0].At.Equal(deadline) {
				t.Fatalf("setup: %+v %v", result, err)
			}
			select {
			case ran := <-runs:
				t.Fatalf("setup: %s ran inside the back-off", ran)
			case <-time.After(50 * time.Millisecond):
			}
			// The user signs in to Grok again: the plan is due now.
			mu.Lock()
			deadline = clock.read()
			mu.Unlock()
			if test.automatic {
				s.StartAutomatic()
			} else {
				result, _, err = s.Request(context.Background(), wire.RefreshRequestParams{Scopes: []string{scope}})
				if err != nil || len(result) != 1 || result[0].DisabledReason != nil {
					t.Fatalf("the click was answered with the old back-off: %+v %v", result, err)
				}
			}
			timeout := time.After(3 * time.Second)
			for {
				select {
				case ran := <-runs:
					if ran == scope {
						return
					}
				case <-timeout:
					t.Fatal("the queued read kept the old deadline")
				}
			}
		})
	}
}

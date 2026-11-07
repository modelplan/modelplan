// SPDX-License-Identifier: MIT
package appserver

import (
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// StartAutomatic begins on the first initialized client session. The native
// client's lifecycle stops the server on sleep and starts a new session on wake.
func (s *RefreshScheduler) StartAutomatic() {
	s.autoOnce.Do(func() {
		s.mu.Lock()
		s.autoStarted = true
		s.mu.Unlock()
		go s.automatic()
	})
}

func (s *RefreshScheduler) automatic() {
	defer close(s.autoDone)
	first := true
	var previous Stamp
	var nextObserve time.Time
	for s.ctx.Err() == nil {
		now := s.now()
		admission := consent.Capture()
		stamp := stampOfFence(admission.Fence())
		if stamp != previous {
			s.mu.Lock()
			s.autoNext = map[string]time.Time{}
			s.autoReason = map[string]wire.MemberRefreshReason{}
			for key, job := range s.scheduled {
				if job.stamp != stamp {
					delete(s.scheduled, key)
					delete(s.pending, key)
				}
			}
			s.signal()
			s.mu.Unlock()
			previous = stamp
		}
		state, mode := admission.State(), admission.Mode()
		scopes := liveRefreshScopes(state, mode)
		runtimeGranted := false
		for i := 0; i < len(scopes); i++ {
			if scopes[i] == consent.ScopeCodexRuntimeUsage {
				if quota.CodexAccountOff() { // the environment keeps Codex to its logs
					scopes = append(scopes[:i], scopes[i+1:]...)
					i--
					continue
				}
				runtimeGranted = true
			}
		}
		if !s.config.Offline && !s.config.ReadOnly && state.AllowsScope(consent.ScopeCodexLocalHistory, mode) &&
			(!runtimeGranted || !quota.CodexRuntimeAvailable(s.paths(admission).Cache, admission, now)) {
			scopes = append(scopes, consent.ScopeCodexLocalHistory)
		}
		next := now.Add(time.Minute)
		if first && (s.config.Offline || s.config.ReadOnly || s.config.Run == nil) {
			reason := refreshReadOnly
			if s.config.Offline {
				reason = refreshOffline
			}
			for _, scope := range scopes {
				s.decisions.add(now, scope, refreshNotAttempted, reason)
			}
		}
		if !s.config.Offline && !s.config.ReadOnly && s.config.Run != nil {
			for _, scope := range scopes {
				definition, _ := consent.Definition(scope)
				key := definition.Tool
				if definition.Class == consent.Local {
					key = scope
				}
				s.mu.Lock()
				until := s.autoNext[key]
				_, pending := s.pending[key]
				s.mu.Unlock()
				if pending {
					continue
				}
				if until.After(now) {
					if until.Before(next) {
						next = until
					}
					continue
				}
				result, _, err := s.Request(s.ctx, wire.RefreshRequestParams{Scopes: []string{scope}})
				outcome, reason := refreshNotAttempted, refreshUnavailable
				if err == nil && len(result) == 1 {
					if result[0].DisabledReason == nil {
						outcome, reason = refreshDeferred, refreshDue
						if first {
							reason = refreshStartup
						}
					} else if *result[0].DisabledReason == wire.RefreshCooldown {
						outcome, reason = refreshDeferred, refreshBudget
					}
				}
				s.decisions.add(now, scope, outcome, reason)
			}
		}
		first = false
		if s.config.Observe != nil && !s.config.Offline && !s.config.ReadOnly {
			// Local writes skip rather than wait for the reader lock, so go when no read holds it.
			// The end of each read wakes this loop.
			s.mu.Lock()
			idle := len(s.pending) == 0
			s.mu.Unlock()
			if idle && !now.Before(nextObserve) {
				s.config.Observe(s.paths(admission), now)
				nextObserve = now.Add(observeEvery)
				if s.config.Changed != nil {
					s.config.Changed()
				}
			}
			if nextObserve.Before(next) {
				next = nextObserve
			}
		}
		wait := next.Sub(s.now())
		if wait < 0 {
			wait = 0
		}
		timer := time.NewTimer(wait)
		select {
		case <-s.ctx.Done():
			timer.Stop()
			return
		case <-s.autoWake:
			timer.Stop()
		case <-timer.C:
		}
	}
}

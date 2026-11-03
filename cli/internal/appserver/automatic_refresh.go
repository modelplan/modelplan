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
	for s.ctx.Err() == nil {
		now := time.Now()
		admission := consent.Capture()
		state, mode := admission.State(), admission.Mode()
		scopes := liveRefreshScopes(state, mode)
		runtimeGranted := false
		for _, scope := range scopes { if scope == consent.ScopeCodexRuntimeUsage { runtimeGranted = true } }
		local, decided := state.Scopes[consent.ScopeCodexLocalHistory]
		if decided && local.Allowed && state.AllowsScope(consent.ScopeCodexLocalHistory, mode) &&
			(!runtimeGranted || !quota.CodexRuntimeAvailable(s.paths(admission).Cache, admission)) {
			scopes = append(scopes, consent.ScopeCodexLocalHistory)
		}
		next := now.Add(time.Minute)
		if !s.config.Offline && !s.config.ReadOnly && s.config.Run != nil {
			for _, scope := range scopes {
				definition, _ := consent.Definition(scope)
				key := definition.Tool
				if definition.Class == consent.Local { key = scope }
				s.mu.Lock()
				until := s.autoNext[key]
				_, pending := s.pending[key]
				s.mu.Unlock()
				if pending { continue }
				if until.After(now) {
					if until.Before(next) { next = until }
					continue
				}
				result, _, err := s.Request(s.ctx, wire.RefreshRequestParams{Scopes: []string{scope}})
				outcome, reason := refreshNotAttempted, refreshUnavailable
				if err == nil && len(result) == 1 {
					if result[0].DisabledReason == nil {
						outcome, reason = refreshDeferred, refreshDue
					} else if *result[0].DisabledReason == wire.RefreshCooldown {
						outcome, reason = refreshDeferred, refreshBudget
					}
				}
				s.decisions.add(now, scope, outcome, reason)
			}
		}
		wait := time.Until(next)
		if wait < 0 { wait = 0 }
		timer := time.NewTimer(wait)
		select {
		case <-s.ctx.Done(): timer.Stop(); return
		case <-s.autoWake: timer.Stop()
		case <-timer.C:
		}
	}
}

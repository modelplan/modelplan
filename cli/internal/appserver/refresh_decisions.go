// SPDX-License-Identifier: MIT
package appserver

import (
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

type refreshOutcome string
type refreshReason string

const (
	refreshNotAttempted refreshOutcome = "not_attempted"
	refreshDeferred     refreshOutcome = "deferred"
	refreshFailed       refreshOutcome = "failed"
	refreshSucceeded    refreshOutcome = "succeeded"

	refreshStartup     refreshReason = "startup"
	refreshWake        refreshReason = "wake"
	refreshDue         refreshReason = "due"
	refreshNotGranted  refreshReason = "not_granted"
	refreshOffline     refreshReason = "offline"
	refreshReadOnly    refreshReason = "read_only"
	refreshBudget      refreshReason = "budget"
	refreshInFlight    refreshReason = "in_flight"
	refreshUnavailable refreshReason = "unavailable"
	refreshCompleted   refreshReason = "completed"
)

type refreshDecision struct {
	at      time.Time
	scope   string
	outcome refreshOutcome
	reason  refreshReason
}

type relativeRefreshDecision struct {
	AgoSeconds int64
	Scope      string
	Outcome    refreshOutcome
	Reason     refreshReason
}

// refreshDecisionRing contains only allow-listed codes and a process-local time.
// It has no provider values, identities, paths, or error strings.
type refreshDecisionRing struct {
	mu    sync.Mutex
	items [20]refreshDecision
	next  int
	count int
}

func (r *refreshDecisionRing) add(at time.Time, scope string, outcome refreshOutcome, reason refreshReason) {
	if !validRefreshDecision(scope, outcome, reason) {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items[r.next] = refreshDecision{at: at, scope: scope, outcome: outcome, reason: reason}
	r.next = (r.next + 1) % len(r.items)
	if r.count < len(r.items) {
		r.count++
	}
}

func validRefreshDecision(scope string, outcome refreshOutcome, reason refreshReason) bool {
	switch scope {
	case consent.ScopeCodexRuntimeUsage, consent.ScopeCodexLocalHistory,
		consent.ScopeClaudeAccountUsageSavedLogin, consent.ScopeGeminiAccountUsageSavedLogin,
		consent.ScopeCursorAccountUsageSavedLogin, consent.ScopeCopilotRuntimeUsage,
		consent.ScopeKimiAccountUsageSavedLogin, consent.ScopeGrokAccountUsageSavedLogin,
		consent.ScopeKiroRuntimeUsage, consent.ScopeAntigravityRuntimeUsage,
		consent.ScopeZaiAccountUsageAPIKey, consent.ScopeMiniMaxAccountUsageAPIKey,
		consent.ScopeOpenCodeGoAccountUsageAPIKey:
	default:
		return false
	}
	switch outcome {
	case refreshNotAttempted, refreshDeferred, refreshFailed, refreshSucceeded:
	default:
		return false
	}
	switch reason {
	case refreshStartup, refreshWake, refreshDue, refreshNotGranted, refreshOffline,
		refreshReadOnly, refreshBudget, refreshInFlight, refreshUnavailable, refreshCompleted:
		return true
	default:
		return false
	}
}

func (r *refreshDecisionRing) snapshot(now time.Time) []relativeRefreshDecision {
	r.mu.Lock()
	defer r.mu.Unlock()
	result := make([]relativeRefreshDecision, 0, r.count)
	for i := 0; i < r.count; i++ {
		item := r.items[(r.next-r.count+i+len(r.items))%len(r.items)]
		seconds := int64(now.Sub(item.at).Seconds())
		if seconds < 0 {
			seconds = 0
		}
		result = append(result, relativeRefreshDecision{AgoSeconds: seconds, Scope: item.scope, Outcome: item.outcome, Reason: item.reason})
	}
	return result
}

func (r *refreshDecisionRing) clear() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items = [20]refreshDecision{}
	r.next, r.count = 0, 0
}

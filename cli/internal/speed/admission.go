// SPDX-License-Identifier: MIT
package speed

import (
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// GrantEpoch is private cache provenance: the consent store epoch and the
// source scope's revoke watermark. Changes to unrelated grants do not change it.
type GrantEpoch struct {
	StoreEpoch        string `json:"storeEpoch"`
	RevokedGeneration uint64 `json:"revokedGeneration"`
}

func sourceScope(source string) string {
	return map[string]string{
		"claude-code": consent.ScopeClaudeLocalHistory,
		"codex":       consent.ScopeCodexLocalHistory,
		"zcode":       consent.ScopeZaiLocalHistory,
		"opencode":    consent.ScopeOpenCodeGoLocalHistory,
	}[source]
}

func currentEpoch(a consent.Admission, source string) *GrantEpoch {
	scope := sourceScope(source)
	state := a.State()
	tool, _, _ := strings.Cut(scope, ".")
	if scope == "" || state.StoreEpoch == "" || !state.AllowsScope(scope, a.Mode()) || a.CleanupPending(scope) || a.CleanupPending(tool) {
		return nil
	}
	if state.Revoked[scope] > 0 && state.Scopes[scope].At.IsZero() {
		return nil
	}
	return &GrantEpoch{StoreEpoch: state.StoreEpoch, RevokedGeneration: state.Revoked[scope]}
}

// grantStart keeps a newly authorized scan from reclassifying observations
// collected before the latest grant as new. Implicit first grants have no time.
func grantStart(a consent.Admission, source string) time.Time {
	return a.State().Scopes[sourceScope(source)].At
}

func sameEpoch(a, b *GrantEpoch) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	return *a == *b
}

// Admitted returns a copy containing only records made in the current grant
// epoch. Legacy unstamped records and records from denied scopes fail closed.
func (v PerfView) Admitted(a consent.Admission) PerfView {
	allowed := func(source string, stamp *GrantEpoch) bool {
		current := currentEpoch(a, source)
		return stamp != nil && current != nil && sameEpoch(stamp, current)
	}
	l := v.Ledger
	l.Rows = nil
	for _, r := range v.Ledger.Rows {
		if allowed(r.Source, r.GrantEpoch) {
			l.Rows = append(l.Rows, r)
		}
	}
	l.Hourly = nil
	for _, r := range v.Ledger.Hourly {
		if allowed(r.Source, r.GrantEpoch) {
			l.Hourly = append(l.Hourly, r)
		}
	}
	l.Live = nil
	for _, r := range v.Ledger.Live {
		if allowed(r.Source, r.GrantEpoch) {
			l.Live = append(l.Live, r)
		}
	}
	l.Sessions = nil
	for _, r := range v.Ledger.Sessions {
		if allowed(r.Source, r.GrantEpoch) {
			l.Sessions = append(l.Sessions, r)
		}
	}
	v.Ledger = l
	return v
}

// LegacyAdmitted withholds denied or cleanup-pending sources even while old
// unstamped caches remain readable for other sources. The legacy desktop output
// uses these views while a cleanup retry is pending.
func LegacyAdmitted(ledger Ledger, perf PerfLedger, long LongLedger, admission consent.Admission) (Ledger, PerfLedger, LongLedger) {
	allowed := func(source string) bool {
		scope := sourceScope(source)
		tool, _, _ := strings.Cut(scope, ".")
		return scope != "" && admission.State().AllowsScope(scope, admission.Mode()) && !admission.CleanupPending(scope) && !admission.CleanupPending(tool)
	}
	rows := make([]Row, 0, len(ledger.Rows))
	for _, r := range ledger.Rows { if allowed(r.Source) { rows = append(rows, r) } }
	ledger.Rows = rows
	perfRows := make([]PerfRow, 0, len(perf.Rows))
	for _, r := range perf.Rows { if allowed(r.Source) { perfRows = append(perfRows, r) } }
	perf.Rows = perfRows
	hourly := make([]Hourly, 0, len(perf.Hourly))
	for _, r := range perf.Hourly { if allowed(r.Source) { hourly = append(hourly, r) } }
	perf.Hourly = hourly
	live := make([]LiveRecord, 0, len(perf.Live))
	for _, r := range perf.Live { if allowed(r.Source) { live = append(live, r) } }
	perf.Live = live
	sessions := make([]PerfSession, 0, len(perf.Sessions))
	for _, r := range perf.Sessions { if allowed(r.Source) { sessions = append(sessions, r) } }
	perf.Sessions = sessions
	longRows := make([]Daily, 0, len(long.Rows))
	for _, r := range long.Rows { if allowed(r.Source) { longRows = append(longRows, r) } }
	long.Rows = longRows
	return ledger, perf, long
}

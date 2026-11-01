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
	StoreEpoch string `json:"storeEpoch"`
	RevokedGeneration uint64 `json:"revokedGeneration"`
}

func sourceScope(source string) string {
	return map[string]string{
		"claude-code": consent.ScopeClaudeLocalHistory,
		"codex": consent.ScopeCodexLocalHistory,
		"zcode": consent.ScopeZaiLocalHistory,
		"opencode": consent.ScopeOpenCodeGoLocalHistory,
	}[source]
}

func currentEpoch(a consent.Admission, source string) *GrantEpoch {
	scope := sourceScope(source)
	state := a.State()
	tool, _, _ := strings.Cut(scope, ".")
	if scope == "" || state.StoreEpoch == "" || !state.AllowsScope(scope, a.Mode()) || a.CleanupPending(scope) || a.CleanupPending(tool) {
		return nil
	}
	if state.Revoked[scope] > 0 && state.Scopes[scope].At.IsZero() { return nil }
	return &GrantEpoch{StoreEpoch: state.StoreEpoch, RevokedGeneration: state.Revoked[scope]}
}

// grantStart keeps a newly authorized scan from reclassifying observations
// collected before the latest grant as new. Implicit first grants have no time.
func grantStart(a consent.Admission, source string) time.Time {
	return a.State().Scopes[sourceScope(source)].At
}

func sameEpoch(a, b *GrantEpoch) bool {
	if a == nil || b == nil { return a == nil && b == nil }
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
	for _, r := range v.Ledger.Rows { if allowed(r.Source, r.GrantEpoch) { l.Rows = append(l.Rows, r) } }
	l.Hourly = nil
	for _, r := range v.Ledger.Hourly { if allowed(r.Source, r.GrantEpoch) { l.Hourly = append(l.Hourly, r) } }
	l.Live = nil
	for _, r := range v.Ledger.Live { if allowed(r.Source, r.GrantEpoch) { l.Live = append(l.Live, r) } }
	l.Sessions = nil
	for _, r := range v.Ledger.Sessions { if allowed(r.Source, r.GrantEpoch) { l.Sessions = append(l.Sessions, r) } }
	v.Ledger = l
	return v
}

// SPDX-License-Identifier: MIT
package appserver

import "github.com/modelplan/modelplan/cli/internal/consent"

// liveRefreshScopes is a closed list of quota routes. In particular it does not
// infer quota from local history, or treat an implicit runtime default as a grant.
// Every caller must still recheck the fence, admission and provider-wide budget
// at execution time.
func liveRefreshScopes(state consent.State, mode string) []string {
	candidates := []string{
		consent.ScopeCodexRuntimeUsage,
		consent.ScopeClaudeAccountUsageSavedLogin,
		consent.ScopeGeminiAccountUsageSavedLogin,
		consent.ScopeCursorAccountUsageSavedLogin,
		consent.ScopeCopilotRuntimeUsage,
		consent.ScopeKimiAccountUsageSavedLogin,
		consent.ScopeGrokAccountUsageSavedLogin,
		consent.ScopeKiroRuntimeUsage,
		consent.ScopeAntigravityRuntimeUsage,
		consent.ScopeZaiAccountUsageAPIKey,
		consent.ScopeMiniMaxAccountUsageAPIKey,
		consent.ScopeOpenCodeGoAccountUsageAPIKey,
	}
	var scopes []string
	for _, scope := range candidates {
		record, decided := state.Scopes[scope]
		if decided && record.Allowed && state.AllowsScope(scope, mode) {
			scopes = append(scopes, scope)
		}
	}
	return scopes
}

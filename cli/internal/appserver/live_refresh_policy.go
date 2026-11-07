// SPDX-License-Identifier: MIT
package appserver

import "github.com/modelplan/modelplan/cli/internal/consent"

// liveRefreshScopes is a closed list of quota routes. In particular it does not
// infer quota from local history. Standard routes that the compiled policy turns
// on by default (consent.ScopeDefinition.DefaultCheck, owner decision 2026-11-06:
// a tool's own runtime/local sign-in is read without a consent click) are live
// until the user turns them off; a recorded refusal, a tool-level denial,
// RequireConsent and readers-off still win, through consent.AllowsScope. Every
// caller must still recheck the fence, admission and provider-wide budget at
// execution time.
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
		if state.AllowsScope(scope, mode) {
			scopes = append(scopes, scope)
		}
	}
	return scopes
}

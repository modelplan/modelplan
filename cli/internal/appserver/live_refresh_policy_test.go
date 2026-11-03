// SPDX-License-Identifier: MIT
package appserver

import (
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestLiveRefreshScopesRequireExplicitCurrentGrant(t *testing.T) {
	scopes := []string{
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
	for _, scope := range scopes {
		t.Run(scope, func(t *testing.T) {
			state := consent.Empty()
			if got := liveRefreshScopes(state, consent.Automatic); len(got) != 0 {
				t.Fatalf("implicit defaults scheduled: %v", got)
			}
			state.Scopes[scope] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
			if got := liveRefreshScopes(state, consent.Automatic); len(got) != 1 || got[0] != scope {
				t.Fatalf("explicit grant not selected: %v", got)
			}
			if got := liveRefreshScopes(state, consent.Off); len(got) != 0 {
				t.Fatalf("readers off selected a scope: %v", got)
			}
			state.Scopes[scope] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
			if got := liveRefreshScopes(state, consent.Automatic); len(got) != 0 {
				t.Fatalf("denied scope selected: %v", got)
			}
			state.Scopes[scope] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion - 1}
			if got := liveRefreshScopes(state, consent.Automatic); len(got) != 0 {
				t.Fatalf("old consent text selected: %v", got)
			}
		})
	}
}

func TestLiveRefreshScopesExcludeLocalHistory(t *testing.T) {
	state := consent.Empty()
	for _, scope := range []string{consent.ScopeAmpLocalHistory, consent.ScopeDroidLocalHistory, consent.ScopeQwenLocalHistory, consent.ScopeOpenCodeV2LocalHistory, consent.ScopeCodexLocalHistory} {
		state.Scopes[scope] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
	}
	if got := liveRefreshScopes(state, consent.Automatic); len(got) != 0 {
		t.Fatalf("local histories selected as quota: %v", got)
	}
}

// SPDX-License-Identifier: MIT
package appserver

import (
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Owner decision 2026-11-06 (G3-19/G3-20): standard routes the compiled policy checks by
// default are live without a consent click; every other route needs an explicit grant, and a
// refusal, a tool-level denial, RequireConsent or readers-off always wins.
func TestLiveRefreshScopesHonourDefaultsAndExplicitGrants(t *testing.T) {
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
	selected := func(got []string, scope string) bool {
		for _, s := range got {
			if s == scope {
				return true
			}
		}
		return false
	}
	for _, scope := range scopes {
		t.Run(scope, func(t *testing.T) {
			definition, _ := consent.Definition(scope)
			state := consent.Empty()
			if got := liveRefreshScopes(state, consent.Automatic); selected(got, scope) != definition.DefaultCheck {
				t.Fatalf("undecided scope selected=%t, default=%t: %v", selected(got, scope), definition.DefaultCheck, got)
			}
			required := consent.Empty()
			required.RequireConsent = true
			if got := liveRefreshScopes(required, consent.Automatic); len(got) != 0 {
				t.Fatalf("RequireConsent still scheduled defaults: %v", got)
			}
			vetoed := consent.Empty()
			vetoed.Tools[definition.Tool] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
			if got := liveRefreshScopes(vetoed, consent.Automatic); selected(got, scope) {
				t.Fatalf("tool denial scheduled %s", scope)
			}
			state.Scopes[scope] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
			if got := liveRefreshScopes(state, consent.Automatic); !selected(got, scope) {
				t.Fatalf("explicit grant not selected: %v", got)
			}
			if got := liveRefreshScopes(state, consent.Off); len(got) != 0 {
				t.Fatalf("readers off selected a scope: %v", got)
			}
			state.Scopes[scope] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
			if got := liveRefreshScopes(state, consent.Automatic); selected(got, scope) {
				t.Fatalf("denied scope selected: %v", got)
			}
			state.Scopes[scope] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion - 1}
			if got := liveRefreshScopes(state, consent.Automatic); selected(got, scope) {
				t.Fatalf("old consent text selected: %v", got)
			}
		})
	}
}

func TestLiveRefreshScopesExcludeLocalHistory(t *testing.T) {
	state := consent.Empty()
	locals := []string{consent.ScopeAmpLocalHistory, consent.ScopeDroidLocalHistory, consent.ScopeQwenLocalHistory, consent.ScopeOpenCodeV2LocalHistory, consent.ScopeCodexLocalHistory}
	for _, scope := range locals {
		state.Scopes[scope] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
	}
	for _, got := range liveRefreshScopes(state, consent.Automatic) {
		for _, local := range locals {
			if got == local {
				t.Fatalf("local history selected as quota: %s", got)
			}
		}
	}
}

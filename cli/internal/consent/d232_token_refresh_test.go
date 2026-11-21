// SPDX-License-Identifier: MIT
package consent

import "testing"

// D232: the Gemini token-refresh scope is opt-in, never pre-selected, only effective together
// with the saved-login scope, and never stands for the tool's route by itself.
func TestD232GeminiTokenRefreshScopeIsAnOptInExtension(t *testing.T) {
	d, ok := Definition(ScopeGeminiAccountUsageTokenRefresh)
	if !ok || d.Tool != "gemini" || d.Class != Credential || d.DefaultCheck || d.Requires != ScopeGeminiAccountUsageSavedLogin || d.Route != "saved_login_api" {
		t.Fatalf("definition %+v", d)
	}
	allowed := Record{Allowed: true, ConsentTextVersion: TextVersion, Backend: "native", ReaderID: "native:gemini"}
	s := State{Tools: map[string]Record{}, Scopes: map[string]Record{}}
	if s.AllowsScope(ScopeGeminiAccountUsageTokenRefresh, Automatic) {
		t.Fatal("unset refresh scope allowed")
	}
	s.Scopes[ScopeGeminiAccountUsageTokenRefresh] = allowed
	syncScopeTool(&s, "gemini")
	if s.AllowsScope(ScopeGeminiAccountUsageTokenRefresh, Automatic) || s.Tools["gemini"].Allowed {
		t.Fatal("refresh without the saved-login scope allowed the tool or the refresh")
	}
	s.Scopes[ScopeGeminiAccountUsageSavedLogin] = allowed
	syncScopeTool(&s, "gemini")
	if !s.AllowsScope(ScopeGeminiAccountUsageTokenRefresh, Automatic) || !s.Tools["gemini"].Allowed || s.ScopeFor("gemini", Credential) != ScopeGeminiAccountUsageSavedLogin {
		t.Fatal("granted pair not effective, or the extension became the tool's route")
	}
	if s.AllowsScope(ScopeGeminiAccountUsageTokenRefresh, Passive) {
		t.Fatal("credential refresh allowed in passive mode")
	}
	stale := allowed
	stale.ConsentTextVersion = TextVersion - 1
	s.Scopes[ScopeGeminiAccountUsageTokenRefresh] = stale
	if s.AllowsScope(ScopeGeminiAccountUsageTokenRefresh, Automatic) {
		t.Fatal("outdated consent text accepted")
	}
}

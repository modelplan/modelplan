// SPDX-License-Identifier: MIT
package consent

import "testing"

// A legacy tool-level allow predates newer default-on scopes and must not switch them off.
func TestLegacyToolAllowKeepsDefaultOnScopes(t *testing.T) {
	s := Empty()
	s.Tools["codex"] = Record{Allowed: true, ConsentTextVersion: TextVersion}
	if !s.AllowsScope(ScopeCodexRuntimeUsage, Automatic) {
		t.Fatal("allowed tool record blocked a default-on scope")
	}
	for name, r := range map[string]Record{
		"denied":      {Allowed: false, ConsentTextVersion: TextVersion},
		"stale text":  {Allowed: true, ConsentTextVersion: TextVersion - 1},
		"source veto": {Allowed: true, ConsentTextVersion: TextVersion, DeniedSources: map[string]bool{Runtime: true}},
	} {
		s.Tools["codex"] = r
		if s.AllowsScope(ScopeCodexRuntimeUsage, Automatic) {
			t.Fatalf("%s tool record admitted the scope", name)
		}
	}
	s.Tools["cursor"] = Record{Allowed: true, ConsentTextVersion: TextVersion}
	if s.AllowsScope(ScopeCursorAccountUsageSavedLogin, Automatic) {
		t.Fatal("an allow must not widen a scope that is not default-on")
	}
}

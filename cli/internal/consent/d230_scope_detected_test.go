// SPDX-License-Identifier: MIT
package consent

import "testing"

// D230: a scope-id key narrows its tool's detection. OpenCode installed without an OpenCode Go key:
// local history stays detected, the OpenCode Go account path does not.
func TestD230ScopeKeyNarrowsToolDetection(t *testing.T) {
	facts := NewAdmission(Empty(), Automatic).ScopeFacts(map[string]bool{"opencodego": true, ScopeOpenCodeGoAccountUsageAPIKey: false})
	got := map[string]bool{}
	for _, f := range facts {
		if f.Tool == "opencodego" {
			got[f.Scope] = f.Detected
		}
	}
	if !got[ScopeOpenCodeGoLocalHistory] || got[ScopeOpenCodeGoAccountUsageAPIKey] {
		t.Fatalf("%v", got)
	}
	if _, listed := got[ScopeOpenCodeGoAccountUsageAPIKey]; !listed {
		t.Fatal("the path is still listed, only not detected")
	}
	// A scope key never turns on an undetected tool.
	for _, f := range NewAdmission(Empty(), Automatic).ScopeFacts(map[string]bool{ScopeOpenCodeGoAccountUsageAPIKey: true}) {
		if f.Tool == "opencodego" && f.Detected {
			t.Fatalf("%s detected without its tool", f.Scope)
		}
	}
}

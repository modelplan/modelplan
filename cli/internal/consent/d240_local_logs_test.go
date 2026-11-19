// SPDX-License-Identifier: MIT
package consent

import (
	"reflect"
	"testing"
)

// D240 (owner 2026-11-13): only local-log scopes (session/history logs on this Mac: no
// credential, no network call) of a later-installed tool are allowed automatically, and only
// while the user has made no decision for that tool. Saved-login, runtime and key scopes stay
// opt-in; OpenCode V2 history keeps its default-off decision.
func TestD240AutoLocalLogScopesAreLocalLogsOnly(t *testing.T) {
	s := Empty()
	got := AutoLocalLogScopes(s, map[string]bool{"gemini": true, "kiro": true, "antigravity": true, "minimax": true, "opencode": true, "cursor": true})
	want := []string{ScopeCursorLocalHistory, ScopeGeminiLocalHistory}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("auto scopes = %v, want %v", got, want)
	}
	for _, id := range got {
		if d, _ := Definition(id); d.Class != Local || d.Route != "local_log" || d.Keychain {
			t.Fatalf("%s is not a local-log scope: %+v", id, d)
		}
	}
	// A decided scope or a decided tool is never re-allowed.
	s.Scopes = map[string]Record{ScopeGeminiLocalHistory: {Allowed: false, ConsentTextVersion: TextVersion}}
	s.Tools = map[string]Record{"cursor": {Allowed: false, ConsentTextVersion: TextVersion}}
	if got := AutoLocalLogScopes(s, map[string]bool{"gemini": true, "cursor": true}); len(got) != 0 {
		t.Fatalf("decided tools re-allowed: %v", got)
	}
}

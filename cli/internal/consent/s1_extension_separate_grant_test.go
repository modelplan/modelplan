// SPDX-License-Identifier: MIT
package consent

import (
	"testing"
)

// Sampling 11-21 S1 (#928, D232): the Gemini token-refresh extension has its own opt-in. A bulk
// grant (first-run Done, Settings "On" for Gemini, "Select all") never grants it; only a grant
// that allows the extension by itself does. Denying it with the rest of the tool stays possible.
func TestS1TokenRefreshIsNeverGrantedInABulkAllow(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "")
	hooks := GrantHooks{Admit: func(ScopeDefinition) (Record, error) {
		return Record{ReaderID: "native:gemini", Backend: "native"}, nil
	}}
	apply := func(id string, allow, deny []string) (GrantReceipt, error) {
		s, err := EnsureStore(Path())
		if err != nil {
			t.Fatal(err)
		}
		return ApplyGrant(Path(), Grant{RequestID: id, ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: TextVersion, Allow: allow, Deny: deny}, hooks)
	}
	refreshAllowed := func() bool {
		s, err := Load(Path())
		if err != nil {
			t.Fatal(err)
		}
		_, decided := s.Scopes[ScopeGeminiAccountUsageTokenRefresh]
		return decided || s.AllowsScope(ScopeGeminiAccountUsageTokenRefresh, Automatic)
	}
	// What the app's first-run Done and Settings "On" sent for a ticked Gemini row before the fix.
	for _, bulk := range [][]string{
		{ScopeGeminiLocalHistory, ScopeGeminiAccountUsageSavedLogin, ScopeGeminiAccountUsageTokenRefresh},
		{ScopeGeminiAccountUsageSavedLogin, ScopeGeminiAccountUsageTokenRefresh},
		{ScopeClaudeLocalHistory, ScopeGeminiAccountUsageTokenRefresh},
	} {
		if receipt, err := apply("bulk", bulk, nil); err == nil || receipt.Committed {
			t.Fatalf("bulk allow %v committed %+v", bulk, receipt)
		}
		if refreshAllowed() {
			t.Fatalf("bulk allow %v recorded the refresh extension", bulk)
		}
	}
	if _, err := apply("standard", []string{ScopeGeminiLocalHistory, ScopeGeminiAccountUsageSavedLogin}, nil); err != nil {
		t.Fatal(err)
	}
	if refreshAllowed() {
		t.Fatal("ordinary Gemini consent granted token refresh")
	}
	// The separate, explicit opt-in.
	if receipt, err := apply("opt-in", []string{ScopeGeminiAccountUsageTokenRefresh}, nil); err != nil || !receipt.Committed {
		t.Fatal("separate opt-in refused", receipt, err)
	}
	if !refreshAllowed() {
		t.Fatal("separate opt-in not effective")
	}
	// Switching Gemini off refuses the extension together with the rest.
	if _, err := apply("off", nil, []string{ScopeGeminiLocalHistory, ScopeGeminiAccountUsageSavedLogin, ScopeGeminiAccountUsageTokenRefresh}); err != nil {
		t.Fatal(err)
	}
	if s, _ := Load(Path()); s.AllowsScope(ScopeGeminiAccountUsageTokenRefresh, Automatic) {
		t.Fatal("tool off left refresh allowed")
	}
}

// S2: a commit that changes only an extension keeps the reading key; any other commit moves it.
func TestS2ExtensionOnlyCommitKeepsTheReadingKey(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "")
	hooks := GrantHooks{Admit: func(ScopeDefinition) (Record, error) {
		return Record{ReaderID: "native:gemini", Backend: "native"}, nil
	}}
	step := func(id string, allow, deny []string) State {
		t.Helper()
		s, err := EnsureStore(Path())
		if err != nil {
			t.Fatal(err)
		}
		if _, err := ApplyGrant(Path(), Grant{RequestID: id, ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: TextVersion, Allow: allow, Deny: deny}, hooks); err != nil {
			t.Fatal(err)
		}
		s, err = Load(Path())
		if err != nil {
			t.Fatal(err)
		}
		return s
	}
	login := step("login", []string{ScopeGeminiAccountUsageSavedLogin}, nil)
	keys := map[string]bool{login.ReadingKey(): true}
	for _, c := range []struct {
		id          string
		allow, deny []string
		same        bool
	}{
		{"refresh-on", []string{ScopeGeminiAccountUsageTokenRefresh}, nil, true},
		{"refresh-off", nil, []string{ScopeGeminiAccountUsageTokenRefresh}, true},
		{"history-on", []string{ScopeGeminiLocalHistory}, nil, false},
		{"refresh-on-again", []string{ScopeGeminiAccountUsageTokenRefresh}, nil, true},
		{"login-off", nil, []string{ScopeGeminiAccountUsageSavedLogin, ScopeGeminiAccountUsageTokenRefresh}, false},
	} {
		before, _ := Load(Path())
		after := step(c.id, c.allow, c.deny)
		if after.Fence() == before.Fence() {
			t.Fatal(c.id, "commit did not move the write fence")
		}
		if same := after.ReadingKey() == before.ReadingKey(); same != c.same {
			t.Fatalf("%s: reading key kept = %v, want %v", c.id, same, c.same)
		}
		if !c.same {
			if keys[after.ReadingKey()] {
				t.Fatal(c.id, "reading key reused")
			}
			keys[after.ReadingKey()] = true
		}
		// The admission copy carries the same key the store does.
		if NewAdmission(after, Automatic).State().ReadingKey() != after.ReadingKey() {
			t.Fatal(c.id, "admission copy lost the reading key")
		}
	}
}

// SPDX-License-Identifier: MIT
package consent

import (
	"testing"
	"time"
)

func TestApplyGrantOmissionPreservesLegacyImplicitKeychain(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	if _, err := EnsureStore(Path()); err != nil {
		t.Fatal(err)
	}
	if err := Change(Path(), func(s *State) error { return Set(s, "claude", true, "native:claude", "native", time.Now()) }); err != nil {
		t.Fatal(err)
	}
	before, err := Load(Path())
	if err != nil {
		t.Fatal(err)
	}
	if before.Tools["claude"].Keychain != "" || before.KeychainStatus("claude", Automatic) != "allowed" {
		t.Fatalf("not a legacy implicit grant: %+v", before.Tools["claude"])
	}
	req := Grant{RequestID: "legacy-omitted-choice", ExpectStoreEpoch: before.StoreEpoch, ExpectGeneration: before.Generation, ConsentTextVersion: TextVersion, Allow: []string{ScopeClaudeAccountUsageSavedLogin}}
	receipt, err := ApplyGrant(Path(), req, GrantHooks{Admit: func(ScopeDefinition) (Record, error) {
		return Record{ReaderID: "native:claude", Backend: "native"}, nil
	}})
	if err != nil || !receipt.Committed {
		t.Fatalf("grant: %+v %v", receipt, err)
	}
	after, err := Load(Path())
	if err != nil {
		t.Fatal(err)
	}
	if got := after.KeychainStatus("claude", Automatic); got != "allowed" {
		t.Fatalf("omitted Keychain choice changed legacy permission: got %s, want allowed", got)
	}
}

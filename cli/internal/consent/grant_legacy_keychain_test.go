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

func TestApplyGrantKeychainOmissionDoesNotWidenConsent(t *testing.T) {
	for _, tc := range []struct{ name, setup, choice, reader, backend, want string }{
		{"new grant", "new", "", "native:claude", "native", "unset"},
		{"explicit deny", "legacy", "deny", "native:claude", "native", "denied"},
		{"prior deny", "denied", "", "native:claude", "native", "denied"},
		{"explicit allow cannot override deny", "denied", "allow", "native:claude", "native", "denied"},
		{"revoked scope", "revoked", "", "native:claude", "native", "unset"},
		{"unsupported route", "legacy", "", "codexbar:claude", "codexbar", "unset"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			t.Setenv("MODELPLAN_READERS", "automatic")
			if _, err := EnsureStore(Path()); err != nil {
				t.Fatal(err)
			}
			if tc.setup != "new" {
				if err := Change(Path(), func(s *State) error {
					if err := Set(s, "claude", true, "native:claude", "native", time.Now()); err != nil {
						return err
					}
					if tc.setup == "revoked" {
						s.RevokeScope(ScopeClaudeAccountUsageSavedLogin)
						r := s.Scopes[ScopeClaudeAccountUsageSavedLogin]
						r.Allowed = false
						s.Scopes[ScopeClaudeAccountUsageSavedLogin] = r
					}
					return nil
				}); err != nil {
					t.Fatal(err)
				}
				if tc.setup == "denied" {
					if err := Deny(Path(), "claude", "keychain"); err != nil {
						t.Fatal(err)
					}
				}
			}
			before, err := Load(Path())
			if err != nil {
				t.Fatal(err)
			}
			req := Grant{RequestID: "keychain-case", ExpectStoreEpoch: before.StoreEpoch, ExpectGeneration: before.Generation, ConsentTextVersion: TextVersion, Allow: []string{ScopeClaudeAccountUsageSavedLogin}}
			if tc.choice != "" {
				req.Keychain = map[string]string{ScopeClaudeAccountUsageSavedLogin: tc.choice}
			}
			_, err = ApplyGrant(Path(), req, GrantHooks{Admit: func(ScopeDefinition) (Record, error) { return Record{ReaderID: tc.reader, Backend: tc.backend}, nil }})
			if err != nil {
				t.Fatal(err)
			}
			after, err := Load(Path())
			if err != nil {
				t.Fatal(err)
			}
			if got := after.KeychainStatus("claude", Automatic); got != tc.want {
				t.Fatalf("status=%s want %s; record=%+v", got, tc.want, after.Tools["claude"])
			}
		})
	}
}

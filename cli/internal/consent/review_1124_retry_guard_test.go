// SPDX-License-Identifier: MIT
package consent

import (
	"errors"
	"path/filepath"
	"testing"
)

// macrevb-1218-5: the guard RetryCleanup hands each eraser is the fence at the point of
// deletion. Invariant: it passes only while the authoritative store is still the snapshot's
// epoch and still owes that scope at least as strongly; otherwise the eraser deletes nothing.
func TestReviewRetryGuardFencesEraseAuthority(t *testing.T) {
	failing := GrantHooks{Cleanup: func(string, bool) error { return errors.New("erasure unavailable") }}
	owe := func(t *testing.T, file, id string, forget bool) {
		t.Helper()
		s, err := Load(file)
		if err != nil {
			t.Fatal(err)
		}
		g := Grant{RequestID: id, ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: TextVersion}
		if forget {
			g.Forget = []string{ScopeZaiLocalHistory}
		} else {
			g.Deny = []string{ScopeZaiLocalHistory}
		}
		if r, err := ApplyGrant(file, g, failing); err != nil || r.Code != "cleanup_pending" {
			t.Fatal(r, err)
		}
	}
	for _, tc := range []struct {
		name    string
		forget  bool
		between func(t *testing.T, file string)
		want    error
	}{
		{"unchanged store", true, func(*testing.T, string) {}, nil},
		{"foreground commit of another scope", true, func(t *testing.T, file string) {
			s, _ := Load(file)
			if _, err := ApplyGrant(file, Grant{RequestID: "deny-other", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, Deny: []string{ScopeGeminiAccountUsageSavedLogin}}, failing); err != nil {
				t.Fatal(err)
			}
		}, nil},
		{"confirmed reset", true, func(t *testing.T, file string) {
			if _, err := Reset(file); err != nil {
				t.Fatal(err)
			}
		}, ErrChanged},
		{"obligation already met", true, func(t *testing.T, file string) {
			if err := RetryCleanup(file, func(string, bool, EraseGuard) error { return nil }); err != nil {
				t.Fatal(err)
			}
		}, ErrChanged},
		{"Forget met, only a Deny owed now", true, func(t *testing.T, file string) {
			if err := RetryCleanup(file, func(string, bool, EraseGuard) error { return nil }); err != nil {
				t.Fatal(err)
			}
			owe(t, file, "deny-again", false)
		}, ErrChanged},
	} {
		t.Run(tc.name, func(t *testing.T) {
			file := filepath.Join(t.TempDir(), "consent.json")
			if _, err := EnsureStore(file); err != nil {
				t.Fatal(err)
			}
			owe(t, file, "owe", tc.forget)
			calls := 0
			var got error
			if err := RetryCleanup(file, func(scope string, forget bool, guard EraseGuard) error {
				if scope != ScopeZaiLocalHistory {
					return nil
				}
				calls++
				tc.between(t, file) // the retry waits for the reader lock outside the consent lock
				got = guard.Check()
				return got
			}); err != nil {
				t.Fatal(err)
			}
			if calls != 1 || !errors.Is(got, tc.want) && got != tc.want {
				t.Fatalf("guard = %v, want %v (calls %d)", got, tc.want, calls)
			}
		})
	}
}

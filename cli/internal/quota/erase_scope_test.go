// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestAccountScopeCleanupKeepsIndependentKeyValuesAndBudget(t *testing.T) {
	for _, forget := range []bool{false, true} {
		t.Run(map[bool]string{false: "deny", true: "forget"}[forget], func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			p := Paths{Cache: cache}
			now := time.Now().UTC()
			loginRef := assignSubscription(cache, "kimi-code-login:china", "synthetic-login", now)
			keyRef := assignSubscription(cache, "api-key", "synthetic-explicit-key", now)
			if loginRef == "" || keyRef == "" {
				t.Fatal("identity setup failed")
			}
			state := &readerState{SchemaVersion: 1, Provider: "kimi", NextAttemptAt: now.Add(time.Hour), Entries: []readerEntry{{ProfileKey: "synthetic", Status: "ok", Account: &Account{Subscription: &Binding{Ref: loginRef, Status: "verified", Basis: "kimi-code-login:china"}}}}}
			if err := saveReaderState(cache, state); err != nil {
				t.Fatal(err)
			}
			native, _ := json.Marshal(nativeSnap{SchemaVersion: 1, Providers: []codexbarEntry{{Provider: "kimi", Status: "ok", SubscriptionRef: keyRef}}})
			path := filepath.Join(cache, "observed", "native.json")
			if err := writeAtomic(path, native); err != nil {
				t.Fatal(err)
			}
			if err := reserveReaderAttempt(cache, "kimi", state.NextAttemptAt); err != nil {
				t.Fatal(err)
			}
			if err := EraseScope(p, consent.ScopeKimiAccountUsageSavedLogin, forget); err != nil {
				t.Fatal(err)
			}
			if _, err := os.Stat(readerPath(cache, "kimi")); !os.IsNotExist(err) {
				t.Fatal("saved-login capture survived", err)
			}
			after, _ := os.ReadFile(path)
			if string(after) != string(native) {
				t.Fatal("saved-login revoke erased independent key reading")
			}
			if readerAttemptDue(cache, "kimi", now.Add(10*time.Minute)) {
				t.Fatal("cleanup reset shared budget")
			}
			if ref := lookupSubscription(cache, "api-key", "synthetic-explicit-key"); ref != keyRef {
				t.Fatal("other scope identity erased")
			}
			ref := lookupSubscription(cache, "kimi-code-login:china", "synthetic-login")
			if forget && ref != "" || !forget && ref != loginRef {
				t.Fatal("deny/Forget identity semantics", ref, forget)
			}
		})
	}
}

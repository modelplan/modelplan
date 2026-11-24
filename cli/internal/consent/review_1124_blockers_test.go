// SPDX-License-Identifier: MIT
package consent

import (
	"errors"
	"fmt"
	"path/filepath"
	"sort"
	"sync"
	"testing"
	"time"
)

func owedErasure(s State) map[string]bool {
	owed := map[string]bool{}
	for _, receipt := range s.Requests {
		for _, scope := range receipt.PendingForget {
			owed[scope] = owed[scope] || receipt.ForgetScopes[scope]
		}
	}
	return owed
}

// macrevb-1218-1: while erasure keeps failing, every valid Deny or Forget leaves an owed
// obligation. Those receipts used to be exempt from pruning, so the store filled (operation
// ~388) and the next revocation was refused, leaving the old permission authoritative.
// Invariant: a valid Deny or Forget always commits; owed erasure survives with its Forget flag;
// a retained receipt replays its original response.
func TestReviewDenyCommitsAtCapacityWhileErasureIsOwed(t *testing.T) {
	file := filepath.Join(t.TempDir(), "consent.json")
	s, err := EnsureStore(file)
	if err != nil {
		t.Fatal(err)
	}
	failing := GrantHooks{
		Admit:   func(ScopeDefinition) (Record, error) { return Record{ReaderID: "native:gemini", Backend: "native"}, nil },
		Cleanup: func(string, bool) error { return errors.New("erasure unavailable") },
	}
	apply := func(g Grant) GrantReceipt {
		t.Helper()
		current, err := Load(file)
		if err != nil {
			t.Fatal(err)
		}
		g.ExpectStoreEpoch, g.ExpectGeneration = s.StoreEpoch, current.Generation
		result, err := ApplyGrant(file, g, failing)
		if err != nil || !result.Committed {
			t.Fatalf("%s refused: %v %+v", g.RequestID, err, result)
		}
		return result
	}
	apply(Grant{RequestID: "forget-retired", Forget: []string{"retired.old_path"}})
	for i := 0; i < 1200; i++ {
		apply(Grant{RequestID: fmt.Sprintf("deny-%04d", i), Deny: []string{ScopeClaudeAccountUsageSavedLogin}})
	}
	apply(Grant{RequestID: "allow-gemini", ConsentTextVersion: TextVersion, Allow: []string{ScopeGeminiAccountUsageSavedLogin}})
	current, _ := Load(file)
	deny := Grant{RequestID: "deny-gemini", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: current.Generation, Deny: []string{ScopeGeminiAccountUsageSavedLogin}}
	original, err := ApplyGrant(file, deny, failing)
	if err != nil || !original.Committed || original.Code != "cleanup_pending" {
		t.Fatal("deny at capacity refused", original, err)
	}
	after, _ := Load(file)
	if after.Scopes[ScopeGeminiAccountUsageSavedLogin].Allowed {
		t.Fatal("deny did not become durable")
	}
	owed := owedErasure(after)
	if !owed["retired.old_path"] {
		t.Fatalf("owed Forget erasure lost: %v", owed)
	}
	for _, scope := range []string{ScopeClaudeAccountUsageSavedLogin, ScopeGeminiAccountUsageSavedLogin} {
		if forget, ok := owed[scope]; !ok || forget {
			t.Fatalf("owed Deny erasure of %s lost or widened: %v", scope, owed)
		}
	}
	if len(after.Requests) > receiptWindow+1 {
		t.Fatalf("kept %d receipts", len(after.Requests))
	}
	replay, err := ApplyGrant(file, deny, failing)
	if err != nil || !replay.Replayed || replay.Code != original.Code || *replay.CommittedGeneration != *original.CommittedGeneration {
		t.Fatal("retained receipt did not replay its original response", replay, err)
	}
	// Once erasure works, each owed scope is erased with its original Forget flag.
	var mu sync.Mutex
	erased := map[string]bool{}
	if err := RetryCleanup(file, func(scope string, forget bool) error {
		mu.Lock()
		defer mu.Unlock()
		erased[scope] = forget
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	want := map[string]bool{"retired.old_path": true, ScopeClaudeAccountUsageSavedLogin: false, ScopeGeminiAccountUsageSavedLogin: false}
	for scope, forget := range want {
		if got, ok := erased[scope]; !ok || got != forget {
			t.Fatalf("erasure of %s: got %v (ran %v), want forget=%v", scope, got, ok, forget)
		}
	}
	cleaned, _ := Load(file)
	if left := owedErasure(cleaned); len(left) != 0 {
		t.Fatalf("obligations left after erasure: %v", left)
	}
	replay, err = ApplyGrant(file, deny, failing)
	if err != nil || !replay.Replayed || replay.Code != original.Code {
		t.Fatal("cleanup rewrote the original receipt", replay, err)
	}
}

// macrevb-1218-2: RetryCleanup held the consent lock across erasure callbacks that each wait for
// the reader lock, so a foreground Deny gave up on the consent lock and never committed.
// Invariant: background erasure never holds the consent lock while it waits.
func TestReviewRetryCleanupLetsForegroundDenyCommit(t *testing.T) {
	file := filepath.Join(t.TempDir(), "consent.json")
	s, err := EnsureStore(file)
	if err != nil {
		t.Fatal(err)
	}
	failing := GrantHooks{Cleanup: func(string, bool) error { return errors.New("reader lock busy") }}
	forget := Grant{RequestID: "forget-two", ExpectStoreEpoch: s.StoreEpoch, Forget: []string{"retired.old_path"}, Deny: []string{ScopeClaudeAccountUsageSavedLogin}}
	original, err := ApplyGrant(file, forget, failing)
	if err != nil || original.Code != "cleanup_pending" {
		t.Fatal(original, err)
	}
	entered, release := make(chan struct{}), make(chan struct{})
	var once sync.Once
	retried := make(chan error, 1)
	go func() {
		retried <- RetryCleanup(file, func(string, bool) error {
			once.Do(func() { close(entered) })
			<-release // a long read still holds the reader lock
			return nil
		})
	}()
	<-entered
	committed := make(chan error, 1)
	go func() {
		current, err := Load(file)
		if err != nil {
			committed <- err
			return
		}
		deny := Grant{RequestID: "foreground-deny", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: current.Generation, Deny: []string{ScopeGeminiAccountUsageSavedLogin}}
		result, err := ApplyGrant(file, deny, failing)
		if err == nil && !result.Committed {
			err = errors.New("not committed")
		}
		committed <- err
	}()
	select {
	case err := <-committed:
		if err != nil {
			close(release)
			t.Fatal("foreground deny did not commit during background erasure:", err)
		}
	case <-time.After(4 * time.Second):
		close(release)
		t.Fatal("foreground deny blocked behind background erasure")
	}
	close(release)
	if err := <-retried; err != nil {
		t.Fatal(err)
	}
	// The racing commit leaves the obligations for the next retry; erasure is idempotent.
	if err := RetryCleanup(file, func(string, bool) error { return nil }); err != nil {
		t.Fatal(err)
	}
	done, _ := Load(file)
	if left := owedErasure(done); len(left) != 0 {
		keys := []string{}
		for k := range left {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		t.Fatalf("obligations left: %v", keys)
	}
	replay, err := ApplyGrant(file, forget, failing)
	if err != nil || !replay.Replayed || replay.Code != original.Code || *replay.CommittedGeneration != *original.CommittedGeneration {
		t.Fatal("retry rewrote the original receipt", replay, err)
	}
}

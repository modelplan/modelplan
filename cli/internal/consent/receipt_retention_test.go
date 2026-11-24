// SPDX-License-Identifier: MIT
package consent

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

// Review 11-24 #2: every committed request kept its receipt, so a long-lived profile filled the
// 256 KiB store and the next Deny or Forget was refused, leaving the old grant authoritative.
// Completed receipts are now bounded; pending cleanup and the recent replay window are kept.
func TestManyGrantsNeverFillTheStoreAndDenyStillCommits(t *testing.T) {
	file := filepath.Join(t.TempDir(), "consent.json")
	s, err := EnsureStore(file)
	if err != nil {
		t.Fatal(err)
	}
	hooks := GrantHooks{Cleanup: func(string, bool) error { return nil }}
	var first Grant
	const rounds = 1200 // well past what 256 KiB of retained receipts could hold
	for i := 0; i < rounds; i++ {
		current, err := Load(file)
		if err != nil {
			t.Fatal(err)
		}
		g := Grant{RequestID: fmt.Sprintf("settings-change-%04d", i), ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: current.Generation, Deny: []string{ScopeClaudeAccountUsageSavedLogin}}
		if i == 0 {
			first = g
		}
		result, err := ApplyGrant(file, g, hooks)
		if err != nil || !result.Committed {
			t.Fatalf("grant %d refused: %v %+v", i, err, result)
		}
	}
	info, err := os.Stat(file)
	if err != nil {
		t.Fatal(err)
	}
	if info.Size() > 64<<10 {
		t.Fatalf("store grew to %d bytes", info.Size())
	}
	current, _ := Load(file)
	if len(current.Requests) > receiptWindow {
		t.Fatalf("kept %d receipts", len(current.Requests))
	}
	// The most recent request still replays its original receipt without writing.
	last := Grant{RequestID: fmt.Sprintf("settings-change-%04d", rounds-1), ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: current.Generation - 1, Deny: []string{ScopeClaudeAccountUsageSavedLogin}}
	before, _ := os.ReadFile(file)
	replay, err := ApplyGrant(file, last, hooks)
	if err != nil || !replay.Replayed {
		t.Fatal("recent receipt lost", replay, err)
	}
	// An expired request ID can never apply a second time: its generation is long gone.
	if _, err := ApplyGrant(file, first, hooks); err == nil || err.Error() != "stale_generation" {
		t.Fatal("expired request re-applied", err)
	}
	after, _ := os.ReadFile(file)
	if string(before) != string(after) {
		t.Fatal("replay or expired request wrote the store")
	}
}

func TestReceiptPruningKeepsPendingCleanup(t *testing.T) {
	file := filepath.Join(t.TempDir(), "consent.json")
	s, err := EnsureStore(file)
	if err != nil {
		t.Fatal(err)
	}
	// A Forget whose erasure fails keeps its obligation through any number of later grants.
	pending := Grant{RequestID: "forget-pending", ExpectStoreEpoch: s.StoreEpoch, Forget: []string{"retired.old_path"}}
	if result, err := ApplyGrant(file, pending, GrantHooks{}); err != nil || result.Code != "cleanup_pending" {
		t.Fatal(result, err)
	}
	hooks := GrantHooks{Cleanup: func(string, bool) error { return nil }}
	for i := 0; i < 3*receiptWindow; i++ {
		current, _ := Load(file)
		g := Grant{RequestID: fmt.Sprintf("later-%03d", i), ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: current.Generation, Deny: []string{ScopeGeminiAccountUsageSavedLogin}}
		if _, err := ApplyGrant(file, g, hooks); err != nil {
			t.Fatal(err)
		}
	}
	// The receipt itself may leave the window (macrevb-1218-1); its Forget obligation may not.
	current, _ := Load(file)
	if owed := owedErasure(current); !owed["retired.old_path"] {
		t.Fatal("pending cleanup obligation pruned", owed)
	}
	if !NewAdmission(current, Automatic).AnyCleanupPending() {
		t.Fatal("admission no longer sees the owed cleanup")
	}
}

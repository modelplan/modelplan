// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Sampling 11-21 S6 (#1130): the app-server watcher captured an admission that allows Codex local
// history, then paused; Forget Codex local history completed through the normal grant transaction;
// the watcher resumed and called ReadPermitted with the old admission. The read took the new memo
// fence and decoded and memoized rollouts after Forget. Invariant: nothing is decoded from Codex
// rollouts after a Forget of Codex local history unless that history is allowed again.
func TestS6StaleAdmissionAfterForgetOpensNoRolloutAndLeavesTheMemoEmpty(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "")
	forgetCodexRollouts()
	t.Cleanup(forgetCodexRollouts)
	home := t.TempDir()
	day := filepath.Join(home, "sessions", "2026", "11", "21")
	_ = os.MkdirAll(day, 0o700)
	path := filepath.Join(day, "rollout-2026-11-21T10-00-00-0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a60.jsonl")
	_ = os.WriteFile(path, []byte(`{"timestamp":"2026-11-21T10:00:02Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":10,"window_minutes":300}}}}`+"\n"), 0o600)
	settled := time.Now().Add(-time.Hour)
	_ = os.Chtimes(path, settled, settled)
	cache := t.TempDir()
	hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) {
		return consent.Record{ReaderID: "native:codex", Backend: "native"}, nil
	}, Cleanup: func(scope string, forget bool) error { return EraseScope(Paths{Cache: cache}, scope, forget) }}
	s, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "allow", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCodexLocalHistory}}, hooks); err != nil {
		t.Fatal(err)
	}
	// The watcher captures its admission, then pauses.
	stale := consent.Capture()
	if !stale.Allows("codex", consent.Local) {
		t.Fatal("setup: Codex history not allowed")
	}
	// Forget Codex local history (Settings), through the normal grant transaction.
	s, _ = consent.Load(consent.Path())
	if receipt, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "forget", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Forget: []string{consent.ScopeCodexLocalHistory}}, hooks); err != nil || receipt.Code != "ok" {
		t.Fatal(receipt, err)
	}
	// The watcher resumes with the old admission.
	before := rolloutReads.Load()
	ReadPermitted(Paths{CodexHome: home, Cache: cache, Admission: &stale}, time.Now())
	if opened := rolloutReads.Load() - before; opened != 0 {
		t.Fatalf("a stale admission opened %d rollouts after Forget", opened)
	}
	if n := codexRolloutMemoSize(); n != 0 {
		t.Fatalf("a stale admission refilled the memo with %d rollouts after Forget", n)
	}
	// Allowing the history again reads it as before.
	s, _ = consent.Load(consent.Path())
	if _, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "allow-again", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCodexLocalHistory}}, hooks); err != nil {
		t.Fatal(err)
	}
	fresh := consent.Capture()
	ReadPermitted(Paths{CodexHome: home, Cache: cache, Admission: &fresh}, time.Now())
	if n := codexRolloutMemoSize(); n != 1 {
		t.Fatalf("a current admission memoized %d rollouts, want 1", n)
	}
}

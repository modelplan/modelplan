// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Sampling 11-20 S1 (#1115): a Codex scan that decoded a rollout before Forget finished must
// not put those events into the memo afterwards. Invariant: nothing decoded from Codex
// rollouts outlives a Forget of Codex local history.
func TestCodexMemoStaysEmptyWhenAScanFinishesAfterForget(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	forgetCodexRollouts()
	t.Cleanup(forgetCodexRollouts)
	home := t.TempDir()
	day := filepath.Join(home, "sessions", "2026", "11", "20")
	_ = os.MkdirAll(day, 0o700)
	path := filepath.Join(day, "rollout-2026-11-20T10-00-00-0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5d.jsonl")
	_ = os.WriteFile(path, []byte(`{"timestamp":"2026-11-20T10:00:02Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":10,"window_minutes":300}}}}`+"\n"), 0o600)
	settled := time.Now().Add(-time.Hour)
	_ = os.Chtimes(path, settled, settled)

	decoded, resume := make(chan struct{}), make(chan struct{})
	afterRolloutDecode = func(string) { close(decoded); <-resume }
	t.Cleanup(func() { afterRolloutDecode = func(string) {} })

	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
	allowed := consent.NewAdmission(state, consent.Automatic)
	cache := t.TempDir()
	done := make(chan struct{})
	go func() {
		defer close(done)
		ReadPermitted(Paths{CodexHome: home, Cache: cache, Admission: &allowed}, time.Now())
	}()
	<-decoded
	// Forget Codex local history (Settings) while the background scan is paused.
	afterRolloutDecode = func(string) {}
	if err := EraseScope(Paths{Cache: cache}, consent.ScopeCodexLocalHistory, true); err != nil {
		t.Fatal(err)
	}
	if n := codexRolloutMemoSize(); n != 0 {
		t.Fatalf("setup: memo holds %d entries right after Forget", n)
	}
	close(resume)
	<-done
	if n := codexRolloutMemoSize(); n != 0 {
		t.Fatalf("a scan begun before Forget left %d decoded rollouts in the memo", n)
	}

	// A scan admitted after Forget still memoizes as before.
	ReadPermitted(Paths{CodexHome: home, Cache: cache, Admission: &allowed}, time.Now())
	if n := codexRolloutMemoSize(); n != 1 {
		t.Fatalf("a scan after Forget kept %d entries, want 1", n)
	}
}

// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
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

// Coordinator follow-up to S1: disconnecting Codex (ForgetTool, the `modelplan connections
// disconnect` and `consent revoke` cleanup) and erasing any other Codex scope (EraseScope ->
// forgetTool) clear the memo too, also when a scan begun before them finishes afterwards, and
// also when ModelPlan has no observed cache yet.
func TestCodexMemoIsClearedByEveryCodexForget(t *testing.T) {
	for _, tc := range []struct {
		name   string
		forget func(Paths) error
	}{
		{"ForgetTool", func(p Paths) error { return ForgetTool(p, "codex") }},
		{"EraseScope runtime usage", func(p Paths) error { return EraseScope(p, consent.ScopeCodexRuntimeUsage, true) }},
	} {
		for _, observed := range []bool{false, true} {
			t.Run(fmt.Sprintf("%s/observed=%v", tc.name, observed), func(t *testing.T) {
				t.Setenv("HOME", t.TempDir())
				forgetCodexRollouts()
				t.Cleanup(forgetCodexRollouts)
				home := t.TempDir()
				day := filepath.Join(home, "sessions", "2026", "11", "20")
				_ = os.MkdirAll(day, 0o700)
				path := filepath.Join(day, "rollout-2026-11-20T10-00-00-0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5e.jsonl")
				_ = os.WriteFile(path, []byte(`{"timestamp":"2026-11-20T10:00:02Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":10,"window_minutes":300}}}}`+"\n"), 0o600)
				settled := time.Now().Add(-time.Hour)
				_ = os.Chtimes(path, settled, settled)
				p := Paths{Cache: t.TempDir()}
				if observed {
					_ = os.MkdirAll(filepath.Join(p.Cache, "observed"), 0o700)
				}
				if readCodex(home, ""); codexRolloutMemoSize() != 1 {
					t.Fatal("setup: memo not filled")
				}
				// A second, unchanged file read is paused between decode and memo insert.
				path2 := strings.Replace(path, "4a5e", "4a5f", 1)
				_ = os.WriteFile(path2, []byte(`{"timestamp":"2026-11-20T10:00:03Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":11,"window_minutes":300}}}}`+"\n"), 0o600)
				_ = os.Chtimes(path2, settled, settled)
				decoded, resume := make(chan struct{}), make(chan struct{})
				var once sync.Once
				afterRolloutDecode = func(string) { once.Do(func() { close(decoded); <-resume }) }
				t.Cleanup(func() { afterRolloutDecode = func(string) {} })
				done := make(chan struct{})
				go func() { defer close(done); readCodex(home, "") }()
				<-decoded
				if err := tc.forget(p); err != nil {
					t.Fatal(err)
				}
				if n := codexRolloutMemoSize(); n != 0 {
					t.Fatalf("memo keeps %d decoded rollouts right after the forget", n)
				}
				close(resume)
				<-done
				if n := codexRolloutMemoSize(); n != 0 {
					t.Fatalf("a scan begun before the forget left %d decoded rollouts in the memo", n)
				}
			})
		}
	}
}

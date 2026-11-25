// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// D397 (macrevb-1222-2): an observation whose outcome changes without a ledger change (a log
// aging out of the live window, a busy lock) writes its diagnostics outside the directory the
// change watcher stamps, so the next production watcher poll asks for no view. A pass that
// replaces a real ledger still makes the watcher ask for one, with no direct callback at all.
func TestDiagnosticChangeDoesNotInvalidateView(t *testing.T) {
	_, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	observed := filepath.Join(cache, "observed")
	if err := os.MkdirAll(observed, 0o700); err != nil {
		t.Fatal(err)
	}
	// A log from an earlier build in the watched directory is removed once, on the first write.
	if err := os.WriteFile(filepath.Join(observed, ObserveLogFile), []byte("{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	b, err := NewSharedBackend(SharedConfig{Detect: func() detect.Report { return detect.Report{} },
		Paths: func(a consent.Admission) quota.Paths { return paths(a) }, Cleanup: func(string, bool, consent.EraseGuard) error { return nil }})
	if err != nil {
		t.Fatal(err)
	}
	outcome, write := ObserveRan, false
	s := NewRefreshScheduler(context.Background(), RefreshConfig{
		Backend: newMemoryBackend(), Paths: paths,
		Observe: func(time.Time) []ObserveResult {
			if write {
				tmp := filepath.Join(observed, ".tmp-ledger")
				if err := os.WriteFile(tmp, []byte("{}"), 0o600); err != nil {
					t.Error(err)
				}
				if err := os.Rename(tmp, filepath.Join(observed, "perf.json")); err != nil {
					t.Error(err)
				}
			}
			return []ObserveResult{{Source: "live", Outcome: outcome}}
		},
		// No direct callback: only the watcher can ask for a view here.
	})
	defer s.Close()
	steps := b.IdleSteps()
	at := time.Now()
	poll := func() bool {
		t.Helper()
		steps.Watch(at)
		at = at.Add(200 * time.Millisecond)
		return steps.Pending()
	}
	pass := func() {
		s.ObserveOnce(at)
		time.Sleep(20 * time.Millisecond) // a rename now carries a later time
	}
	poll()
	pass() // first log write, and the one-time removal of the legacy copy
	poll()
	if _, err := os.Stat(filepath.Join(observed, ObserveLogFile)); !os.IsNotExist(err) {
		t.Fatalf("the legacy observation log in the watched directory was kept: %v", err)
	}
	for i, next := range []ObserveOutcome{ObserveSkippedNoLogs, ObserveRan, ObserveSkippedLockBusy, ObserveError} {
		outcome = next
		before, _ := os.Stat(ObserveLogPath(cache))
		pass()
		after, err := os.Stat(ObserveLogPath(cache))
		if err != nil || before != nil && os.SameFile(before, after) {
			t.Fatalf("transition %d: the changed outcome was not recorded (%v)", i, err)
		}
		if poll() {
			t.Fatalf("transition %d to %s: a diagnostics-only change made the watcher ask for a view", i, next)
		}
	}
	write, outcome = true, ObserveRan
	pass()
	if !poll() {
		t.Fatal("a pass that replaced a ledger did not make the watcher ask for a view")
	}
}

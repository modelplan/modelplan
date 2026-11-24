// SPDX-License-Identifier: MIT
package main

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// D397 (energy plan item 2): an observer whose logs and ledgers are as its last clean pass left
// them is skipped, so an idle 30-second pass decodes nothing. Any change it could have read runs
// it again: an append, a ledger rewritten by another process, a new fence, a new day or label
// setting, a log still settling, a failed pass, or the memo's age.
func TestObserveMemoSkipsOnlyUnchangedSettledPasses(t *testing.T) {
	cache := t.TempDir()
	if err := os.MkdirAll(filepath.Join(cache, "observed"), 0o700); err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, 11, 24, 12, 0, 0, 0, time.Local)
	log := filepath.Join(t.TempDir(), "rollout.jsonl")
	writeAt := func(path, body string, at time.Time) {
		t.Helper()
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(path, at, at); err != nil {
			t.Fatal(err)
		}
	}
	writeAt(log, "{}\n", now.Add(-time.Hour))
	var memo observeMemo
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	labels, outcome, calls := true, appserver.ObserveRan, 0
	run := func(at time.Time) bool {
		before := calls
		got := memo.skipUnchanged("codex", cache, fence, labels, "ref", []string{log}, observeSettle, at, func() appserver.ObserveOutcome {
			calls++
			return outcome
		})
		if got != outcome && got != appserver.ObserveRan {
			t.Fatalf("outcome %q", got)
		}
		return calls > before
	}
	step := func(name string, at time.Time, want bool) {
		t.Helper()
		if ran := run(at); ran != want {
			t.Fatalf("%s: ran=%v, want %v", name, ran, want)
		}
	}
	step("first pass", now, true)
	step("unchanged", now.Add(30*time.Second), false)

	writeAt(log, "{}\n{}\n", now.Add(-time.Hour)) // appended, same mtime
	step("append", now.Add(time.Minute), true)
	step("unchanged after append", now.Add(90*time.Second), false)

	writeAt(speed.Path(cache), "{}\n", now) // another process rewrote a ledger
	step("ledger rewritten", now.Add(2*time.Minute), true)
	step("unchanged after ledger", now.Add(150*time.Second), false)

	fence.Generation++
	step("new fence", now.Add(3*time.Minute), true)
	labels = false
	step("labels off", now.Add(4*time.Minute), true)
	step("next day", now.Add(24*time.Hour), true)
	step("memo too old", now.Add(24*time.Hour+observeMemoTTL), true)

	writeAt(log, "{}\n{}\n{}\n", now.Add(24*time.Hour+observeMemoTTL)) // a turn may still be closing
	step("settling", now.Add(24*time.Hour+observeMemoTTL+30*time.Second), true)
	step("still settling", now.Add(24*time.Hour+observeMemoTTL+time.Minute), true)
	step("settled", now.Add(24*time.Hour+observeMemoTTL+3*time.Minute), true)
	step("settled and unchanged", now.Add(24*time.Hour+observeMemoTTL+3*time.Minute+30*time.Second), false)

	outcome = appserver.ObserveSkippedLockBusy
	if err := os.Remove(speed.Path(cache)); err != nil {
		t.Fatal(err)
	}
	step("busy", now.Add(25*time.Hour), true)
	step("busy again", now.Add(25*time.Hour+30*time.Second), true)
}

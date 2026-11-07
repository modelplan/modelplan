// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// A fake Codex that fails every read, with no canary or credential involved.
func failingCodex(t *testing.T) string {
	t.Helper()
	bin := filepath.Join(t.TempDir(), "codex")
	if err := os.WriteFile(bin, []byte("#!/bin/sh\nexit 1\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	return bin
}

// G3-36: a first read that fails retries soon, a bounded number of times, and then falls back
// to the ordinary wait, so a Codex that is not signed in is not started every few seconds.
func TestG336FirstReadFailuresRetrySoonThenBackOff(t *testing.T) {
	isolateHome(t)
	cache, bin, now := t.TempDir(), failingCodex(t), acctNow
	for _, want := range append(append([]time.Duration{}, firstReadRetries...), accountRetryAfter) {
		if err := RefreshCodexAccount(context.Background(), cache, bin, now); err == nil {
			t.Fatal("a failing Codex reported success")
		}
		if AccountDue(cache, now.Add(want-time.Second)) || !AccountDue(cache, now.Add(want)) {
			next, _ := codexRefreshNext(cache)
			t.Fatalf("after a failed read the next read is %s away, want %s", next.Sub(now), want)
		}
		now = now.Add(want)
	}
	if got := CodexFailureWait(cache); got != accountRetryAfter {
		t.Fatalf("spent first-read retries wait %s", got)
	}
}

// A Mac that has a reading keeps the ordinary wait: the first-read limits are for the first read.
func TestG336FailureAfterAReadingKeepsTheOrdinaryWait(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	if err := save(cache, &accountSnap{SchemaVersion: 1, ObservedAt: acctNow.Add(-time.Hour), Status: "ok"}); err != nil {
		t.Fatal(err)
	}
	if err := RefreshCodexAccount(context.Background(), cache, failingCodex(t), acctNow); err == nil {
		t.Fatal("a failing Codex reported success")
	}
	if AccountDue(cache, acctNow.Add(29*time.Minute)) || !AccountDue(cache, acctNow.Add(accountRetryAfter)) {
		t.Fatal("a failure after a reading no longer waits the ordinary half hour")
	}
}

// An older failure record has no count: it keeps the wait it was written with.
func TestG336OlderFailureRecordKeepsItsWait(t *testing.T) {
	if got := accountFailureWait(&accountSnap{SchemaVersion: 1, Status: "error"}); got != accountRetryAfter {
		t.Fatalf("older failure waits %s", got)
	}
}

// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
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

func grantCodexRuntime(t *testing.T) {
	t.Helper()
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		return consent.Set(s, "codex", true, "", "", acctNow)
	}); err != nil {
		t.Fatal(err)
	}
}

// G3-36: the consent store and settings are reset (first run again) while the cache folder
// keeps an old snapshot and a next-attempt time. A new grant must read at once: neither the old
// schedule nor the old snapshot from before the grant may hold the first read back.
func TestG336NewGrantReadsAtOnceDespiteStaleCache(t *testing.T) {
	isolateHome(t)
	cache, bin := t.TempDir(), failingCodex(t)
	grantCodexRuntime(t)
	// A failed read under the first grant leaves a snapshot and a reservation far in the future.
	if err := save(cache, &accountSnap{SchemaVersion: 1, ObservedAt: acctNow, Status: "ok"}); err != nil {
		t.Fatal(err)
	}
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow.Add(AccountEvery)); err == nil {
		t.Fatal("a failing Codex reported success")
	}
	if err := reserveReaderAttempt(cache, "codex", acctNow.Add(30*time.Minute)); err != nil {
		t.Fatal(err)
	}
	now := acctNow.Add(2 * time.Minute)
	if AccountDue(cache, now) {
		t.Fatal("precondition: the old schedule should still hold within the same grant")
	}
	// First run again: the consent store is moved aside, then the user grants once more.
	if err := os.Remove(consent.Path()); err != nil {
		t.Fatal(err)
	}
	grantCodexRuntime(t)
	if !AccountDue(cache, now) {
		next, _ := codexRefreshNext(cache)
		t.Fatalf("a new grant waits %s on a stale cache", next.Sub(now))
	}
	fake, log := fakeCodex(t, acctResponse)
	if err := RefreshCodexAccount(context.Background(), cache, fake, now); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(log); !strings.Contains(string(b), "account/rateLimits/read") {
		t.Fatal("the new grant did not read Codex at once")
	}
	if s := loadAccount(cache); s == nil || s.Status != "ok" || s.ObservedAt.Before(now) {
		t.Fatalf("snapshot after the new grant = %+v", s)
	}
}

// A failure after a new grant is a first read again: it retries soon, not after the old wait.
func TestG336FailureAfterNewGrantRetriesSoon(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	grantCodexRuntime(t)
	state, _ := consent.Current()
	if err := save(cache, &accountSnap{SchemaVersion: 1, ObservedAt: acctNow.Add(-time.Hour), Status: "ok",
		Admission: state.CaptureStamp(consent.ScopeCodexRuntimeUsage)}); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(consent.Path()); err != nil {
		t.Fatal(err)
	}
	grantCodexRuntime(t)
	if err := RefreshCodexAccount(context.Background(), cache, failingCodex(t), acctNow); err == nil {
		t.Fatal("a failing Codex reported success")
	}
	if !AccountDue(cache, acctNow.Add(firstReadRetries[0])) {
		t.Fatal("a failed first read after a new grant did not retry soon")
	}
}

// A revoke and re-grant inside the same consent store keeps the shared read budget: the schedule
// booked by the last read still holds, and Codex is not asked early.
func TestG336RevokeAndRegrantInSameStoreKeepsTheBudget(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	grantCodexRuntime(t)
	bin, log := fakeCodex(t, acctResponse)
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		return consent.Set(s, "codex", false, "", "", acctNow)
	}); err != nil {
		t.Fatal(err)
	}
	grantCodexRuntime(t)
	before, _ := os.ReadFile(log)
	soon := acctNow.Add(time.Minute)
	if AccountDue(cache, soon) {
		t.Fatal("a revoke and re-grant reset the read budget")
	}
	if err := RefreshCodexAccount(context.Background(), cache, bin, soon); err != nil {
		t.Fatal(err)
	}
	if after, _ := os.ReadFile(log); string(after) != string(before) {
		t.Fatal("Codex was asked before the booked time")
	}
}

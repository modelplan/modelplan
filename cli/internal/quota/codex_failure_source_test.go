// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"testing"
	"time"
)

func codexAccountFailure(r Report) *SourceStatus {
	for i := range r.Sources {
		if r.Sources[i].Source == "codex-account" && r.Sources[i].ErrorCode != "" {
			return &r.Sources[i]
		}
	}
	return nil
}

// Post-merge sample 11-11 (#792 finding 2): a Codex read that fails with no last good reading
// still names its cause in the report, so it reaches the app-server rows.
func TestFirstFailedCodexReadReportsItsCause(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	_ = RefreshCodexAccount(context.Background(), cache, failingCodex(t), acctNow)
	if s := loadAccount(cache); s == nil || s.Good != nil || s.failureCode() != "closed" {
		t.Fatalf("snapshot %+v", s)
	}
	r := Report{}
	applyAccount(&r, cache, acctNow.Add(time.Minute))
	if f := codexAccountFailure(r); f == nil || f.ErrorCode != "closed" {
		t.Fatalf("first failure dropped: %+v", r.Sources)
	}
	if len(r.Accounts) != 0 {
		t.Fatalf("a failure alone must not make an account: %+v", r.Accounts)
	}
	// A failure older than accountKeep describes nothing current.
	old := Report{}
	applyAccount(&old, cache, acctNow.Add(accountKeep+time.Minute))
	if f := codexAccountFailure(old); f != nil {
		t.Fatalf("old failure still reported: %+v", f)
	}
}

// The same holds once the retained reading has expired: the newer failure keeps its cause.
func TestFailedCodexReadAfterTheRetainedReadingExpiresReportsItsCause(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	good, _ := fakeCodex(t, acctResponse)
	if err := RefreshCodexAccount(context.Background(), cache, good, acctNow); err != nil {
		t.Fatal(err)
	}
	failedAt := acctNow.Add(accountKeep - time.Hour)
	_ = RefreshCodexAccount(context.Background(), cache, failingCodex(t), failedAt)
	r := Report{}
	applyAccount(&r, cache, acctNow.Add(accountKeep+time.Hour))
	if f := codexAccountFailure(r); f == nil || f.ErrorCode != "closed" {
		t.Fatalf("failure after the retained reading expired dropped: %+v", r.Sources)
	}
	// While the retained reading is still usable, only the existing stale failure source is reported.
	kept := Report{}
	applyAccount(&kept, cache, failedAt.Add(time.Minute))
	count := 0
	for _, s := range kept.Sources {
		if s.Source == "codex-account" {
			count++
		}
	}
	if f := codexAccountFailure(kept); f == nil || f.Status != "stale" || count != 1 {
		t.Fatalf("retained failure reported as %+v", kept.Sources)
	}
}

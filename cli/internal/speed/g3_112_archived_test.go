// SPDX-License-Identifier: MIT
package speed

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// G3-112: Codex moves archived threads to <CODEX_HOME>/archived_sessions (flat rollout files). The
// importer reads them as well, so a user who archives threads still gets their past usage.
func TestImportReadsCodexArchivedSessions(t *testing.T) {
	f := newFixture(t)
	f.codexLog("rollout-live.jsonl", -2)
	p := f.codexLog("rollout-archived.jsonl", -6, -5)
	archived := filepath.Join(f.home, "archived_sessions", filepath.Base(p))
	os.MkdirAll(filepath.Dir(archived), 0o700)
	if err := os.Rename(p, archived); err != nil {
		t.Fatal(err)
	}
	os.Chtimes(archived, f.now, f.now)
	f.run(30, both())
	l, _ := LoadImported(f.cache)
	if r, _ := total(l, "codex"); r != 3 {
		t.Fatalf("codex requests %d, want 3 (live 1 + archived 2)", r)
	}
	// A second run counts nothing twice, even after the live thread is archived too.
	live := filepath.Join(f.home, "sessions", "2026", "10", "rollout-live.jsonl")
	os.Rename(live, filepath.Join(f.home, "archived_sessions", "rollout-live.jsonl"))
	f.run(30, both())
	l, _ = LoadImported(f.cache)
	if r, _ := total(l, "codex"); r != 3 {
		t.Fatalf("re-import after archiving counted %d, want 3", r)
	}
}

// glm-967-2: coverage written before archived threads were read does not hide them. An older
// codex span (no archived mark) is imported again from both folders, each turn exactly once.
func TestImportReReadsArchivedThreadsUnderOlderCoverage(t *testing.T) {
	f := newFixture(t)
	f.codexLog("rollout-live.jsonl", -2)
	f.run(30, both())
	l, _ := LoadImported(f.cache)
	c := l.Coverage["codex"]
	c.Archived = false // as an older build wrote it
	l.Coverage["codex"] = c
	if err := writeImported(f.cache, l); err != nil {
		t.Fatal(err)
	}
	p := f.codexLog("rollout-old.jsonl", -6, -5)
	archived := filepath.Join(f.home, "archived_sessions", filepath.Base(p))
	os.MkdirAll(filepath.Dir(archived), 0o700)
	if err := os.Rename(p, archived); err != nil {
		t.Fatal(err)
	}
	f.run(30, both())
	l, _ = LoadImported(f.cache)
	if r, _ := total(l, "codex"); r != 3 {
		t.Fatalf("codex requests after upgrade %d, want 3 (each turn once)", r)
	}
	if !l.Coverage["codex"].Archived {
		t.Fatal("re-read coverage not marked as covering archived threads")
	}
	f.run(30, both())
	l, _ = LoadImported(f.cache)
	if r, _ := total(l, "codex"); r != 3 {
		t.Fatalf("third import counted %d", r)
	}
}

// glm-967-4: an automatic run whose every admitted source was withdrawn before its commit has not
// completed the first run; it stays owed.
func TestAutoImportWithdrawnBeforeCommitStaysOwed(t *testing.T) {
	f := newFixture(t)
	f.codexLog("rollout-a.jsonl", -3)
	live := admitted(consent.ScopeCodexLocalHistory)
	withdrawn := func() *consent.Admission {
		state := consent.Empty()
		state.StoreEpoch = "0123456789abcdef0123456789abcdef"
		state.Generation = 3
		state.Revoked[consent.ScopeCodexLocalHistory] = 1
		state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion, At: t0}
		state.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion, At: t0}
		a := consent.NewAdmission(state, consent.Automatic)
		return &a
	}
	if err := MarkAutoRequested(f.cache, f.now); err != nil {
		t.Fatal(err)
	}
	_, err := Import(context.Background(), f.cache, ImportOptions{Now: f.now, Admission: admitted(consent.ScopeCodexLocalHistory), Auto: true,
		Codex: &ImportRoot{Dir: f.home, Background: func(string) bool { live = withdrawn(); return false }},
		Live:  func() consent.Admission { return *live }, Guard: localWriteGuard(&live)})
	if err != nil {
		t.Fatal(err)
	}
	if !NeedsAutoImport(f.cache) {
		t.Fatal("a run whose only source was withdrawn marked the first run done")
	}
	if got := OwedSources(f.cache, *admitted(consent.ScopeCodexLocalHistory)); len(got) != 1 || got[0] != "codex" {
		t.Fatalf("re-granted codex not owed: %v", got)
	}
}

// G3-112: a source is owed a retry once the first-run import was requested (or ran under an older
// build) and that source holds a grant but no current coverage; a fresh profile owes nothing.
func TestOwedSourcesFollowRequestGrantAndCoverage(t *testing.T) {
	f := newFixture(t)
	f.codexLog("rollout-a.jsonl", -3)
	adm := *both()
	if got := OwedSources(f.cache, adm); len(got) != 0 {
		t.Fatalf("fresh profile owes %v", got)
	}
	if err := MarkAutoRequested(f.cache, f.now); err != nil {
		t.Fatal(err)
	}
	if got := OwedSources(f.cache, adm); len(got) != 2 {
		t.Fatalf("requested, nothing covered: %v", got)
	}
	f.run(30, both())
	if got := OwedSources(f.cache, adm); len(got) != 0 {
		t.Fatalf("covered sources still owed: %v", got)
	}
	if got := OwedSources(f.cache, *admitted(consent.ScopeCodexLocalHistory)); len(got) != 0 {
		t.Fatalf("an ungranted source is owed: %v", got)
	}
}

// macrevd-967-1: history the user removed ("Remove imported history") stays removed: it is not
// owed again under the same grant; only a revoke and a new grant (a new grant epoch) owe it again.
func TestRemovedImportIsNotOwedUntilGrantedAgain(t *testing.T) {
	f := newFixture(t)
	f.codexLog("rollout-a.jsonl", -3)
	if _, err := Import(context.Background(), f.cache, ImportOptions{Now: f.now, Codex: &ImportRoot{Dir: f.home}, Admission: both(), Auto: true}); err != nil {
		t.Fatal(err)
	}
	if err := RemoveImportedUnder(f.cache, *both()); err != nil {
		t.Fatal(err)
	}
	if got := OwedSources(f.cache, *both()); len(got) != 0 {
		t.Fatalf("after remove owed %v, want none (removal covers every recorded grant)", got)
	}
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Revoked[consent.ScopeCodexLocalHistory] = 1
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, At: t0}
	state.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
	regranted := consent.NewAdmission(state, consent.Automatic)
	if got := OwedSources(f.cache, regranted); len(got) != 1 || got[0] != "codex" {
		t.Fatalf("revoked and granted again: owed %v, want [codex]", got)
	}
}

// Owner condition (retry must never disturb): automatic retries of a source back off after each
// attempt and stop after OwedRetryMax attempts under the same grant; a new grant starts over, and
// a successful import clears the count.
func TestOwedRetryBacksOffAndStopsAfterTheCap(t *testing.T) {
	f := newFixture(t)
	adm := *admitted(consent.ScopeCodexLocalHistory)
	if err := MarkAutoRequested(f.cache, f.now); err != nil {
		t.Fatal(err)
	}
	now := f.now
	for attempt := 1; attempt <= OwedRetryMax; attempt++ {
		if got := OwedSourcesAt(f.cache, adm, now); len(got) != 1 {
			t.Fatalf("attempt %d not due: %v", attempt, got)
		}
		if err := MarkOwedAttempt(f.cache, []string{"codex"}, adm, now); err != nil {
			t.Fatal(err)
		}
		wait := OwedRetryBase << (attempt - 1)
		if got := OwedSourcesAt(f.cache, adm, now.Add(wait-time.Minute)); len(got) != 0 {
			t.Fatalf("attempt %d retried before its %v backoff", attempt, wait)
		}
		now = now.Add(wait)
	}
	if got := OwedSourcesAt(f.cache, adm, now.Add(1000*time.Hour)); len(got) != 0 {
		t.Fatalf("retried past the cap: %v", got)
	}
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Revoked[consent.ScopeCodexLocalHistory] = 1
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, At: t0}
	state.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
	if got := OwedSourcesAt(f.cache, consent.NewAdmission(state, consent.Automatic), now); len(got) != 1 {
		t.Fatalf("a new grant did not start the retries over: %v", got)
	}
	f.codexLog("rollout-a.jsonl", -3)
	if _, err := Import(context.Background(), f.cache, ImportOptions{Now: f.now, Codex: &ImportRoot{Dir: f.home}, Admission: &adm}); err != nil {
		t.Fatal(err)
	}
	if l, _ := LoadImported(f.cache); len(l.Attempts) != 0 {
		t.Fatalf("a successful import kept the attempt count: %+v", l.Attempts)
	}
}

// macrevd-967-5: the next due retry time is known, so a running engine can wake for it; nothing is
// due once the cap is reached, the source is cancelled or removed under this grant, or covered.
func TestNextOwedAtFollowsTheBackoff(t *testing.T) {
	f := newFixture(t)
	adm := *admitted(consent.ScopeCodexLocalHistory)
	if _, ok := NextOwedAt(f.cache, adm, f.now); ok {
		t.Fatal("fresh profile has a due retry")
	}
	if err := MarkAutoRequested(f.cache, f.now); err != nil {
		t.Fatal(err)
	}
	if at, ok := NextOwedAt(f.cache, adm, f.now); !ok || !at.Equal(f.now) {
		t.Fatalf("owed now: %v %v", at, ok)
	}
	if err := MarkOwedAttempt(f.cache, []string{"codex"}, adm, f.now); err != nil {
		t.Fatal(err)
	}
	if at, ok := NextOwedAt(f.cache, adm, f.now); !ok || !at.Equal(f.now.UTC().Add(OwedRetryBase)) {
		t.Fatalf("after one attempt: %v %v", at, ok)
	}
	if err := MarkOwedCancelled(f.cache, adm); err != nil {
		t.Fatal(err)
	}
	if _, ok := NextOwedAt(f.cache, adm, f.now); ok {
		t.Fatal("a cancelled source still has a due retry")
	}
	if got := OwedSourcesAt(f.cache, adm, f.now.Add(100*time.Hour)); len(got) != 0 {
		t.Fatalf("a cancelled source is owed: %v", got)
	}
}

// Self-check of the retry state machine: removing imported history keeps an earlier Cancel, so a
// cancelled source never becomes owed again through a removal.
func TestRemoveKeepsTheUsersCancel(t *testing.T) {
	f := newFixture(t)
	adm := *both()
	f.claudeLog("a.jsonl", -3)
	if _, err := Import(context.Background(), f.cache, ImportOptions{Now: f.now, Claude: &ImportRoot{Dir: f.claude}, Admission: &adm, Auto: true}); err != nil {
		t.Fatal(err)
	}
	if err := MarkOwedCancelled(f.cache, adm); err != nil {
		t.Fatal(err)
	}
	if err := RemoveImportedUnder(f.cache, adm); err != nil {
		t.Fatal(err)
	}
	if got := OwedSourcesAt(f.cache, adm, f.now.Add(100*time.Hour)); len(got) != 0 {
		t.Fatalf("owed after Cancel then Remove: %v", got)
	}
}

// macrevd-967-6: a Cancel made while a scope was undecided does not block its later first
// explicit allow; it never marks an undecided scope.
func TestCancelDoesNotBlockALaterFirstGrant(t *testing.T) {
	f := newFixture(t)
	claudeOnly := func() consent.Admission {
		state := consent.Empty()
		state.StoreEpoch = "0123456789abcdef0123456789abcdef"
		state.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, At: t0}
		return consent.NewAdmission(state, consent.Automatic) // codex undecided (default-on)
	}()
	if err := MarkAutoRequested(f.cache, f.now); err != nil {
		t.Fatal(err)
	}
	if err := MarkOwedCancelled(f.cache, claudeOnly); err != nil {
		t.Fatal(err)
	}
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, At: t0}
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, At: t0.Add(time.Hour)}
	later := consent.NewAdmission(state, consent.Automatic)
	if got := OwedSourcesAt(f.cache, later, f.now); len(got) != 1 || got[0] != "codex" {
		t.Fatalf("first explicit Codex allow after a Cancel: owed %v, want [codex]", got)
	}
}

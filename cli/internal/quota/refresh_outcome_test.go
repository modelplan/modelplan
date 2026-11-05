// SPDX-License-Identifier: MIT
package quota

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestRefreshOutcomeRequiresThisAttempt(t *testing.T) {
	cache := t.TempDir()
	now := time.Date(2026, 11, 3, 12, 0, 0, 0, time.UTC)
	p := Paths{Cache: cache}
	if err := save(cache, &accountSnap{SchemaVersion: 1, ObservedAt: now, Status: "error"}); err != nil {
		t.Fatal(err)
	}
	if got := ScopeRefreshOutcome(p, consent.ScopeCodexRuntimeUsage, now); got != "failed" {
		t.Fatal(got)
	}
	if got := ScopeRefreshOutcome(p, consent.ScopeCodexRuntimeUsage, now.Add(time.Minute)); got != "not_attempted" {
		t.Fatal(got)
	}
	if err := save(cache, &accountSnap{SchemaVersion: 1, ObservedAt: now, Status: "ok"}); err != nil {
		t.Fatal(err)
	}
	if got := ScopeRefreshOutcome(p, consent.ScopeCodexRuntimeUsage, now); got != "succeeded" {
		t.Fatal(got)
	}
}

func TestCodexRuntimeAvailabilityRequiresUsableRecentWindows(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	now := time.Now().UTC()
	admission := consent.Capture()
	snapshot := &accountSnap{SchemaVersion: 1, ObservedAt: now, Status: "ok"}
	if err := save(cache, snapshot); err != nil {
		t.Fatal(err)
	}
	if CodexRuntimeAvailable(cache, admission, now) {
		t.Fatal("empty runtime was usable")
	}
	used := 20.0
	snapshot.Windows = []Window{{Kind: "weekly", UsedPercent: &used, ObservedAt: now}}
	if err := save(cache, snapshot); err != nil {
		t.Fatal(err)
	}
	if !CodexRuntimeAvailable(cache, admission, now) {
		t.Fatal("recent runtime window unavailable")
	}
	snapshot.Windows[0].ResetsAt = &now
	if err := save(cache, snapshot); err != nil {
		t.Fatal(err)
	}
	if CodexRuntimeAvailable(cache, admission, now) {
		t.Fatal("expired window considered usable")
	}
	snapshot.Windows[0].ResetsAt = nil
	if err := save(cache, snapshot); err != nil {
		t.Fatal(err)
	}
	if !CodexRuntimeAvailable(cache, admission, now.Add(staleAfter-time.Nanosecond)) {
		t.Fatal("fresh runtime prematurely unavailable")
	}
	if CodexRuntimeAvailable(cache, admission, now.Add(staleAfter)) {
		t.Fatal("stale runtime suppressed the local fallback")
	}
	if CodexRuntimeAvailable(cache, admission, now.Add(3*time.Hour)) {
		t.Fatal("three-hour-old runtime suppressed the local fallback")
	}
	if CodexRuntimeAvailable(cache, admission, now.Add(7*time.Hour)) {
		t.Fatal("expired runtime considered usable")
	}
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	if CodexRuntimeAvailable(cache, admission, now) {
		t.Fatal("disabled runtime considered usable")
	}
}

func TestCodexRuntimeAvailabilityUsesWindowObservation(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	now := time.Now().UTC()
	admission := consent.Capture()
	used := 20.0
	snap := &accountSnap{SchemaVersion: 1, ObservedAt: now, Status: "ok", Windows: []Window{{Kind: "weekly", UsedPercent: &used, ObservedAt: now.Add(-3 * time.Hour)}}}
	if err := save(cache, snap); err != nil {
		t.Fatal(err)
	}
	if CodexRuntimeAvailable(cache, admission, now) {
		t.Fatal("stale window borrowed the fresh account observation")
	}
	snap.Windows[0].ObservedAt = now
	snap.Windows[0].UsedPercent = nil
	if err := save(cache, snap); err != nil {
		t.Fatal(err)
	}
	if CodexRuntimeAvailable(cache, admission, now) {
		t.Fatal("window without a reported value suppressed fallback")
	}
	snap.Windows[0].UsedPercent = &used
	if err := save(cache, snap); err != nil {
		t.Fatal(err)
	}
	if !CodexRuntimeAvailable(cache, admission, now) {
		t.Fatal("valid fresh window unavailable")
	}
}

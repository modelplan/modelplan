// SPDX-License-Identifier: MIT
package speed

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/idlework"
)

// #1222 sampling P2: the two-second activity tick copies nothing out of the inventory while the
// history is idle, and its cached selection equals a fresh one as files age out of LiveWithin.
func TestIdleActivitySelectionCopiesNothingAndAgesOut(t *testing.T) {
	home := t.TempDir()
	start := time.Now().Truncate(time.Second)
	claude := filepath.Join(home, "claude")
	old := start.Add(-48 * time.Hour)
	for d := 0; d < 20; d++ {
		dir := filepath.Join(claude, "projects", fmt.Sprintf("-p%02d", d))
		os.MkdirAll(dir, 0o700)
		for i := 0; i < 50; i++ {
			p := filepath.Join(dir, fmt.Sprintf("s%03d.jsonl", i))
			os.WriteFile(p, []byte("{}\n"), 0o600)
			mod := old
			if d == 0 && i < 3 { // three recent sessions, aging out one by one
				mod = start.Add(-time.Duration(4-i) * time.Minute)
			}
			os.Chtimes(p, mod, mod)
		}
		os.Chtimes(dir, old, old)
	}
	os.Chtimes(filepath.Join(claude, "projects"), old, old)
	var index ActivityLogIndex
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	got := index.Logs(claude, "", "", fence, start, start)
	if len(got) != 3 {
		t.Fatalf("warm-up: %d logs", len(got))
	}
	before := idlework.CopiedCount()
	for s := 2; s <= 240; s += 2 {
		now := start.Add(time.Duration(s) * time.Second)
		got := index.Logs(claude, "", "", fence, now, now)
		want := ActivityLogs(claude, "", "", now)
		if fmt.Sprint(got) != fmt.Sprint(want) {
			t.Fatalf("at +%ds: cached %v, fresh %v", s, got, want)
		}
	}
	// The fresh one-shot reads copy; the index's ticks must not. Count only the index.
	var index2 ActivityLogIndex
	index2.Logs(claude, "", "", fence, start, start)
	before = idlework.CopiedCount()
	for s := 2; s <= 240; s += 2 {
		now := start.Add(time.Duration(s) * time.Second)
		index2.Logs(claude, "", "", fence, now, now)
	}
	if n := idlework.CopiedCount() - before; n != 0 {
		t.Fatalf("idle activity ticks copied %d inventory entries, want 0", n)
	}
}

// BenchmarkIdleActivityMinute: one simulated idle minute of the activity observer's two-second
// selection over a static 20,000-log Claude Code history: "uncached" as before, "cached" now.
func BenchmarkIdleActivityMinute(b *testing.B) {
	home := b.TempDir()
	claude := filepath.Join(home, "claude")
	old := time.Now().Add(-48 * time.Hour)
	for d := 0; d < 100; d++ {
		dir := filepath.Join(claude, "projects", fmt.Sprintf("-p%03d", d))
		os.MkdirAll(dir, 0o700)
		for i := 0; i < 200; i++ {
			p := filepath.Join(dir, fmt.Sprintf("s%03d.jsonl", i))
			os.WriteFile(p, []byte("{}\n"), 0o600)
			os.Chtimes(p, old, old)
		}
		os.Chtimes(dir, old, old)
	}
	os.Chtimes(filepath.Join(claude, "projects"), old, old)
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	roots := activityRoots(claude, "", "")
	for _, mode := range []string{"uncached", "cached"} {
		b.Run(mode, func(b *testing.B) {
			var index ActivityLogIndex
			now := time.Now()
			index.Logs(claude, "", "", fence, now, now)
			b.ResetTimer()
			for i := 0; i < b.N; i++ {
				for s := 0; s < 30; s++ {
					now = now.Add(2 * time.Second)
					if mode == "cached" {
						index.Logs(claude, "", "", fence, now, now)
					} else {
						recentLogs(index.inventory(), fence, roots, now, now)
					}
				}
			}
		})
	}
}

// macrev2-1261-1: after every cached candidate has aged out under an unchanged inventory, a tick
// visits at most maxLive+1 of them, and the selection still equals a fresh one.
func TestIdleActivityExpiredCandidatesBounded(t *testing.T) {
	home := t.TempDir()
	start := time.Now().Truncate(time.Second)
	claude := filepath.Join(home, "claude")
	old := start.Add(-48 * time.Hour)
	for d := 0; d < 10; d++ {
		dir := filepath.Join(claude, "projects", fmt.Sprintf("-p%02d", d))
		os.MkdirAll(dir, 0o700)
		for i := 0; i < 200; i++ { // 2,000 logs changed within the last minute
			p := filepath.Join(dir, fmt.Sprintf("s%03d.jsonl", i))
			os.WriteFile(p, []byte("{}\n"), 0o600)
			mod := start.Add(-time.Duration(d*200+i) * 20 * time.Millisecond)
			os.Chtimes(p, mod, mod)
		}
		os.Chtimes(dir, old, old)
	}
	os.Chtimes(filepath.Join(claude, "projects"), old, old)
	var index ActivityLogIndex
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	if got := index.Logs(claude, "", "", fence, start, start); len(got) != maxLive {
		t.Fatalf("warm-up: %d logs", len(got))
	}
	gen := index.selection.gen
	for s := 2; s <= 7*60; s += 2 {
		now := start.Add(time.Duration(s) * time.Second)
		before := liveCandidateVisits.Load()
		got := index.Logs(claude, "", "", fence, now, now)
		if v := liveCandidateVisits.Load() - before; v > maxLive+1 {
			t.Fatalf("at +%ds a tick visited %d cached candidates", s, v)
		}
		if s%60 == 0 {
			if want := ActivityLogs(claude, "", "", now); fmt.Sprint(got) != fmt.Sprint(want) {
				t.Fatalf("at +%ds: cached %d logs, fresh %d", s, len(got), len(want))
			}
		}
	}
	if index.selection.gen != gen {
		t.Fatal("the inventory changed: the test did not keep one generation")
	}
}

// macrev2-1261-2: when every source is withdrawn, the cached selection is forgotten at once,
// with or without a new fence.
func TestActivityWithdrawalForgetsSelection(t *testing.T) {
	home := t.TempDir()
	claude := filepath.Join(home, "claude")
	dir := filepath.Join(claude, "projects", "-p")
	os.MkdirAll(dir, 0o700)
	now := time.Now()
	os.WriteFile(filepath.Join(dir, "s.jsonl"), []byte("{}\n"), 0o600)
	for _, next := range []consent.Fence{{StoreEpoch: "test", Generation: 1}, {StoreEpoch: "test", Generation: 2}} {
		var index ActivityLogIndex
		fence := consent.Fence{StoreEpoch: "test", Generation: 1}
		if got := index.Logs(claude, "", "", fence, now, now); len(got) != 1 {
			t.Fatalf("warm-up: %v", got)
		}
		if got := index.Logs("", "", "", next, now.Add(2*time.Second), now.Add(2*time.Second)); len(got) != 0 {
			t.Fatalf("withdrawn: %v", got)
		}
		if fmt.Sprint(index.selection) != fmt.Sprint(liveSelection{}) {
			t.Fatalf("fence %v: withdrawn selection kept: %+v", next, index.selection)
		}
	}
}

// macrev2-1261-4 (activity): an unavailable consent store disables every source for one pass; when
// the same epoch recovers, the activity selection reads again and equals a fresh one, and a pass
// holding a ticket from before the outage keeps nothing.
func TestActivityRecoversAfterUnavailableStore(t *testing.T) {
	home := t.TempDir()
	claude := filepath.Join(home, "claude")
	dir := filepath.Join(claude, "projects", "-p")
	os.MkdirAll(dir, 0o700)
	now := time.Now()
	os.WriteFile(filepath.Join(dir, "s.jsonl"), []byte("{}\n"), 0o600)
	a := consent.Fence{StoreEpoch: "0123456789abcdef0123456789abcdef", Generation: 3}
	var index ActivityLogIndex
	stale := index.Ticket()
	if got := index.LogsWith(claude, "", "", a, now, now, stale); len(got) != 1 {
		t.Fatalf("warm-up: %v", got)
	}
	// The outage: Capture returns an empty fence and readers off, so every source is disabled.
	if got := index.LogsWith("", "", "", consent.Fence{}, now.Add(2*time.Second), now.Add(2*time.Second), index.Ticket()); len(got) != 0 {
		t.Fatalf("outage: %v", got)
	}
	later := now.Add(4 * time.Second)
	got := index.LogsWith(claude, "", "", a, later, later, index.Ticket())
	if want := ActivityLogs(claude, "", "", later); len(got) != 1 || fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("recovered: %v, fresh %v", got, want)
	}
	var other ActivityLogIndex
	other.Inventory = index.inventory()
	if got := other.LogsWith(claude, "", "", a, later, later, stale); len(got) != 0 {
		t.Fatalf("a pass from before the outage read %v", got)
	}
}

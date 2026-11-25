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

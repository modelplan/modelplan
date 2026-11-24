// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/idlework"
	"github.com/modelplan/modelplan/cli/internal/logindex"
)

// D397 (macrevb-1222-1): a static Codex history larger than the former 20,000-entry bound
// costs no directory listing at any later check, across the ten-minute mark too, and a resumed
// rollout whose name sorts outside the newest 20,000 is selected within the 30 s cold
// interval. The inventory has no entry bound, so the same holds at any size.
func TestLargeStaticInventoryAndResumedRollout(t *testing.T) {
	home := t.TempDir()
	start := time.Date(2026, 11, 20, 12, 0, 0, 0, time.UTC)
	old := start.Add(-30 * 24 * time.Hour)
	const days, perDay = 101, 200 // 20,200 rollouts plus their directories
	var oldest string
	for d := 0; d < days; d++ {
		at := old.Add(-time.Duration(days-d) * 24 * time.Hour)
		dir := filepath.Join(home, "sessions", at.Format("2006"), at.Format("01"), at.Format("02"))
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
		for r := 0; r < perDay; r++ {
			p := filepath.Join(dir, fmt.Sprintf("rollout-%s-%03d.jsonl", at.Format("2006-01-02T15-04-05"), r))
			if err := os.WriteFile(p, []byte("{}\n"), 0o600); err != nil {
				t.Fatal(err)
			}
			if err := os.Chtimes(p, at, at); err != nil {
				t.Fatal(err)
			}
			if oldest == "" {
				oldest = p
			}
		}
	}
	// Static: every directory last changed long ago (a fresh one would be listed again as racy).
	_ = filepath.WalkDir(filepath.Join(home, "sessions"), func(p string, d os.DirEntry, err error) error {
		if err == nil && d.IsDir() {
			defer os.Chtimes(p, old, old)
		}
		return nil
	})
	var index CodexRolloutIndex
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	now := start
	if files, _ := index.recent(home, "", fence, now); len(files) != codexFiles {
		t.Fatalf("warm-up selected %d rollouts", len(files))
	}
	before := idlework.Snapshot()
	// Past the cold interval and the ten-minute mark: metadata reconciliation only.
	for now = now.Add(time.Second); now.Before(start.Add(11 * time.Minute)); now = now.Add(time.Second) {
		index.recent(home, "", fence, now)
	}
	if got := idlework.Snapshot().Since(before); got.Entries != 0 || got.Walks > int64(11*time.Minute/logindex.ColdInterval)+1 {
		t.Fatalf("a large static history cost %+v in eleven minutes, want 0 entries and one walk per cold interval", got)
	}
	// The session in the oldest-named rollout resumes: Codex appends to its start day's file.
	f, err := os.OpenFile(oldest, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.WriteString("{\"resumed\":true}\n"); err != nil {
		t.Fatal(err)
	}
	f.Close()
	if err := os.Chtimes(oldest, now, now); err != nil {
		t.Fatal(err)
	}
	resumed := now
	for ; now.Before(resumed.Add(logindex.ColdInterval + time.Second)); now = now.Add(time.Second) {
		if files, _ := index.recent(home, "", fence, now); slices.Contains(files, oldest) {
			return
		}
	}
	t.Fatalf("a resumed rollout outside the newest-named 20,000 was not selected within %s", logindex.ColdInterval)
}

// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// A resumed session lives in its start day's directory; when it is the most recently
// written log it must be found even behind a busier, newer day (audit C, P2).
func TestNewestRolloutsFindsResumedOlderSession(t *testing.T) {
	root := t.TempDir()
	base := time.Date(2026, 11, 11, 9, 0, 0, 0, time.UTC)
	write := func(day, name string, mod time.Time) string {
		dir := filepath.Join(root, "2026", "11", day)
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
		p := filepath.Join(dir, name)
		if err := os.WriteFile(p, []byte("{}\n"), 0o600); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(p, mod, mod); err != nil {
			t.Fatal(err)
		}
		return p
	}
	for i := 0; i < 16; i++ {
		write("11", fmt.Sprintf("rollout-today-%02d.jsonl", i), base.Add(time.Duration(i)*time.Minute))
	}
	resumed := write("10", "rollout-yesterday.jsonl", base.Add(time.Hour))
	got := newestRollouts(root, 8)
	if len(got) != 8 || got[0] != resumed {
		t.Fatalf("resumed session not first: %v", got)
	}
}

type snapshotRolloutEntry struct {
	os.DirEntry
	snapshot os.FileInfo
}

func (e snapshotRolloutEntry) Info() (os.FileInfo, error) { return e.snapshot, nil }

func TestCachedRolloutNamesStillObserveAppends(t *testing.T) {
	root := t.TempDir()
	dir := filepath.Join(root, "2026", "11", "24")
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	old, latest := filepath.Join(dir, "rollout-old.jsonl"), filepath.Join(dir, "rollout-latest.jsonl")
	before := time.Unix(1200, 0)
	for idx, path := range []string{old, latest} {
		if err := os.WriteFile(path, []byte("{}\n"), 0600); err != nil {
			t.Fatal(err)
		}
		at := before.Add(time.Duration(idx) * time.Second)
		if err := os.Chtimes(path, at, at); err != nil {
			t.Fatal(err)
		}
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		t.Fatal(err)
	}
	for i, entry := range entries {
		fi, err := entry.Info()
		if err != nil {
			t.Fatal(err)
		}
		entries[i] = snapshotRolloutEntry{entry, fi}
	}
	readDir := func(path string) ([]os.DirEntry, error) {
		if path == dir {
			return entries, nil
		}
		return os.ReadDir(path)
	}
	if got := newestRolloutsFrom(root, 1, readDir); len(got) != 1 || got[0] != latest {
		t.Fatal(got)
	}
	if err := os.WriteFile(old, []byte("{}\n{}\n"), 0600); err != nil {
		t.Fatal(err)
	}
	after := before.Add(time.Minute)
	if err := os.Chtimes(old, after, after); err != nil {
		t.Fatal(err)
	}
	if got := newestRolloutsFrom(root, 1, readDir); len(got) != 1 || got[0] != old {
		t.Fatalf("stale directory entry hid the resumed rollout: %v", got)
	}
}

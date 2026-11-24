// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestCodexIdleDirectoryBudget(t *testing.T) {
	home := t.TempDir()
	dir := filepath.Join(home, "sessions", "2026", "11", "24")
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	var index CodexRolloutIndex
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	start := time.Unix(100, 0)
	read := func(offset time.Duration) ([]string, string) {
		return index.recent(home, "thread", fence, start.Add(offset))
	}
	if files, _ := read(0); len(files) != 0 {
		t.Fatal(files)
	}
	path := filepath.Join(dir, "rollout-2026-11-24T00-00-00-thread.jsonl")
	if err := os.WriteFile(path, []byte("{}\n"), 0600); err != nil {
		t.Fatal(err)
	}
	for offset := time.Second; offset < codexRolloutDiscoveryInterval; offset += time.Second {
		if got, _ := read(offset); len(got) != 0 || index.scannedAt != start {
			t.Fatalf("walked the root again at %s: %v", offset, got)
		}
	}
	if got, own := read(codexRolloutDiscoveryInterval); len(got) != 1 || got[0] != path || own != path {
		t.Fatalf("missed newly discovered thread: %v, %q", got, own)
	}
	if err := os.Rename(dir, dir+"-original"); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(dir+"-original", dir); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
	if files, _ := read(codexRolloutDiscoveryInterval + time.Second); len(files) != 0 {
		t.Fatalf("returned a cached path through a replaced directory: %v", files)
	}
}

func TestCodexColdReconciliationKeepsKnownActiveCandidates(t *testing.T) {
	home := t.TempDir()
	dir := filepath.Join(home, "sessions", "2026", "11", "24")
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, "rollout-retained.jsonl")
	if err := os.WriteFile(path, []byte("{}\n"), 0600); err != nil {
		t.Fatal(err)
	}
	var index CodexRolloutIndex
	fence := consent.Fence{StoreEpoch: "hello", Generation: 1}
	now := time.Unix(1100, 0)
	if got, _ := index.recent(home, "", fence, now); len(got) != 1 || got[0] != path {
		t.Fatal(got)
	}
	partial := func(request string) ([]os.DirEntry, error) {
		if request == dir {
			return nil, nil // deferred cold leaf, no new enumeration in this pass
		}
		return os.ReadDir(request)
	}
	if got, _ := index.recentFrom(home, "", fence, now.Add(codexRolloutDiscoveryInterval), partial); len(got) != 1 || got[0] != path {
		t.Fatalf("partial discovery dropped a known rollout: %v", got)
	}
	fence.Generation++
	if got, _ := index.recentFrom(home, "", fence, now.Add(2*codexRolloutDiscoveryInterval), partial); len(got) != 0 {
		t.Fatalf("permission change retained a prior rollout: %v", got)
	}
}

func TestDisplacedRolloutParentsCannotCrowdOutValidCandidates(t *testing.T) {
	home := t.TempDir()
	parent := filepath.Join(home, "sessions", "2026", "11")
	old, valid := filepath.Join(parent, "23"), filepath.Join(parent, "24")
	now := time.Now()
	write := func(dir, name string, at time.Time) string {
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
		log := filepath.Join(dir, name)
		if err := os.WriteFile(log, []byte("{}\n"), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(log, at, at); err != nil {
			t.Fatal(err)
		}
		return log
	}
	keep := write(valid, "rollout-valid.jsonl", now.Add(-time.Minute))
	for i := range codexFiles {
		write(old, fmt.Sprintf("rollout-displaced-%d.jsonl", i), now)
	}
	var index CodexRolloutIndex
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	if got, _ := index.recent(home, "", fence, now); len(got) != codexFiles || got[0] == keep {
		t.Fatalf("the initial full candidate set did not come from one day: %v", got)
	}
	replaced := filepath.Join(t.TempDir(), "after")
	if err := os.Rename(old, replaced); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(replaced, old); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
	if got, _ := index.recent(home, "", fence, now.Add(codexRolloutDiscoveryInterval)); len(got) != 1 || got[0] != keep {
		t.Fatalf("replaced paths crowded out the valid rollout: %v", got)
	}
}

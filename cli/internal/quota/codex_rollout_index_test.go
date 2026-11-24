// SPDX-License-Identifier: MIT
package quota

import (
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

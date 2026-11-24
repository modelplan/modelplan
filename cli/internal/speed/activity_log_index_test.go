// SPDX-License-Identifier: MIT
package speed

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestActivityIdleDirectoryBudget(t *testing.T) {
	home := t.TempDir()
	project := filepath.Join(home, "projects", "project")
	if err := os.MkdirAll(project, 0700); err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	clock := time.Unix(100, 0)
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	var index ActivityLogIndex
	logs := func(offset time.Duration) []LiveLog {
		return index.Logs(home, "", "", fence, now.Add(offset), clock.Add(offset))
	}
	if got := logs(0); len(got) != 0 {
		t.Fatalf("empty startup: %v", got)
	}

	path := filepath.Join(project, "first.jsonl")
	if err := os.WriteFile(path, []byte("{}\n"), 0600); err != nil {
		t.Fatal(err)
	}
	for offset := time.Second; offset < ActivityDiscoveryInterval; offset += time.Second {
		if got := logs(offset); len(got) != 0 || index.scannedAt != clock {
			t.Fatalf("walked the root again at %s: %v", offset, got)
		}
	}
	if got := logs(ActivityDiscoveryInterval); len(got) != 1 || got[0].Path != path {
		t.Fatalf("missed the new log at the next discovery: %v", got)
	}
	fence.Generation++
	if got := index.Logs("", "", "", fence, now, clock.Add(ActivityDiscoveryInterval)); len(got) != 0 || len(index.logs) != 0 {
		t.Fatalf("revoked root kept files: %v", got)
	}
}

func TestDisplacedActivityParentsCannotCrowdOutValidCandidates(t *testing.T) {
	home := t.TempDir()
	parent := filepath.Join(home, "projects")
	old, valid := filepath.Join(parent, "old"), filepath.Join(parent, "valid")
	now := time.Now()
	write := func(dir, name string, at time.Time) string {
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
		path := filepath.Join(dir, name)
		if err := os.WriteFile(path, []byte("{}\n"), 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(path, at, at); err != nil {
			t.Fatal(err)
		}
		return path
	}
	keep := write(valid, "kept.jsonl", now.Add(-time.Minute))
	for i := range maxLive {
		write(old, fmt.Sprintf("displaced-%d.jsonl", i), now)
	}
	var index ActivityLogIndex
	fence := consent.Fence{StoreEpoch: "test", Generation: 1}
	if got := index.Logs(home, "", "", fence, now, now); len(got) != maxLive || got[0].Path == keep {
		t.Fatalf("the initial full candidate set did not come from one project: %v", got)
	}
	replaced := filepath.Join(t.TempDir(), "after")
	if err := os.Rename(old, replaced); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(replaced, old); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
	next := now.Add(ActivityDiscoveryInterval)
	if got := index.Logs(home, "", "", fence, next, next); len(got) != 1 || got[0].Path != keep {
		t.Fatalf("replaced paths crowded out the valid log: %v", got)
	}
}

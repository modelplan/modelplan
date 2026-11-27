// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/idlework"
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
		before := idlework.Snapshot()
		got := logs(offset)
		if done := idlework.Snapshot().Since(before); len(got) != 0 || done.Walks != 0 || done.Entries != 0 {
			t.Fatalf("walked the root again at %s: %v (%+v)", offset, got, done)
		}
	}
	if got := logs(ActivityDiscoveryInterval); len(got) != 1 || got[0].Path != path {
		t.Fatalf("missed the new log at the next discovery: %v", got)
	}
	fence.Generation++
	if got := index.Logs("", "", "", fence, now, clock.Add(ActivityDiscoveryInterval)); len(got) != 0 {
		t.Fatalf("revoked root kept files: %v", got)
	}
	// The new fence discarded the inventory: the root is walked afresh, not served from memory.
	before := idlework.Snapshot()
	if got := index.Logs(home, "", "", fence, now, clock.Add(ActivityDiscoveryInterval+time.Second)); len(got) != 1 {
		t.Fatalf("re-granted root: %v", got)
	}
	if done := idlework.Snapshot().Since(before); done.Walks != 1 {
		t.Fatalf("the revoked inventory was reused: %+v", done)
	}
}

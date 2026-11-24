// SPDX-License-Identifier: MIT
package logindex

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/idlework"
)

type invFixture struct {
	t       *testing.T
	inv     Inventory
	root    string
	fence   consent.Fence
	now     time.Time // wall
	elapsed time.Time // monotonic stand-in
}

func newInvFixture(t *testing.T) *invFixture {
	return &invFixture{t: t, root: filepath.Join(t.TempDir(), "projects"), fence: consent.Fence{StoreEpoch: "test", Generation: 1},
		now: time.Now(), elapsed: time.Unix(1000, 0)}
}

// write creates path with an mtime of at, and gives its directory an old mtime too unless
// keepDir, so only the file looks recent.
func (f *invFixture) write(rel string, at time.Time) string {
	f.t.Helper()
	path := filepath.Join(f.root, rel)
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		f.t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("{}\n"), 0o600); err != nil {
		f.t.Fatal(err)
	}
	if err := os.Chtimes(path, at, at); err != nil {
		f.t.Fatal(err)
	}
	return path
}

func (f *invFixture) age(dir string, at time.Time) {
	f.t.Helper()
	if err := os.Chtimes(filepath.Join(f.root, dir), at, at); err != nil {
		f.t.Fatal(err)
	}
}

func (f *invFixture) step(d time.Duration) ([]File, idlework.Counts) {
	f.now, f.elapsed = f.now.Add(d), f.elapsed.Add(d)
	before := idlework.Snapshot()
	files := f.inv.Files(f.fence, []Root{{Dir: f.root, Source: "claude-code"}}, f.now, f.elapsed)
	sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
	return files, idlework.Snapshot().Since(before)
}

func has(files []File, path string) (File, bool) {
	for _, f := range files {
		if f.Path == path {
			return f, true
		}
	}
	return File{}, false
}

// D397: once a static tree is known, neither the hot check nor the cold reconciliation lists a
// directory again, and each cold reconciliation is one walk of the root.
func TestInventoryListsNothingOnAStaticTree(t *testing.T) {
	f := newInvFixture(t)
	old := f.now.Add(-48 * time.Hour)
	for _, rel := range []string{"a/s1.jsonl", "a/s2.jsonl", "a/s1/subagents/x.jsonl", "b/s3.jsonl", "b/notes.txt"} {
		f.write(rel, old)
	}
	for _, dir := range []string{"a/s1/subagents", "a/s1", "a", "b", "."} {
		f.age(dir, old)
	}
	files, first := f.step(0)
	if len(files) != 4 || first.Walks != 1 || first.Entries == 0 {
		t.Fatalf("first scan: %d files, %+v", len(files), first)
	}
	var total idlework.Counts
	for i := 0; i < int(3*ColdInterval/time.Second); i++ {
		got, done := f.step(time.Second)
		if len(got) != 4 {
			t.Fatalf("lost files on a static tree: %v", got)
		}
		total = total.Plus(done)
	}
	if total.Entries != 0 || total.Walks != 3 {
		t.Fatalf("a static tree cost %+v over three cold intervals, want 0 entries and 3 walks", total)
	}
}

// The hot check finds a new log in a project directory within HotInterval; the cold
// reconciliation finds one in an old nested directory, an append to an old log (a resumed
// session) and removals within ColdInterval. Symlinks are never followed.
func TestInventoryFindsChangesWithinItsIntervals(t *testing.T) {
	f := newInvFixture(t)
	old := f.now.Add(-48 * time.Hour)
	resumed := f.write("a/s1.jsonl", old)
	gone := f.write("b/s2.jsonl", old)
	f.write("0/s3/subagents/x.jsonl", old) // "0" sorts first: off the newest-name chain
	for _, dir := range []string{"0/s3/subagents", "0/s3", "a", "b", "0", "."} {
		f.age(dir, old)
	}
	if files, _ := f.step(0); len(files) != 3 {
		t.Fatalf("first scan: %v", files)
	}

	fresh := f.write("a/s4.jsonl", f.now)
	nested := f.write("0/s3/subagents/y.jsonl", f.now)
	f.age("0/s3/subagents", old.Add(time.Hour)) // changed, but it does not look recent
	if err := os.WriteFile(resumed, []byte("{}\n{}\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(gone); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(f.root, "a"), filepath.Join(f.root, "link")); err != nil {
		t.Skipf("symlink unavailable: %v", err)
	}
	f.write("a/linked.jsonl", old)
	f.age("a", f.now) // the new files moved it; keep it current for the hot check

	var hotFound, coldFound time.Duration
	for at := time.Second; at <= ColdInterval; at += time.Second {
		files, _ := f.step(time.Second)
		if _, ok := has(files, fresh); ok && hotFound == 0 {
			hotFound = at
		}
		_, nestedOK := has(files, nested)
		r, _ := has(files, resumed)
		_, goneOK := has(files, gone)
		if nestedOK && r.Size == 6 && !goneOK && coldFound == 0 {
			coldFound = at
		}
	}
	if hotFound == 0 || hotFound > HotInterval {
		t.Errorf("a new log in a project directory was found after %s, want within %s", hotFound, HotInterval)
	}
	if coldFound == 0 || coldFound > ColdInterval {
		t.Errorf("the nested log, the resumed append or the removal took %s, want within %s", coldFound, ColdInterval)
	}
	files, _ := f.step(time.Second)
	for _, file := range files {
		if filepath.Base(filepath.Dir(file.Path)) == "link" {
			t.Errorf("followed a symlinked directory: %s", file.Path)
		}
	}
}

// A file added within the same timestamp tick as the listing leaves its directory's stamp as it
// was; the directory is listed again while its change is that recent.
func TestInventoryRelistsADirectoryChangedInTheSameTick(t *testing.T) {
	f := newInvFixture(t)
	f.write("a/s1.jsonl", f.now.Add(-time.Hour))
	dir := filepath.Join(f.root, "a")
	info, err := os.Stat(dir)
	if err != nil {
		t.Fatal(err)
	}
	f.now = info.ModTime() // listed in the same instant the directory last changed
	if files, _ := f.step(0); len(files) != 1 {
		t.Fatalf("first scan: %v", files)
	}
	added := f.write("a/s2.jsonl", f.now)
	if err := os.Chtimes(dir, info.ModTime(), info.ModTime()); err != nil {
		t.Fatal(err)
	}
	files, _ := f.step(HotInterval)
	if _, ok := has(files, added); !ok {
		t.Fatalf("a same-tick addition was trusted away by the directory stamp: %v", files)
	}
}

// Privacy: a new consent fence discards everything, Drop forgets a root at once, and nothing is
// returned for a root the caller did not ask for.
func TestInventoryForgetsOnFenceChangeAndDrop(t *testing.T) {
	f := newInvFixture(t)
	f.write("a/s1.jsonl", f.now)
	if files, _ := f.step(0); len(files) != 1 {
		t.Fatalf("first scan: %v", files)
	}
	if got := f.inv.Files(f.fence, nil, f.now, f.elapsed); len(got) != 0 {
		t.Fatalf("returned files of a root nobody asked for: %v", got)
	}
	f.fence.Generation++
	if _, done := f.step(time.Second); done.Walks != 1 {
		t.Fatalf("a new fence reused the inventory: %+v", done)
	}
	f.inv.Drop(f.root)
	if _, done := f.step(time.Second); done.Walks != 1 {
		t.Fatalf("Drop kept the root: %+v", done)
	}
	f.inv.Clear()
	if _, done := f.step(time.Second); done.Walks != 1 {
		t.Fatalf("Clear kept the root: %+v", done)
	}
}

// D397 (macrevb-1222-1): a root that holds more than the retained bound is not listed again at
// every cold check; its known part is reconciled by stats, and only TruncatedRescan relists it.
func TestInventoryOverCapRootIsNotRelistedAtEachColdCheck(t *testing.T) {
	defer func(n int) { maxEntries = n }(maxEntries)
	maxEntries = 20
	f := newInvFixture(t)
	old := f.now.Add(-48 * time.Hour)
	for d := 0; d < 6; d++ {
		for s := 0; s < 5; s++ {
			f.write(filepath.Join(fmt.Sprintf("d%02d", d), fmt.Sprintf("s%d.jsonl", s)), old)
		}
		f.age(fmt.Sprintf("d%02d", d), old)
	}
	f.age(".", old)
	if _, first := f.step(0); first.Walks != 1 || first.Entries == 0 {
		t.Fatalf("first scan: %+v", first)
	}
	var total idlework.Counts
	for i := 0; i < int(3*ColdInterval/time.Second); i++ {
		_, done := f.step(time.Second)
		total = total.Plus(done)
	}
	if total.Entries != 0 {
		t.Fatalf("an over-cap static root was listed again at its cold checks: %+v", total)
	}
	if _, done := f.step(TruncatedRescan); done.Entries == 0 {
		t.Fatal("an over-cap root was never rescanned for the part it could not retain")
	}
}

// Only directories and .jsonl files count against the bound: other entries are not retained.
func TestInventoryBoundCountsRetainedEntriesOnly(t *testing.T) {
	defer func(n int) { maxEntries = n }(maxEntries)
	maxEntries = 10
	f := newInvFixture(t)
	old := f.now.Add(-48 * time.Hour)
	for i := 0; i < 30; i++ {
		f.write(fmt.Sprintf("a/notes-%02d.txt", i), old)
	}
	log := f.write("a/s.jsonl", old)
	files, _ := f.step(0)
	if _, ok := has(files, log); !ok {
		t.Fatalf("non-log entries pushed a log out of the bound: %v", files)
	}
}

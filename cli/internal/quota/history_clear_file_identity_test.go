// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// swapZCodeDB replaces the ZCode database at path with another file of n rows (ids prefix-i,
// started at start), edited by edit before it takes the path. "rename": the new file is written
// beside the old one and renamed over it, so it has another inode. "recreate": the old file is
// removed first and the new one created at the path, where the file system may reuse the inode
// (ext4 does); its birth time differs.
func swapZCodeDB(t *testing.T, path, how, prefix string, n int, start time.Time, edit string, args ...any) {
	t.Helper()
	before, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	removeDB := func() {
		for _, p := range []string{path, path + "-wal", path + "-shm", path + "-journal"} {
			if err := os.Remove(p); err != nil && !os.IsNotExist(err) {
				t.Fatal(err)
			}
		}
	}
	target := path
	if how == "rename" {
		target = path + ".new"
	} else {
		removeDB()
	}
	db := zcodeBatchDB(t, target, prefix, n, start)
	if _, err := db.Exec(edit, args...); err != nil {
		t.Fatal(err)
	}
	if err := db.Close(); err != nil {
		t.Fatal(err)
	}
	if how == "rename" {
		if err := os.Rename(target, path); err != nil {
			t.Fatal(err)
		}
		after, err := os.Stat(path)
		if err != nil {
			t.Fatal(err)
		}
		if os.SameFile(before, after) {
			t.Fatal("setup: the renamed replacement has the old inode")
		}
	}
}

func observeZCode(t *testing.T, cache, home string, at time.Time) {
	t.Helper()
	if err := speed.ObserveZCode(cache, home, speed.Ingest{}, at); err != nil {
		t.Fatal(err)
	}
}

// After the post-clear rows below the pre-clear watermark row were all read, the database is
// replaced by another file with the same number of post-clear rows below that row (other
// requests). The count is unchanged, the file is not: its requests count, each once, the first
// file's are not counted again, and no anchor is kept for the pre-clear row.
func TestHistoryClearSameCountReplacementIsAnotherFile(t *testing.T) {
	for _, how := range []string{"rename", "recreate"} {
		t.Run(how, func(t *testing.T) {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_HISTORY", "")
			cache, home := t.TempDir(), t.TempDir()
			now := time.Now().UTC()
			boundary, db := clearZCodeThenReplace(t, cache, home, 10, now)
			if _, err := db.Exec(`UPDATE model_usage SET started_at = ?, completed_at = ?, output_tokens = 3 WHERE rowid IN (2, 5)`,
				boundary.Add(time.Second).UnixMilli(), boundary.Add(2*time.Second).UnixMilli()); err != nil {
				t.Fatal(err)
			}
			db.Close()
			observeZCode(t, cache, home, boundary.Add(time.Minute))
			if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 2 || out != 6 {
				t.Fatalf("setup: first replacement %d/%d, want 2/6", n, out)
			}
			path := filepath.Join(home, "db.sqlite")
			swapZCodeDB(t, path, how, "synthetic-second-replacement", 10, now.Add(-90*time.Second),
				`UPDATE model_usage SET started_at = ?, completed_at = ?, output_tokens = 7 WHERE rowid IN (2, 5)`,
				boundary.Add(3*time.Second).UnixMilli(), boundary.Add(4*time.Second).UnixMilli())
			for i := 2; i <= 5; i++ {
				observeZCode(t, cache, home, boundary.Add(time.Duration(i)*time.Minute))
			}
			if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 4 || out != 20 {
				t.Fatalf("each post-clear request of both files counts once: got %d/%d, want 4/20", n, out)
			}
			if c := zcodeCursor(t, cache); c.RowID != 10 || c.Anchor != "" || c.More || c.Unread {
				t.Fatalf("cursor rests on the pre-clear row without an anchor: rowID=%d anchor=%q more=%t unread=%t", c.RowID, c.Anchor, c.More, c.Unread)
			}
		})
	}
}

// The database is replaced while the post-clear rows below the pre-clear watermark row are only
// partly read (one batch of 5,000 of 6,001). The new file's rows below the watermark are read from
// its start, not from where the old file's read stopped: the 5,000 requests already counted stay
// counted once and all 6,000 requests of the new file count once.
func TestHistoryClearReplacementDuringLowerBatchReadsNewFileFromStart(t *testing.T) {
	for _, how := range []string{"rename", "recreate"} {
		t.Run(how, func(t *testing.T) {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_HISTORY", "")
			cache, home := t.TempDir(), t.TempDir()
			now := time.Now().UTC()
			boundary, db := clearZCodeThenReplace(t, cache, home, 6002, now)
			if _, err := db.Exec(`UPDATE model_usage SET started_at = ?, completed_at = ? WHERE rowid <= 6001`,
				boundary.Add(time.Second).UnixMilli(), boundary.Add(2*time.Second).UnixMilli()); err != nil {
				t.Fatal(err)
			}
			db.Close()
			observeZCode(t, cache, home, boundary.Add(time.Minute))
			if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 5000 || out != 5000 {
				t.Fatalf("setup: first batch %d/%d, want 5000/5000", n, out)
			}
			if c := zcodeCursor(t, cache); !c.Unread || !c.More {
				t.Fatalf("setup: the lower read is unfinished: unread=%t more=%t", c.Unread, c.More)
			}
			path := filepath.Join(home, "db.sqlite")
			swapZCodeDB(t, path, how, "synthetic-mid-batch-replacement", 6002, now.Add(-90*time.Second),
				`UPDATE model_usage SET started_at = ?, completed_at = ?, output_tokens = 2 WHERE rowid <= 6000`,
				boundary.Add(3*time.Second).UnixMilli(), boundary.Add(4*time.Second).UnixMilli())
			for i := 2; i <= 6; i++ {
				observeZCode(t, cache, home, boundary.Add(time.Duration(i)*time.Minute))
			}
			if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 11000 || out != 17000 {
				t.Fatalf("the new file's unread rows are not dropped: got %d/%d, want 11000/17000", n, out)
			}
			if c := zcodeCursor(t, cache); c.RowID != 6002 || c.Anchor != "" || c.More || c.Unread {
				t.Fatalf("the read completes on the pre-clear row without an anchor: rowID=%d anchor=%q more=%t unread=%t", c.RowID, c.Anchor, c.More, c.Unread)
			}
		})
	}
}

// Requests appended in place (the same file, the same inode) during and after the lower read are
// not a replacement: the normal cursors read them, and every post-clear request counts once.
func TestHistoryClearInPlaceAppendSameFileCountsOnce(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, home := t.TempDir(), t.TempDir()
	now := time.Now().UTC()
	boundary, db := clearZCodeThenReplace(t, cache, home, 6002, now)
	path := filepath.Join(home, "db.sqlite")
	before, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`UPDATE model_usage SET started_at = ?, completed_at = ? WHERE rowid <= 6001`,
		boundary.Add(time.Second).UnixMilli(), boundary.Add(2*time.Second).UnixMilli()); err != nil {
		t.Fatal(err)
	}
	insert := func(id string, out int, at time.Time) {
		t.Helper()
		if _, err := db.Exec(`INSERT INTO model_usage VALUES (?, 'synthetic-session', 'synthetic-model', ?, ?, ?)`,
			id, at.UnixMilli(), at.Add(time.Second).UnixMilli(), out); err != nil {
			t.Fatal(err)
		}
	}
	observeZCode(t, cache, home, boundary.Add(time.Minute))
	if c := zcodeCursor(t, cache); !c.Unread || !c.More {
		t.Fatalf("setup: the lower read is unfinished: unread=%t more=%t", c.Unread, c.More)
	}
	insert("synthetic-in-place-1", 5, boundary.Add(3*time.Second))
	for i := 2; i <= 4; i++ {
		observeZCode(t, cache, home, boundary.Add(time.Duration(i)*time.Minute))
	}
	if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 6002 || out != 6001+5 {
		t.Fatalf("after the first in-place append: got %d/%d, want 6002/6006", n, out)
	}
	insert("synthetic-in-place-2", 9, boundary.Add(5*time.Second))
	for i := 5; i <= 7; i++ {
		observeZCode(t, cache, home, boundary.Add(time.Duration(i)*time.Minute))
	}
	if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 6003 || out != 6001+5+9 {
		t.Fatalf("every post-clear request counts once: got %d/%d, want 6003/6015", n, out)
	}
	after, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if !os.SameFile(before, after) {
		t.Fatal("setup: the appends changed the file")
	}
	if c := zcodeCursor(t, cache); c.RowID != 6004 || c.Anchor == "" || c.More || c.Unread {
		t.Fatalf("want the cursor anchored at the post-clear row 6004: rowID=%d anchor=%q more=%t unread=%t", c.RowID, c.Anchor, c.More, c.Unread)
	}
}

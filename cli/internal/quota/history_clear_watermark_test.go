// SPDX-License-Identifier: MIT
package quota

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// clearZCodeThenReplace: a synthetic ZCode database of n pre-clear requests is read, the tool's
// history cleared (watermark n), and the database replaced by a copy of n pre-clear requests. It
// returns the clear time and the replacement.
func clearZCodeThenReplace(t *testing.T, cache, home string, n int, now time.Time) (time.Time, *sql.DB) {
	t.Helper()
	seedPerfLedger(t, cache, now.Add(-time.Hour))
	path := filepath.Join(home, "db.sqlite")
	t.Setenv("MODELPLAN_ZCODE_DB", path)
	old := zcodeBatchDB(t, path, "synthetic-original", n, now.Add(-2*time.Minute))
	if err := speed.ObserveZCode(cache, home, speed.Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if err := EraseScope(Paths{Cache: cache}, "zai.local_history", true); err != nil {
		t.Fatal(err)
	}
	cleared := speed.LoadCleared(cache)
	if got := cleared.DBRows["zai"]; got != int64(n) {
		t.Fatalf("want the watermark %d, got %d", n, got)
	}
	old.Close()
	for _, p := range []string{path, path + "-wal", path + "-shm"} {
		if err := os.Remove(p); err != nil && !os.IsNotExist(err) {
			t.Fatal(err)
		}
	}
	return cleared.Tools["zai"], zcodeBatchDB(t, path, "synthetic-copied", n, now.Add(-90*time.Second))
}

// A replaced database with more than one read batch of post-clear requests below the watermark
// (6,001 rows below N = 6,002, whose own row is pre-clear) and one more post-clear request above
// it: bounded scans read the rows below the watermark in order, each counts exactly once, the
// cursor says there is more while some are unread, and the request above N counts once too.
func TestHistoryClearReplacedDatabaseBelowWatermarkExceedsBatch(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, home := t.TempDir(), t.TempDir()
	boundary, db := clearZCodeThenReplace(t, cache, home, 6002, time.Now().UTC())
	if _, err := db.Exec(`UPDATE model_usage SET started_at = ?, completed_at = ? WHERE rowid <= 6001`,
		boundary.Add(time.Second).UnixMilli(), boundary.Add(2*time.Second).UnixMilli()); err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(`INSERT INTO model_usage VALUES ('synthetic-above', 'synthetic-session', 'synthetic-model', ?, ?, 7)`,
		boundary.Add(3*time.Second).UnixMilli(), boundary.Add(4*time.Second).UnixMilli()); err != nil {
		t.Fatal(err)
	}
	for i := 1; i <= 6; i++ {
		if err := speed.ObserveZCode(cache, home, speed.Ingest{}, boundary.Add(time.Duration(i)*time.Minute)); err != nil {
			t.Fatal(err)
		}
		c := zcodeCursor(t, cache)
		_, _, n, out := ledgerTotals(t, cache, "zcode")
		t.Logf("scan=%d rowID=%d more=%t requests=%d output=%d", i, c.RowID, c.More, n, out)
		if i == 1 && (!c.More || n != 5000) {
			t.Fatalf("scan 1 reads one batch below the watermark and says there is more: more=%t requests=%d", c.More, n)
		}
		if i > 1 && c.More {
			t.Fatalf("scan %d: the rows below the watermark are read, but more=%t", i, c.More)
		}
	}
	if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 6002 || out != 6001+7 {
		t.Fatalf("every post-clear request counts once: got %d/%d, want 6002/6008", n, out)
	}
	if c := zcodeCursor(t, cache); c.RowID != 6003 || c.Anchor == "" {
		t.Fatalf("want the cursor anchored at the post-clear row 6003, got rowID=%d anchor=%q", c.RowID, c.Anchor)
	}
}

// The database is replaced only after the first post-clear scan, while the read position is still
// the pre-clear row at the watermark (so there is no anchor to notice the change): the count of
// post-clear rows up to the read position changes, so they are read, each counting once.
func TestHistoryClearDatabaseReplacedAfterFirstPostClearScan(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, home := t.TempDir(), t.TempDir()
	now := time.Now().UTC()
	seedPerfLedger(t, cache, now.Add(-time.Hour))
	path := filepath.Join(home, "db.sqlite")
	t.Setenv("MODELPLAN_ZCODE_DB", path)
	old := zcodeBatchDB(t, path, "synthetic-original", 10, now.Add(-2*time.Minute))
	if err := speed.ObserveZCode(cache, home, speed.Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if err := EraseScope(Paths{Cache: cache}, "zai.local_history", true); err != nil {
		t.Fatal(err)
	}
	boundary := speed.LoadCleared(cache).Tools["zai"]
	if err := speed.ObserveZCode(cache, home, speed.Ingest{}, boundary.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if c := zcodeCursor(t, cache); c.RowID != 10 || c.Anchor != "" || c.More {
		t.Fatalf("after the first post-clear scan: rowID=%d anchor=%q more=%t", c.RowID, c.Anchor, c.More)
	}
	old.Close()
	for _, p := range []string{path, path + "-wal", path + "-shm"} {
		os.Remove(p)
	}
	db := zcodeBatchDB(t, path, "synthetic-copied", 10, now.Add(-90*time.Second))
	if _, err := db.Exec(`UPDATE model_usage SET started_at = ?, completed_at = ?, output_tokens = 3 WHERE rowid IN (2, 5)`,
		boundary.Add(time.Second).UnixMilli(), boundary.Add(2*time.Second).UnixMilli()); err != nil {
		t.Fatal(err)
	}
	for i := 2; i <= 5; i++ {
		if err := speed.ObserveZCode(cache, home, speed.Ingest{}, boundary.Add(time.Duration(i)*time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 2 || out != 6 {
		t.Fatalf("each post-clear request of the later replacement counts once: got %d/%d, want 2/6", n, out)
	}
	if got := zcodeAnchors(t, cache); len(got) != 0 {
		t.Fatalf("no anchor for the pre-clear row at the watermark, got %v", got)
	}
}

// OpenCode: the row at the watermark has no readable start (null or not a number), which counts as
// pre-clear. After the clear and a replacement that repeats that row, no request anchor is kept for
// it (the erased anchor does not come back), and the post-clear message below it counts once.
func TestHistoryClearOpenCodeUnknownStartAtWatermarkKeepsNoAnchor(t *testing.T) {
	for name, unknown := range map[string]string{"null": `null`, "non-numeric": `"not a time"`} {
		t.Run(name, func(t *testing.T) {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_HISTORY", "")
			cache, home := t.TempDir(), t.TempDir()
			now := time.Now().UTC()
			seedPerfLedger(t, cache, now.Add(-time.Hour))
			path := filepath.Join(home, "opencode.db")
			t.Setenv("MODELPLAN_OPENCODE_DB", path)
			openDB := func() *sql.DB {
				t.Helper()
				db, err := sql.Open("sqlite", "file:"+path)
				if err != nil {
					t.Fatal(err)
				}
				t.Cleanup(func() { db.Close() })
				if _, err := db.Exec(`CREATE TABLE session_message (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, type TEXT NOT NULL, data TEXT NOT NULL)`); err != nil {
					t.Fatal(err)
				}
				return db
			}
			msg := func(db *sql.DB, id string, created string, out int) {
				t.Helper()
				data := fmt.Sprintf(`{"id":%q,"time":{"created":%s,"completed":%d},"model":{"id":"synthetic-model"},"tokens":{"output":%d}}`,
					id, created, now.Add(time.Hour).UnixMilli(), out)
				if _, err := db.Exec(`INSERT INTO session_message VALUES (?, 'synthetic-session', 'assistant', ?)`, "row-"+id, data); err != nil {
					t.Fatal(err)
				}
			}
			ms := func(at time.Time) string { return fmt.Sprint(at.UnixMilli()) }
			old := openDB()
			msg(old, "synthetic-old-0", ms(now.Add(-2*time.Minute)), 1)
			msg(old, "synthetic-old-1", ms(now.Add(-2*time.Minute)), 1)
			msg(old, "synthetic-old-2", unknown, 1)
			if err := speed.ObserveOpenCode(cache, home, speed.Ingest{}, now); err != nil {
				t.Fatal(err)
			}
			before, _ := speed.LoadPerf(cache)
			oldAnchor := ""
			for _, c := range before.Stores {
				oldAnchor = c.Anchor
			}
			if oldAnchor == "" {
				t.Fatal("setup: no anchor before the clear")
			}
			if err := EraseScope(Paths{Cache: cache}, "opencodego.local_history", true); err != nil {
				t.Fatal(err)
			}
			cleared := speed.LoadCleared(cache)
			boundary := cleared.Tools["opencodego"]
			if got := cleared.DBRows["opencodego"]; got != 3 {
				t.Fatalf("want the watermark 3, got %d", got)
			}
			old.Close()
			for _, p := range []string{path, path + "-wal", path + "-shm"} {
				os.Remove(p)
			}
			db := openDB()
			msg(db, "synthetic-replaced-new", ms(boundary.Add(time.Second)), 44)
			msg(db, "synthetic-copied", ms(now.Add(-90*time.Second)), 1)
			msg(db, "synthetic-old-2", unknown, 7)
			for i := 1; i <= 4; i++ {
				if err := speed.ObserveOpenCode(cache, home, speed.Ingest{}, boundary.Add(time.Duration(i)*time.Minute)); err != nil {
					t.Fatal(err)
				}
			}
			if _, _, n, out := ledgerTotals(t, cache, "opencode"); n != 1 || out != 44 {
				t.Fatalf("the post-clear message below the watermark counts once: got %d/%d, want 1/44", n, out)
			}
			ledger, ok := speed.LoadPerf(cache)
			if !ok {
				t.Fatal("perf.json unreadable")
			}
			for key, c := range ledger.Stores {
				if strings.HasPrefix(key, "opencode:") && c.Anchor != "" {
					t.Errorf("a row treated as pre-clear left a request anchor: rowID=%d sameAsBeforeClear=%t", c.RowID, c.Anchor == oldAnchor)
				}
			}
		})
	}
}

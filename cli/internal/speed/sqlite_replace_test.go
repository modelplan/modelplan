package speed

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// A database recreated at the same path numbers its rows from 1 again; its new requests must
// count whether it has fewer, as many or more rows than the old watermark, and a later read
// must not count anything twice (audit C, P2; macrevb-857-1).
func TestZCodeDatabaseRecreated(t *testing.T) {
	schema := `CREATE TABLE model_usage (id TEXT PRIMARY KEY, session_id TEXT, turn_id TEXT, model_id TEXT, started_at INTEGER,
		completed_at INTEGER, duration_ms INTEGER, input_tokens INTEGER, output_tokens INTEGER, reasoning_tokens INTEGER,
		cache_read_input_tokens INTEGER, cache_creation_input_tokens INTEGER, agent TEXT, mode TEXT);`
	for _, replaced := range []int{2, 5, 7} {
		t.Run(fmt.Sprint(replaced), func(t *testing.T) {
			utc(t)
			cache, home := t.TempDir(), t.TempDir()
			seedPerf(t, cache, t0.Add(-time.Minute))
			db := sqliteDB(t, ZCodeDB(home), schema)
			for i := 0; i < 5; i++ {
				start := t0.Add(time.Duration(i) * time.Second)
				exec(t, db, `INSERT INTO model_usage (id, session_id, model_id, started_at, completed_at, output_tokens) VALUES (?, 's', 'GLM-5.2', ?, ?, 100)`, fmt.Sprintf("old-%d", i), ms(start), ms(start.Add(500*time.Millisecond)))
			}
			if err := ObserveZCode(cache, home, Ingest{}, t0.Add(time.Minute)); err != nil {
				t.Fatal(err)
			}
			db.Close()
			for _, suffix := range []string{"", "-wal", "-shm"} {
				_ = os.Remove(ZCodeDB(home) + suffix)
			}
			db = sqliteDB(t, ZCodeDB(home), schema)
			for i := 0; i < replaced; i++ {
				start := t0.Add(2*time.Minute + time.Duration(i)*time.Second)
				exec(t, db, `INSERT INTO model_usage (id, session_id, model_id, started_at, completed_at, output_tokens) VALUES (?, 's', 'GLM-5.2', ?, ?, 100)`, fmt.Sprintf("new-%d", i), ms(start), ms(start.Add(time.Second)))
			}
			want := 5 + replaced
			for _, at := range []time.Duration{3 * time.Minute, 4 * time.Minute} {
				now := t0.Add(at)
				if err := ObserveZCode(cache, home, Ingest{}, now); err != nil {
					t.Fatal(err)
				}
				if d := view(t, cache, now).Daily(); len(d) != 1 || d[0].ObservedRequests != want || d[0].ObservedOutputTokens != int64(100*want) {
					t.Fatalf("at +%v: daily = %+v, want %d requests", at, d, want)
				}
				// A new request in the same database is still read after the reset.
				if at == 3*time.Minute {
					start := t0.Add(3*time.Minute + 10*time.Second)
					exec(t, db, `INSERT INTO model_usage (id, session_id, model_id, started_at, completed_at, output_tokens) VALUES ('later', 's', 'GLM-5.2', ?, ?, 100)`, ms(start), ms(start.Add(time.Second)))
					want++
				}
			}
		})
	}
}

// The shared scanner also recognises a replaced OpenCode database with more rows than the old
// watermark.
func TestOpenCodeDatabaseRecreated(t *testing.T) {
	utc(t)
	cache, home := t.TempDir(), t.TempDir()
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
	seedPerf(t, cache, t0.Add(-time.Minute))
	schema := `CREATE TABLE session_message (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, type TEXT NOT NULL, data TEXT NOT NULL);`
	msg := func(db *sql.DB, id string, start time.Time) {
		data := fmt.Sprintf(`{"id":%q,"time":{"created":%d,"completed":%d},"model":{"id":"m"},"tokens":{"output":100}}`, id, ms(start), ms(start.Add(time.Second)))
		exec(t, db, `INSERT INTO session_message VALUES (?, 'ses', 'assistant', ?)`, id, data)
	}
	db := sqliteDB(t, OpenCodeDB(home), schema)
	for i := 0; i < 3; i++ {
		msg(db, fmt.Sprintf("old-%d", i), t0.Add(time.Duration(i)*time.Second))
	}
	if err := ObserveOpenCode(cache, home, Ingest{}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	db.Close()
	for _, suffix := range []string{"", "-wal", "-shm"} {
		_ = os.Remove(OpenCodeDB(home) + suffix)
	}
	db = sqliteDB(t, OpenCodeDB(home), schema)
	for i := 0; i < 4; i++ {
		msg(db, fmt.Sprintf("new-%d", i), t0.Add(2*time.Minute+time.Duration(i)*time.Second))
	}
	for _, at := range []time.Duration{3 * time.Minute, 4 * time.Minute} {
		now := t0.Add(at)
		if err := ObserveOpenCode(cache, home, Ingest{}, now); err != nil {
			t.Fatal(err)
		}
		if d := view(t, cache, now).Daily(); len(d) != 1 || d[0].ObservedRequests != 7 {
			t.Fatalf("at +%v: daily = %+v, want 7 requests", at, d)
		}
	}
}

// stripAnchors turns the persisted cursors into the format released builds wrote: no anchor.
func stripAnchors(t *testing.T, cache string) {
	t.Helper()
	b, err := os.ReadFile(PerfPath(cache))
	if err != nil {
		t.Fatal(err)
	}
	var ledger map[string]json.RawMessage
	if err := json.Unmarshal(b, &ledger); err != nil {
		t.Fatal(err)
	}
	var stores map[string]map[string]json.RawMessage
	if err := json.Unmarshal(ledger["stores"], &stores); err != nil || len(stores) == 0 {
		t.Fatalf("no cursors: %v", err)
	}
	for _, c := range stores {
		if _, ok := c["anchor"]; !ok {
			t.Fatal("fixture: cursor has no anchor to strip")
		}
		delete(c, "anchor")
	}
	ledger["stores"], _ = json.Marshal(stores)
	b, _ = json.Marshal(ledger)
	if err := os.WriteFile(PerfPath(cache), b, 0o600); err != nil {
		t.Fatal(err)
	}
}

// A cursor saved by a build without anchors is migrated on its first read: a replacement as large
// as the watermark or larger is read from its first row, and an unchanged database that only grew
// counts nothing twice (macrevb-857-1, round 2).
func TestZCodeLegacyCursorRecreated(t *testing.T) {
	schema := `CREATE TABLE model_usage (id TEXT PRIMARY KEY, session_id TEXT, turn_id TEXT, model_id TEXT, started_at INTEGER,
		completed_at INTEGER, duration_ms INTEGER, input_tokens INTEGER, output_tokens INTEGER, reasoning_tokens INTEGER,
		cache_read_input_tokens INTEGER, cache_creation_input_tokens INTEGER, agent TEXT, mode TEXT);`
	insert := func(t *testing.T, db *sql.DB, id string, start time.Time) {
		exec(t, db, `INSERT INTO model_usage (id, session_id, model_id, started_at, completed_at, output_tokens) VALUES (?, 's', 'GLM-5.2', ?, ?, 100)`, id, ms(start), ms(start.Add(time.Second)))
	}
	for _, test := range []struct {
		name     string
		replaced int // 0: the same database, one more row
	}{{"equal", 5}, {"larger", 7}, {"unchanged", 0}} {
		t.Run(test.name, func(t *testing.T) {
			utc(t)
			cache, home := t.TempDir(), t.TempDir()
			seedPerf(t, cache, t0.Add(-time.Minute))
			db := sqliteDB(t, ZCodeDB(home), schema)
			for i := 0; i < 5; i++ {
				insert(t, db, fmt.Sprintf("old-%d", i), t0.Add(time.Duration(i)*time.Second))
			}
			if err := ObserveZCode(cache, home, Ingest{}, t0.Add(time.Minute)); err != nil {
				t.Fatal(err)
			}
			stripAnchors(t, cache)
			want := 5
			if test.replaced > 0 {
				db.Close()
				for _, suffix := range []string{"", "-wal", "-shm"} {
					_ = os.Remove(ZCodeDB(home) + suffix)
				}
				db = sqliteDB(t, ZCodeDB(home), schema)
				for i := 0; i < test.replaced; i++ {
					insert(t, db, fmt.Sprintf("new-%d", i), t0.Add(2*time.Minute+time.Duration(i)*time.Second))
				}
				want += test.replaced
			} else {
				insert(t, db, "grown", t0.Add(2*time.Minute))
				want++
			}
			for _, at := range []time.Duration{3 * time.Minute, 4 * time.Minute} {
				now := t0.Add(at)
				if err := ObserveZCode(cache, home, Ingest{}, now); err != nil {
					t.Fatal(err)
				}
				if d := view(t, cache, now).Daily(); len(d) != 1 || d[0].ObservedRequests != want || d[0].ObservedOutputTokens != int64(100*want) {
					t.Fatalf("at +%v: daily = %+v, want %d requests", at, d, want)
				}
				if at == 3*time.Minute {
					insert(t, db, "later", t0.Add(3*time.Minute+10*time.Second))
					want++
				}
			}
		})
	}
}

// Migrating a legacy cursor never counts a recorded request again, even when more requests
// than Seen can hold started within the lookback window (macrevb-857-2).
func TestZCodeLegacyCursorPastSeenLimit(t *testing.T) {
	utc(t)
	cache, home := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	db := sqliteDB(t, ZCodeDB(home), `CREATE TABLE model_usage (id TEXT PRIMARY KEY, session_id TEXT, turn_id TEXT, model_id TEXT, started_at INTEGER,
		completed_at INTEGER, duration_ms INTEGER, input_tokens INTEGER, output_tokens INTEGER, reasoning_tokens INTEGER,
		cache_read_input_tokens INTEGER, cache_creation_input_tokens INTEGER, agent TEXT, mode TEXT);`)
	insert := func(stmt interface {
		Exec(...any) (sql.Result, error)
	}, id string, start time.Time) {
		if _, err := stmt.Exec(id, ms(start), ms(start.Add(time.Second))); err != nil {
			t.Fatal(err)
		}
	}
	const q = `INSERT INTO model_usage (id, session_id, model_id, started_at, completed_at, output_tokens) VALUES (?, 's', 'GLM-5.2', ?, ?, 1)`
	n := maxSeenRows + dbBatch/2
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	stmt, err := tx.Prepare(q)
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i < n; i++ {
		insert(stmt, fmt.Sprintf("r-%d", i), t0.Add(time.Duration(i)*300*time.Millisecond)) // ~1h45m
	}
	stmt.Close()
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}
	now := t0.Add(2 * time.Hour)
	observe := func() {
		t.Helper()
		for i := 0; i < n/dbBatch+3; i++ {
			now = now.Add(time.Minute)
			if err := ObserveZCode(cache, home, Ingest{}, now); err != nil {
				t.Fatal(err)
			}
		}
	}
	requests := func() int {
		total := 0
		for _, d := range view(t, cache, now).Daily() {
			total += d.ObservedRequests
		}
		return total
	}
	observe()
	if got := requests(); got != n {
		t.Fatalf("first ingestion: %d requests, want %d", got, n)
	}
	l, _ := LoadPerf(cache)
	for _, c := range l.Stores {
		if len(c.Seen) < maxSeenRows {
			t.Fatalf("fixture: Seen holds %d ids, want it full", len(c.Seen))
		}
	}
	stripAnchors(t, cache)
	single, err := db.Prepare(q)
	if err != nil {
		t.Fatal(err)
	}
	defer single.Close()
	insert(single, "after-upgrade", now.Add(-10*time.Second))
	observe()
	if got := requests(); got != n+1 {
		t.Fatalf("after migration: %d requests, want %d", got, n+1)
	}
	insert(single, "later", now.Add(-5*time.Second))
	observe()
	if got := requests(); got != n+2 {
		t.Fatalf("after a later request: %d requests, want %d", got, n+2)
	}
}

// A request still running when a legacy cursor is migrated, though it started before the newest
// counted one, counts once when it finishes.
func TestZCodeLegacyCursorKeepsRunningRequest(t *testing.T) {
	utc(t)
	cache, home := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	db := sqliteDB(t, ZCodeDB(home), `CREATE TABLE model_usage (id TEXT PRIMARY KEY, session_id TEXT, turn_id TEXT, model_id TEXT, started_at INTEGER,
		completed_at INTEGER, duration_ms INTEGER, input_tokens INTEGER, output_tokens INTEGER, reasoning_tokens INTEGER,
		cache_read_input_tokens INTEGER, cache_creation_input_tokens INTEGER, agent TEXT, mode TEXT);`)
	exec(t, db, `INSERT INTO model_usage (id, session_id, model_id, started_at, output_tokens) VALUES ('long', 's', 'GLM-5.2', ?, 0)`, ms(t0))
	exec(t, db, `INSERT INTO model_usage (id, session_id, model_id, started_at, completed_at, output_tokens) VALUES ('short', 's', 'GLM-5.2', ?, ?, 100)`, ms(t0.Add(time.Second)), ms(t0.Add(2*time.Second)))
	if err := ObserveZCode(cache, home, Ingest{}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	stripAnchors(t, cache)
	exec(t, db, `UPDATE model_usage SET completed_at = ?, output_tokens = 100 WHERE id = 'long'`, ms(t0.Add(90*time.Second)))
	for _, at := range []time.Duration{2 * time.Minute, 3 * time.Minute} {
		now := t0.Add(at)
		if err := ObserveZCode(cache, home, Ingest{}, now); err != nil {
			t.Fatal(err)
		}
		if d := view(t, cache, now).Daily(); len(d) != 1 || d[0].ObservedRequests != 2 {
			t.Fatalf("at +%v: daily = %+v, want 2 requests", at, d)
		}
	}
}

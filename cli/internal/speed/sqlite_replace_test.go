package speed

import (
	"fmt"
	"os"
	"testing"
	"time"
)

// A database recreated at the same path starts its rowids again; its new requests must count
// (audit C, P2).
func TestZCodeDatabaseRecreated(t *testing.T) {
	utc(t)
	cache, home := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	schema := `CREATE TABLE model_usage (id TEXT PRIMARY KEY, session_id TEXT, turn_id TEXT, model_id TEXT, started_at INTEGER,
		completed_at INTEGER, duration_ms INTEGER, input_tokens INTEGER, output_tokens INTEGER, reasoning_tokens INTEGER,
		cache_read_input_tokens INTEGER, cache_creation_input_tokens INTEGER, agent TEXT, mode TEXT);`
	db := sqliteDB(t, ZCodeDB(home), schema)
	for i := 0; i < 5; i++ {
		start, end := t0.Add(time.Duration(i)*time.Second), t0.Add(time.Duration(i)*time.Second+500*time.Millisecond)
		exec(t, db, `INSERT INTO model_usage (id, session_id, model_id, started_at, completed_at, output_tokens) VALUES (?, 's', 'GLM-5.2', ?, ?, 100)`, fmt.Sprintf("old-%d", i), ms(start), ms(end))
	}
	if err := ObserveZCode(cache, home, Ingest{}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	db.Close()
	for _, suffix := range []string{"", "-wal", "-shm"} {
		_ = os.Remove(ZCodeDB(home) + suffix)
	}
	db = sqliteDB(t, ZCodeDB(home), schema)
	for i := 0; i < 2; i++ {
		start := t0.Add(2*time.Minute + time.Duration(i)*time.Second)
		exec(t, db, `INSERT INTO model_usage (id, session_id, model_id, started_at, completed_at, output_tokens) VALUES (?, 's', 'GLM-5.2', ?, ?, 100)`, fmt.Sprintf("new-%d", i), ms(start), ms(start.Add(time.Second)))
	}
	now := t0.Add(3 * time.Minute)
	if err := ObserveZCode(cache, home, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if d := view(t, cache, now).Daily(); len(d) != 1 || d[0].ObservedRequests != 7 || d[0].ObservedOutputTokens != 700 {
		t.Fatalf("daily = %+v", d)
	}
}

package speed

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func sqliteDB(t *testing.T, path, schema string) *sql.DB {
	t.Helper()
	os.MkdirAll(filepath.Dir(path), 0o700)
	db, err := sql.Open("sqlite", "file:"+path)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := db.Exec(schema); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

func exec(t *testing.T, db *sql.DB, q string, args ...any) {
	t.Helper()
	if _, err := db.Exec(q, args...); err != nil {
		t.Fatal(err)
	}
}

func ms(at time.Time) int64 { return at.UnixMilli() }

func TestZCodeDatabase(t *testing.T) {
	utc(t)
	cache, home, root := t.TempDir(), t.TempDir(), t.TempDir()
	repo, _ := gitRepo(t, root)
	seedPerf(t, cache, t0.Add(-time.Minute))
	db := sqliteDB(t, ZCodeDB(home), `
		CREATE TABLE model_usage (id TEXT PRIMARY KEY, session_id TEXT, turn_id TEXT, model_id TEXT, started_at INTEGER,
			completed_at INTEGER, duration_ms INTEGER, input_tokens INTEGER, output_tokens INTEGER, reasoning_tokens INTEGER,
			cache_read_input_tokens INTEGER, cache_creation_input_tokens INTEGER, agent TEXT, mode TEXT);
		CREATE TABLE session (id TEXT PRIMARY KEY, directory TEXT, path TEXT, title TEXT);`)
	exec(t, db, `INSERT INTO session VALUES ('z-1', ?, '', 'Secret title')`, repo)
	row := func(id string, start time.Time, end *time.Time, out int) {
		var e any
		if end != nil {
			e = ms(*end)
		}
		exec(t, db, `INSERT INTO model_usage (id, session_id, turn_id, model_id, started_at, completed_at, input_tokens, output_tokens, reasoning_tokens)
			VALUES (?, 'z-1', 't', 'GLM-5.2', ?, ?, 9000, ?, 40)`, id, ms(start), e, out)
	}
	done := t0.Add(20 * time.Second)
	row("before", t0.Add(-time.Hour), &done, 999) // before the ledger started
	row("r1", t0, &done, 300)
	row("r2", t0.Add(30*time.Second), nil, 0) // still running
	now := t0.Add(time.Minute)
	if err := ObserveZCode(cache, home, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	v := view(t, cache, now)
	if d := v.Daily(); len(d) != 1 || d[0].Source != "zcode" || d[0].Model != "GLM-5.2" || d[0].ObservedOutputTokens != 300 || d[0].ObservedRequests != 1 {
		t.Fatalf("daily = %+v", d)
	}
	if live := v.LiveSessions(); len(live) != 1 || live[0].Status != "running" || live[0].EffortStatus != "unreported" || live[0].SubscriptionRef != nil || live[0].Rate.Value != nil {
		t.Fatalf("ZCode live %+v", live)
	}
	// The running request finishes; it counts once, and nothing counts twice on a re-read.
	exec(t, db, `UPDATE model_usage SET completed_at = ?, output_tokens = 500 WHERE id = 'r2'`, ms(t0.Add(50*time.Second)))
	for _, at := range []time.Duration{2 * time.Minute, 3 * time.Minute} {
		if err := ObserveZCode(cache, home, Ingest{}, t0.Add(at)); err != nil {
			t.Fatal(err)
		}
	}
	v = view(t, cache, t0.Add(3*time.Minute))
	w := v.Projects().Recent7d
	if w.TotalObservedOutputTokens != 800 || w.Projects != 1 || w.Top[0].Sessions != 1 {
		t.Fatalf("projects = %+v", w)
	}
	if r, _ := projector(cache, false)(repo); r != w.Top[0].Ref {
		t.Fatal("the session's directory names its project")
	}
	// End-to-end times include the wait for the first token: never a generation sample.
	if r := v.WorkloadRate("zcode"); r.N != 0 || r.Value != nil {
		t.Fatalf("rate = %+v", r)
	}
	b, _ := os.ReadFile(PerfPath(cache))
	for _, leak := range []string{"Secret title", "z-1", root, `"r1"`} {
		if containsBytes(b, leak) {
			t.Fatalf("%q in perf.json", leak)
		}
	}
}

func TestOpenCodeDatabase(t *testing.T) {
	utc(t)
	cache, home, root := t.TempDir(), t.TempDir(), t.TempDir()
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
	seedPerf(t, cache, t0.Add(-time.Minute))
	db := sqliteDB(t, OpenCodeDB(home), `
		CREATE TABLE session_v2 (id TEXT PRIMARY KEY, directory TEXT NOT NULL, title TEXT);
		CREATE TABLE session_message (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, type TEXT NOT NULL, data TEXT NOT NULL);`)
	exec(t, db, `INSERT INTO session_v2 VALUES ('ses-a', ?, 'title'), ('ses-fork', ?, 'title')`, root, root)
	msg := func(row, session, id string, start time.Time, done bool, out, reasoning int) {
		completed := ""
		if done {
			completed = fmt.Sprintf(`,"completed":%d`, ms(start.Add(4*time.Second)))
		}
		data := fmt.Sprintf(`{"id":%q,"time":{"created":%d%s},"agent":"build","model":{"id":"claude-sonnet-4-5","providerID":"anthropic","variant":"high"},"content":[{"text":"secret reply"}],"tokens":{"input":5000,"output":%d,"reasoning":%d,"cache":{"read":1,"write":2}}}`,
			id, ms(start), completed, out, reasoning)
		exec(t, db, `INSERT INTO session_message VALUES (?, ?, 'assistant', ?)`, row, session, data)
	}
	exec(t, db, `INSERT INTO session_message VALUES ('u1', 'ses-a', 'user', '{"time":{"created":1}}')`)
	msg("row-1", "ses-a", "msg-1", t0, true, 200, 50)
	msg("row-2", "ses-a", "msg-2", t0.Add(10*time.Second), false, 0, 0)
	if err := ObserveOpenCode(cache, home, Ingest{}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if live := view(t, cache, t0.Add(time.Minute)).LiveSessions(); len(live) != 1 || live[0].Status != "running" || live[0].Rate.Value != nil {
		t.Fatalf("OpenCode live %+v", live)
	}
	// msg-2 finishes; a fork copies msg-1 into another session; neither the copy nor a re-read
	// counts twice.
	exec(t, db, `UPDATE session_message SET data = json_set(json_set(data, '$.time.completed', ?), '$.tokens.output', 100) WHERE id = 'row-2'`, ms(t0.Add(15*time.Second)))
	msg("row-3", "ses-fork", "msg-1", t0, true, 200, 50)
	for _, at := range []time.Duration{2 * time.Minute, 3 * time.Minute} {
		if err := ObserveOpenCode(cache, home, Ingest{}, t0.Add(at)); err != nil {
			t.Fatal(err)
		}
	}
	v := view(t, cache, t0.Add(3*time.Minute))
	d := v.Daily()
	if len(d) != 1 || d[0].Source != "opencode" || d[0].Model != "claude-sonnet-4-5" || d[0].ObservedOutputTokens != 350 || d[0].ObservedRequests != 2 {
		t.Fatalf("daily = %+v", d)
	}
	r := v.Ranking().Recent7d
	if r.Sessions != 1 || r.Top[0].Configs[0].EffortStatus != "unreported" || r.Top[0].ProjectRef == nil {
		t.Fatalf("ranking = %+v", r)
	}
	b, _ := os.ReadFile(PerfPath(cache))
	for _, leak := range []string{"secret reply", "ses-a", "msg-1", root} {
		if containsBytes(b, leak) {
			t.Fatalf("%q in perf.json", leak)
		}
	}
}

func TestDatabaseThrottleAndAbsence(t *testing.T) {
	utc(t)
	cache, home := t.TempDir(), t.TempDir()
	if err := ObserveZCode(cache, home, Ingest{}, t0); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(PerfPath(cache)); !os.IsNotExist(err) {
		t.Fatal("no ZCode database: nothing written")
	}
	if _, err := os.Stat(ZCodeDB(home)); !os.IsNotExist(err) {
		t.Fatal("a database was created")
	}
}

func containsBytes(b []byte, s string) bool { return len(s) > 0 && bytesContains(b, s) }

func bytesContains(b []byte, s string) bool {
	for i := 0; i+len(s) <= len(b); i++ {
		if string(b[i:i+len(s)]) == s {
			return true
		}
	}
	return false
}

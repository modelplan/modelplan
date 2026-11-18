package speed

import (
	"fmt"
	"path/filepath"
	"testing"
	"time"
)

// OpenCode V2 accounting matches ccusage@58866ba6 (rust/adapters/opencode): a completed
// compaction counts, a running one does not; rows a fork copied from its parent (seq at or
// below the boundary) do not count again although their JSON ids are new; a reported total
// the buckets leave unexplained is output. Redacted, real-shaped rows.
//
// Hand check against ccusage's message_value_to_entry_inner + apply_total_token_fallback:
//
//	p1 assistant   in 100  out 200 + reasoning 50  read 1000 write 10   -> total 1360
//	p2 assistant   all parts 0, total 500 -> output 500                  -> total  500
//	p3 compaction  completed, in 3000 out 400                           -> total 3400
//	p4 compaction  running                                              -> not counted
//	f1, f2         fork copies of p1, p2 (seq <= seq of p2, "through")  -> not counted
//	f3 assistant   fork's own step, in 7 out 3                          -> total   10
//
// ccusage total 5270 = input 3107 + cache read 1000 + cache write 10 + output 1103 + reasoning 50.
// The ledger keeps output with reasoning: 1153. The earlier reader gave 503 (no p2 fallback, no
// p3, f1 counted again).
func TestOpenCodeMatchesCcusageAccounting(t *testing.T) {
	utc(t)
	cache, home := t.TempDir(), t.TempDir()
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
	seedPerf(t, cache, t0.Add(-time.Minute))
	db := sqliteDB(t, OpenCodeDB(home), `
		CREATE TABLE session_v2 (id TEXT PRIMARY KEY, directory TEXT NOT NULL, project_id TEXT, fork_session_id TEXT, fork_boundary TEXT);
		CREATE TABLE session_message (id TEXT PRIMARY KEY, session_id TEXT NOT NULL, type TEXT NOT NULL, seq INTEGER NOT NULL, data TEXT NOT NULL);`)
	exec(t, db, `INSERT INTO session_v2 VALUES ('ses-p', '/redacted', NULL, NULL, NULL), ('ses-f', '/redacted', NULL, 'ses-p', '{"type":"through","messageID":"p2"}')`)
	row := func(id, session, typ string, seq int, at time.Time, extra, tokens string) {
		data := fmt.Sprintf(`{"id":"msg-%s","time":{"created":%d%s},"model":{"id":"claude-sonnet-4-5","providerID":"anthropic"},"content":[{"text":"[redacted]"}],"tokens":%s}`,
			id, ms(at), extra, tokens)
		exec(t, db, `INSERT INTO session_message VALUES (?, ?, ?, ?, ?)`, id, session, typ, seq, data)
	}
	done := func(at time.Time) string { return fmt.Sprintf(`,"completed":%d`, ms(at.Add(3*time.Second))) }
	p1 := `{"input":100,"output":200,"reasoning":50,"cache":{"read":1000,"write":10}}`
	p2 := `{"input":0,"output":0,"reasoning":0,"cache":{"read":0,"write":0},"total":500}`
	row("p1", "ses-p", "assistant", 1, t0, done(t0), p1)
	row("p2", "ses-p", "assistant", 2, t0.Add(10*time.Second), done(t0.Add(10*time.Second)), p2)
	// A compaction records no completion time; its status says whether it finished.
	row("p3", "ses-p", "compaction", 3, t0.Add(20*time.Second), "", `{"input":3000,"output":400,"reasoning":0,"cache":{"read":0,"write":0}}`)
	row("p4", "ses-p", "compaction", 4, t0.Add(25*time.Second), "", `{"input":9000,"output":900,"reasoning":0,"cache":{"read":0,"write":0}}`)
	exec(t, db, `UPDATE session_message SET data = json_set(data, '$.status', CASE id WHEN 'p3' THEN 'completed' ELSE 'running' END) WHERE type = 'compaction'`)
	row("f1", "ses-f", "assistant", 1, t0, done(t0), p1)
	row("f2", "ses-f", "assistant", 2, t0.Add(10*time.Second), done(t0.Add(10*time.Second)), p2)
	row("f3", "ses-f", "assistant", 3, t0.Add(30*time.Second), done(t0.Add(30*time.Second)), `{"input":7,"output":3,"reasoning":0,"cache":{"read":0,"write":0}}`)
	for _, at := range []time.Duration{time.Minute, 2 * time.Minute} {
		if err := ObserveOpenCode(cache, home, Ingest{}, t0.Add(at)); err != nil {
			t.Fatal(err)
		}
	}
	d := view(t, cache, t0.Add(2*time.Minute)).Daily()
	if len(d) != 1 {
		t.Fatalf("daily = %+v", d)
	}
	got := d[0]
	if got.ObservedOutputTokens != 1153 || got.ObservedRequests != 4 {
		t.Fatalf("output %d requests %d, want ccusage's 1153 (output+reasoning) over 4 records", got.ObservedOutputTokens, got.ObservedRequests)
	}
	if got.InputTokens == nil || *got.InputTokens != 3107 || got.CacheReadTokens == nil || *got.CacheReadTokens != 1000 || got.CacheWriteTokens == nil || *got.CacheWriteTokens != 10 {
		t.Fatalf("token kinds = %+v", got.TokenKinds)
	}
	if total := *got.InputTokens + *got.CacheReadTokens + *got.CacheWriteTokens + got.ObservedOutputTokens; total != 5270 {
		t.Fatalf("total %d, want ccusage's 5270", total)
	}
}

// macrevb-1017-2: row 2 moves the cursor past a still-running compaction.
// A status-only update of row 1 must remain observable across repeated scans.
func TestOpenCodeRunningCompactionFinishesOnce(t *testing.T) {
	for _, withCompletionTime := range []bool{false, true} {
		t.Run(fmt.Sprintf("completion-time-%t", withCompletionTime), func(t *testing.T) {
			utc(t)
			cache, home := t.TempDir(), t.TempDir()
			t.Setenv("XDG_DATA_HOME", filepath.Join(home, "data"))
			seedPerf(t, cache, t0.Add(-time.Minute))
			db := sqliteDB(t, OpenCodeDB(home), `CREATE TABLE session_message (session_id TEXT, type TEXT, data TEXT);`)
			completion := ""
			if withCompletionTime {
				completion = fmt.Sprintf(`,"completed":%d`, ms(t0.Add(time.Second)))
			}
			running := fmt.Sprintf(`{"id":"compaction","status":"running","time":{"created":%d%s},"model":{"id":"m"},"tokens":{"input":100,"output":50}}`, ms(t0), completion)
			assistant := fmt.Sprintf(`{"id":"assistant","time":{"created":%d,"completed":%d},"model":{"id":"m"},"tokens":{"output":3}}`, ms(t0.Add(10*time.Second)), ms(t0.Add(11*time.Second)))
			exec(t, db, `INSERT INTO session_message VALUES ('s','compaction',?),('s','assistant',?)`, running, assistant)
			assertTotals := func(at time.Time, requests int, output int64) {
				t.Helper()
				if err := ObserveOpenCode(cache, home, Ingest{}, at); err != nil {
					t.Fatal(err)
				}
				daily := view(t, cache, at).Daily()
				if len(daily) != 1 || daily[0].ObservedRequests != requests || daily[0].ObservedOutputTokens != output {
					t.Fatalf("requests/output want %d/%d, got %+v", requests, output, daily)
				}
			}
			assertTotals(t0.Add(time.Minute), 1, 3)
			exec(t, db, `UPDATE session_message SET data=json_set(data,'$.status','completed') WHERE type='compaction'`)
			assertTotals(t0.Add(2*time.Minute), 2, 53)
			assertTotals(t0.Add(3*time.Minute), 2, 53)
		})
	}
}

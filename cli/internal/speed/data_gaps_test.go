package speed

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func count(n int64) *int64 { return &n }
func TestTokenKindsFromClaudeFixture(t *testing.T) {
	utc(t)
	cache := t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(t.TempDir(), "cc.jsonl")
	reply := ccReply(5, "PRIVATE-ID-CANARY", "m", "high", "", 300, 2000, "end_turn", false)
	reply = strings.Replace(reply, `"input_tokens":5`, `"input_tokens":5,"cache_read_input_tokens":100,"cache_creation_input_tokens":20`, 1)
	writeLines(t, p, ccPrompt(0), reply, reply, ccPrompt(60))
	ObserveClaude(cache, p, false, Ingest{}, t0.Add(2*time.Minute))
	r := view(t, cache, t0.Add(2*time.Minute)).Ledger.Rows[0]
	if r.ObservedRequests != 1 || r.ObservedOutputTokens != 300 || r.InputTokens == nil || *r.InputTokens != 5 || *r.CacheReadTokens != 100 || *r.CacheWriteTokens != 20 {
		t.Fatalf("%+v", r)
	}
	b, _ := os.ReadFile(PerfPath(cache))
	for _, canary := range []string{"PRIVATE-ID-CANARY", "question", "answer", p} {
		if strings.Contains(string(b), canary) {
			t.Fatal("content leaked", canary)
		}
	}
}
func TestCodexKindsLastTotalAndDuplicateUsage(t *testing.T) {
	utc(t)
	cache := t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(t.TempDir(), "cx.jsonl")
	writeLines(t, p, cx(0, "event_msg", `{"type":"task_started"}`), cx(0, "turn_context", high),
		cx(1, "event_msg", `{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":500,"output_tokens":100}}}`),
		cx(2, "response_item", `{"type":"function_call_output","output":"CONTENT-CANARY"}`),
		cx(4, "event_msg", `{"type":"token_count","info":{"total_token_usage":{"input_tokens":1100,"cached_input_tokens":540,"output_tokens":300}}}`),
		cx(4, "event_msg", `{"type":"token_count","info":{"total_token_usage":{"input_tokens":1100,"cached_input_tokens":540,"output_tokens":300}}}`),
		cx(5, "response_item", `{"type":"function_call_output","output":"CONTENT-CANARY"}`),
		cx(6, "token_usage_record", `{"usage":{"input_tokens":200,"output_tokens":400}}`),
		cx(6, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"input_tokens":200,"cached_input_tokens":100,"output_tokens":400}}}`),
		cx(7, "event_msg", `{"type":"task_complete","duration_ms":7000}`))
	observeCx(t, cache, t0.Add(time.Minute), p)
	r := view(t, cache, t0.Add(time.Minute)).Ledger.Rows[0]
	if r.ObservedRequests != 2 || r.ObservedOutputTokens != 600 || r.InputTokens == nil || *r.InputTokens != 160 || r.CacheReadTokens == nil || *r.CacheReadTokens != 140 || r.CacheWriteTokens != nil {
		t.Fatalf("%+v", r)
	}
}
func TestTodaySumsAndLegacyUnknownKinds(t *testing.T) {
	utc(t)
	now := t0.Add(time.Hour)
	last := now.Add(-time.Minute)
	a := PerfRow{TokenKinds: TokenKinds{InputTokens: count(20), CacheReadTokens: count(0)}, Day: day(now), Source: "codex", Model: "a", ObservedRequests: 5, EligibleRequests: 5, EligibleOutputTokens: 1000, GenMs: 10000, LastAt: &last}
	b := a
	b.Model = "b"
	b.EligibleOutputTokens = 500
	b.GenMs = 20000
	old := a
	old.Day = day(now.AddDate(0, 0, -1))
	old.GenMs = 900000
	v := PerfView{OK: true, Recording: true, Now: now, Ledger: PerfLedger{Since: now.AddDate(0, 0, -2), Rows: []PerfRow{a, b, old}}}
	totals := v.TodayTotals()
	if len(totals) != 1 || totals[0].Sums.EligibleOutputTokens != 1500 || totals[0].Sums.GenMs != 30000 || *totals[0].Sums.CacheReadTokens != 0 {
		t.Fatalf("%+v", totals)
	}
	if r := v.Stats()[0].Windows.Today.Metrics.GenerationTps; r.Value == nil || *r.Value != 100 {
		t.Fatalf("%+v", r)
	}
	var legacy PerfRow
	if err := json.Unmarshal([]byte(`{"day":"2026-10-17","source":"codex","model":"a","observedRequests":1}`), &legacy); err != nil {
		t.Fatal(err)
	}
	sums := PerfSums{}
	sums.add(&legacy)
	sums.add(&a)
	if sums.InputTokens != nil || sums.CacheReadTokens != nil {
		t.Fatal("partial known sums must not replace missing old values")
	}
}
func TestHourlyMidnightDSTAndCap(t *testing.T) {
	old := time.Local
	t.Cleanup(func() { time.Local = old })
	loc, err := time.LoadLocation("America/New_York")
	if err != nil {
		t.Fatal(err)
	}
	time.Local = loc
	start := time.Date(2026, 11, 1, 0, 0, 0, 0, loc)
	now := time.Date(2026, 11, 2, 23, 30, 0, 0, loc)
	l := PerfLedger{}
	cfg := config{model: "m"}
	for at := start; !at.After(now); at = at.Add(time.Hour) {
		l.addHourly("codex", request{cfg: cfg, end: at.Add(time.Minute), out: 1}, at)
	}
	l.pruneHourly(now)
	if len(l.Hourly) != 48 {
		t.Fatalf("%d", len(l.Hourly))
	}
	seen := map[string]bool{}
	for _, r := range l.Hourly {
		seen[r.Hour] = true
	}
	if !seen["2026-11-01T01:00:00-04:00"] || !seen["2026-11-01T01:00:00-05:00"] {
		t.Fatalf("repeated hour collapsed: %v", seen)
	}
	if got := (PerfView{OK: true, Ledger: l, Now: now.AddDate(0, 0, 2)}).Hourly(); len(got) != 0 {
		t.Fatal("old hourly rows escaped two-day retention")
	}
	time.Local = time.FixedZone("quarter", 5*3600+45*60)
	if h := localHour(time.Date(2026, 10, 23, 0, 13, 0, 0, time.Local)); h != "2026-10-23T00:00:00+05:45" {
		t.Fatal(h)
	}
}
func TestConcurrentLiveSessionsAndShortRate(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	parent := filepath.Join(dir, "parent.jsonl")
	child := filepath.Join(dir, "child.jsonl")
	codex := filepath.Join(dir, "cx.jsonl")
	lines := []string{ccPrompt(0)}
	for i := 0; i < 5; i++ {
		at := float64(i*4 + 3)
		lines = append(lines, ccReply(at, fmt.Sprintf("REQ-CANARY-%d", i), "m", "high", "", 100, 1000, "tool_use", false))
		if i < 4 {
			lines = append(lines, ccTool(at+1))
		}
	}
	writeLines(t, parent, lines...)
	writeLines(t, child, strings.ReplaceAll(ccPrompt(1), `"isSidechain":false`, `"isSidechain":true`), ccReply(18, "CHILD-CANARY", "child-model", "low", "", 90, 1000, "end_turn", true))
	writeLines(t, codex, cx(1, "session_meta", `{"id":"ID-CANARY","source":{"subagent":"review"}}`), cx(1, "event_msg", `{"type":"task_started"}`), cx(2, "turn_context", high))
	logs := []LiveLog{{Path: parent, Source: "claude-code"}, {Path: child, Source: "claude-code", Sidechain: true}, {Path: codex, Source: "codex"}}
	now := t0.Add(25 * time.Second)
	if err := ObserveLive(cache, logs, false, nil, now); err != nil {
		t.Fatal(err)
	}
	v := view(t, cache, now)
	sessions := v.LiveSessions()
	if len(sessions) != 3 {
		t.Fatalf("%+v", sessions)
	}
	refs := map[string]bool{}
	for _, s := range sessions {
		refs[s.Ref] = true
		if s.Model == "m" {
			if s.Status != "running" || s.Rate.N != 5 || s.Rate.Value == nil || *s.Rate.Value != 100 || s.Rate.Window != "60s" {
				t.Fatalf("%+v", s)
			}
		}
		if s.Model == "child-model" && (s.Status != "idle" || s.Rate.Status != "insufficient") {
			t.Fatalf("%+v", s)
		}
	}
	if len(refs) != 3 || len(v.Ledger.Rows) != 0 {
		t.Fatal("live reading must not duplicate historical requests")
	}
	b, _ := json.Marshal(sessions)
	for _, canary := range []string{"ID-CANARY", "CHILD-CANARY", "REQ-CANARY", dir, "answer", "question"} {
		if strings.Contains(string(b), canary) {
			t.Fatal("live leak", canary)
		}
	}
	v.Now = now.Add(time.Minute)
	for _, s := range v.LiveSessions() {
		if s.Rate.Value != nil {
			t.Fatal("old 60s samples retained")
		}
	}
	v.Now = now.Add(LiveWithin)
	if len(v.LiveSessions()) != 0 {
		t.Fatal("stale sessions retained")
	}
	t.Setenv("MODELPLAN_HISTORY", "off")
	empty := t.TempDir()
	ObserveLive(empty, logs, false, nil, now)
	if _, err := os.Stat(PerfPath(empty)); !os.IsNotExist(err) {
		t.Fatal("history-off recorded live observations")
	}
}

func TestCodexOptionalCacheWritesAndResets(t *testing.T) {
	u := &cxUsage{Input: count(100), Cached: count(40), Write: count(10), Output: count(200)}
	k := u.kinds()
	if *k.InputTokens != 60 || *k.CacheReadTokens != 40 || *k.CacheWriteTokens != 10 {
		t.Fatal(k)
	}
	d := usageDelta(u, &cxUsage{Input: count(80), Cached: count(30), Write: count(8), Output: count(100)})
	if d == nil || *d.Write != 2 || *d.kinds().InputTokens != 10 {
		t.Fatal(d)
	}
	if usageDelta(&cxUsage{Output: count(1)}, u) != nil {
		t.Fatal("reset cumulative usage cannot become a negative request")
	}
}
func TestDatabaseTokenKindsAndLiveUnknownRate(t *testing.T) {
	utc(t)
	cache, home := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	db := sqliteDB(t, ZCodeDB(home), `CREATE TABLE model_usage (id TEXT,session_id TEXT,model_id TEXT,started_at INTEGER,completed_at INTEGER,output_tokens INTEGER,input_tokens INTEGER,cache_read_input_tokens INTEGER,cache_creation_input_tokens INTEGER);`)
	exec(t, db, `INSERT INTO model_usage VALUES ('PRIVATE-DB-ID','PRIVATE-SESSION-ID','db-model',?,?,?,?,?,?)`, ms(t0), ms(t0.Add(time.Second)), 200, 100, 30, 10)
	// Six placeholders after the three identity/config values.
	if err := ObserveZCode(cache, home, Ingest{}, t0.Add(10*time.Second)); err != nil {
		t.Fatal(err)
	}
	v := view(t, cache, t0.Add(10*time.Second))
	if len(v.Ledger.Rows) != 1 {
		t.Fatal(v.Ledger)
	}
	k := v.Ledger.Rows[0].TokenKinds
	if k.InputTokens == nil || *k.InputTokens != 100 || *k.CacheReadTokens != 30 || *k.CacheWriteTokens != 10 {
		t.Fatal(k)
	}
	live := v.LiveSessions()
	if len(live) != 1 || live[0].Rate.Value != nil || live[0].Rate.Reason != "no-eligible-generation" {
		t.Fatal(live)
	}
	b, _ := json.Marshal(live)
	if strings.Contains(string(b), "PRIVATE-") {
		t.Fatal(string(b))
	}
}

func TestNewLedgerStillShowsRecentPendingDatabaseSession(t *testing.T) {
	utc(t)
	cache, home := t.TempDir(), t.TempDir()
	db := sqliteDB(t, ZCodeDB(home), `CREATE TABLE model_usage (id TEXT,session_id TEXT,model_id TEXT,started_at INTEGER,completed_at INTEGER,output_tokens INTEGER);`)
	exec(t, db, `INSERT INTO model_usage VALUES ('pending-private','session-private','m',?,NULL,0)`, ms(t0))
	ObserveZCode(cache, home, Ingest{}, t0.Add(10*time.Second))
	v := view(t, cache, t0.Add(10*time.Second))
	if got := v.LiveSessions(); len(got) != 1 || got[0].Status != "running" {
		t.Fatal(got)
	}
	exec(t, db, `UPDATE model_usage SET completed_at=?,output_tokens=200`, ms(t0.Add(20*time.Second)))
	ObserveZCode(cache, home, Ingest{}, t0.Add(50*time.Second))
	v = view(t, cache, t0.Add(50*time.Second))
	if len(v.Ledger.Rows) != 0 {
		t.Fatal("pre-since work was retroactively counted")
	}
	if got := v.LiveSessions(); len(got) != 1 || got[0].Status != "idle" {
		t.Fatal(got)
	}
}
func TestLiveClockBoundariesAndDiscovery(t *testing.T) {
	utc(t)
	now := t0.Add(time.Minute)
	v := PerfView{OK: true, Recording: true, Now: now, Ledger: PerfLedger{Live: []LiveRecord{{Ref: "opaque", Source: "codex", Model: "m", LastAt: now.Add(-10 * time.Second), Samples: []liveSample{{At: now.Add(-20 * time.Second)}}}}}}
	want := now.Add(40 * time.Second)
	found := false
	for _, b := range v.Boundaries() {
		if b.Equal(want) {
			found = true
		}
	}
	if !found {
		t.Fatal(v.Boundaries())
	}
	home := t.TempDir()
	parent := filepath.Join(home, "projects", "p", "main.jsonl")
	child := filepath.Join(home, "projects", "p", "s", "subagents", "child.jsonl")
	for _, p := range []string{parent, child} {
		os.MkdirAll(filepath.Dir(p), 0700)
		os.WriteFile(p, []byte("{}\n"), 0600)
		os.Chtimes(p, now, now)
	}
	outside := filepath.Join(t.TempDir(), "canary.jsonl")
	os.WriteFile(outside, []byte("{}\n"), 0600)
	os.Chtimes(outside, now, now)
	os.Symlink(outside, filepath.Join(home, "projects", "p", "symlink.jsonl"))
	logs := ActiveLogs(home, "", now)
	if len(logs) != 2 {
		t.Fatal(logs)
	}
	n := 0
	for _, log := range logs {
		if log.Sidechain {
			n++
		}
	}
	if n != 1 {
		t.Fatal(logs)
	}
}

func TestNewEvidenceStaysWithinLedgerByteBudget(t *testing.T) {
	utc(t)
	now := t0.Add(time.Minute)
	l := PerfLedger{SchemaVersion: 1, Since: t0}
	for i := 0; i < 64; i++ {
		r := LiveRecord{Key: fmt.Sprint(i), Ref: fmt.Sprint(i), Source: "codex", Model: strings.Repeat("m", 96), StartedAt: t0, LastAt: now}
		for j := 0; j < 256; j++ {
			r.Samples = append(r.Samples, liveSample{At: now.Add(-time.Duration(j) * time.Millisecond), Out: 999999999, GenMs: 999999999, Eligible: true})
		}
		l.Live = append(l.Live, r)
	}
	for i := 0; i < 2048; i++ {
		l.Hourly = append(l.Hourly, Hourly{Hour: localHour(now), Source: "codex", Model: fmt.Sprintf("%096d", i), TokenKinds: TokenKinds{InputTokens: count(999999999), CacheReadTokens: count(999999999), CacheWriteTokens: count(999999999)}, ObservedRequests: 999999999, ObservedOutputTokens: 999999999})
	}
	b := l.prune(now)
	if len(b) >= maxFile {
		t.Fatalf("new evidence broke perf.json limit: %d", len(b))
	}
	live, _ := json.Marshal(l.Live)
	hours, _ := json.Marshal(l.Hourly)
	if len(live) > 512<<10 || len(hours) > 512<<10 {
		t.Fatal("new evidence exceeded its byte caps")
	}
}

func TestNewLedgerDoesNotShowCopiedForkHistoryAsTwoLiveSessions(t *testing.T) {
	utc(t)
	cache, home := t.TempDir(), t.TempDir()
	db := sqliteDB(t, OpenCodeDB(home), `CREATE TABLE session_message (id TEXT PRIMARY KEY,session_id TEXT,type TEXT,data TEXT);`)
	raw := fmt.Sprintf(`{"id":"message-private","model":{"id":"m"},"time":{"created":%d,"completed":%d},"tokens":{"output":100}}`, ms(t0), ms(t0.Add(time.Second)))
	exec(t, db, `INSERT INTO session_message VALUES ('row1','parent-private','assistant',?)`, raw)
	exec(t, db, `INSERT INTO session_message VALUES ('row2','child-private','assistant',?)`, raw)
	ObserveOpenCode(cache, home, Ingest{}, t0.Add(10*time.Second))
	v := view(t, cache, t0.Add(10*time.Second))
	if len(v.LiveSessions()) != 1 || len(v.Ledger.Rows) != 0 {
		t.Fatalf("live=%+v rows=%+v", v.LiveSessions(), v.Ledger.Rows)
	}
}

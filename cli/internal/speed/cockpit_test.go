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

func ptr(n int64) *int64 { return &n }
func TestTokenKindsFixtures(t *testing.T) {
	utc(t)
	for _, source := range []string{"claude-code", "codex"} {
		t.Run(source, func(t *testing.T) {
			cache := t.TempDir()
			seedPerf(t, cache, t0.Add(-time.Minute))
			var err error
			if source == "codex" {
				err = ObserveCodex(cache, []string{"testdata/codex-token-kinds.jsonl"}, func(string) bool { return false }, Ingest{}, t0.Add(time.Minute))
			} else {
				path, _ := filepath.Abs("testdata/claude-token-kinds.jsonl")
				err = ObserveClaude(cache, path, false, Ingest{}, t0.Add(2*time.Minute))
			}
			if err != nil {
				t.Fatal(err)
			}
			v := view(t, cache, t0.Add(2*time.Minute))
			rows := v.Daily()
			if len(rows) != 1 {
				t.Fatalf("daily: %+v", rows)
			}
			wantInput, wantRead, wantOut := int64(200), int64(800), int64(100)
			if source == "codex" {
				wantInput, wantRead, wantOut = 500, 1700, 250
			}
			d := rows[0]
			if d.InputTokens == nil || *d.InputTokens != wantInput || d.CacheReadTokens == nil || *d.CacheReadTokens != wantRead || d.ObservedOutputTokens != wantOut {
				t.Fatalf("kinds: %+v", d)
			}
			if source == "codex" && d.CacheWriteTokens != nil {
				t.Fatal("Codex does not report cache writes")
			}
			if source == "claude-code" && (d.CacheWriteTokens == nil || *d.CacheWriteTokens != 30) {
				t.Fatal("cache creation missing")
			}
			l, ok := LoadLong(cache)
			if !ok || len(l.Rows) != 1 || !equalToken(l.Rows[0].InputTokens, d.InputTokens) {
				t.Fatal("long rollup loses kinds")
			}
			if h := v.Hourly(); len(h) != 1 || !equalToken(h[0].CacheReadTokens, d.CacheReadTokens) {
				t.Fatalf("hourly %+v", h)
			}
			b, _ := json.Marshal(struct {
				Stats  []PerfStat
				Live   []LiveSession
				Daily  []Daily
				Hourly []Hourly
				Totals []TodayTotal
			}{v.Stats(), v.LiveSessions(), v.DailyLong(), v.Hourly(), v.TodayTotals()})
			stored, _ := os.ReadFile(PerfPath(cache))
			for _, canary := range []string{"prompt-canary", "reply-canary", "id-canary", "path-canary"} {
				if strings.Contains(string(b), canary) || strings.Contains(string(stored), canary) {
					t.Fatalf("leaked %q", canary)
				}
			}
		})
	}
}
func TestTodayRatioAndUnknownKinds(t *testing.T) {
	utc(t)
	now := t0.Add(time.Hour)
	a := rateRows(day(now), "high", 5, 500, 10000, now)
	a.InputTokens = ptr(10)
	a.CacheReadTokens = ptr(90)
	a.CacheWriteTokens = ptr(0)
	b := rateRows(day(now), "low", 5, 1000, 10000, now)
	b.InputTokens = ptr(20)
	b.CacheReadTokens = ptr(80)
	b.CacheWriteTokens = ptr(0)
	old := rateRows(day(now.AddDate(0, 0, -1)), "high", 5, 9000, 10000, now.AddDate(0, 0, -1))
	v := PerfView{OK: true, Recording: true, Now: now, Ledger: PerfLedger{Since: t0.AddDate(0, 0, -3), Rows: []PerfRow{a, b, old}}}
	all := v.TodayTotals()
	if len(all) != 1 || all[0].Sums.GenMs != 20000 || all[0].Sums.EligibleOutputTokens != 1500 || all[0].GenerationTps.Value == nil || *all[0].GenerationTps.Value != 75 {
		t.Fatalf("today %+v", all)
	}
	for _, s := range v.Stats() {
		if s.Windows.Today.Sums.ObservedRequests != 5 {
			t.Fatalf("window %+v", s.Windows.Today)
		}
	}
	if x := v.Daily()[1]; x.InputTokens == nil || *x.InputTokens != 30 {
		t.Fatalf("sum %+v", x)
	}
	// A pre-upgrade contribution stays unknown; a partial known total is not passed off as full.
	v.Ledger.Rows[0].InputTokens = nil
	if x := v.TodayTotals()[0].Sums; x.InputTokens != nil || x.CacheReadTokens == nil || *x.CacheReadTokens != 170 {
		t.Fatalf("partial %+v", x)
	}
	v.Recording = false
	if x := v.TodayTotals()[0].GenerationTps; x.Status != "off" || x.Value != nil {
		t.Fatalf("off %+v", x)
	}
}
func TestLiveConcurrentAndPending(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	a, b := filepath.Join(dir, "a.jsonl"), filepath.Join(dir, "b.jsonl")
	requests := []req{{100, 1, 0.1}, {100, 1, 0.1}, {100, 1, 0.1}, {100, 1, 0.1}, {100, 1, 0.1}}
	lines := cxTurnLines(0, high, 10, requests...)
	writeLines(t, a, lines[:len(lines)-1]...) // five finished requests, turn still open
	writeLines(t, b, cxTurnLines(1, high, 5, req{300, 1, 0.1})...)
	ObserveCodex(cache, []string{a, b}, func(p string) bool { return p == b }, Ingest{Subscription: "local-ref"}, t0.Add(15*time.Second))
	v := view(t, cache, t0.Add(15*time.Second))
	live := v.LiveSessions()
	if len(live) != 2 {
		t.Fatalf("live %+v", live)
	}
	statuses := map[string]int{}
	var ref string
	for _, s := range live {
		statuses[s.Status]++
		if s.Status == "running" {
			ref = s.Ref
			if s.Rate.Window != "60s" || s.Rate.N != 5 || s.Rate.Value == nil || *s.Rate.Value != 100 {
				t.Fatalf("running %+v", s)
			}
		} else if s.Rate.Status != "insufficient" || s.Rate.Reason != "too-few-samples" {
			t.Fatalf("few %+v", s)
		}
	}
	if statuses["running"] != 1 || statuses["idle"] != 1 || len(v.Daily()) != 0 {
		t.Fatal("provisional and subagent samples entered completed-turn history")
	}
	observeCx(t, cache, t0.Add(16*time.Second), a)
	if x := view(t, cache, t0.Add(16*time.Second)).LiveSessions(); len(x) != 2 || x[1].Rate.N != 5 {
		t.Fatalf("reread dedup %+v", x)
	}
	writeLines(t, a, lines[len(lines)-1])
	observeCx(t, cache, t0.Add(20*time.Second), a)
	v = view(t, cache, t0.Add(20*time.Second))
	if len(v.Ledger.Sessions) != 1 || v.Ledger.Sessions[0].Ref != ref {
		t.Fatal("live ref should survive completion")
	}
	v.Now = t0.Add(80 * time.Second)
	for _, s := range v.LiveSessions() {
		if s.Rate.Value != nil || s.Rate.N != 0 {
			t.Fatalf("expired rate %+v", s)
		}
	}
	v.Now = t0.Add(6 * time.Minute)
	if len(v.LiveSessions()) != 0 {
		t.Fatal("expired sessions")
	}
	v.Recording = false
	v.Now = t0.Add(20 * time.Second)
	if len(v.LiveSessions()) != 0 {
		t.Fatal("live while off")
	}
}
func TestClaudeSeparateSidechain(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "parent.jsonl")
	sub := filepath.Join(dir, "parent", "subagents", "agent-a.jsonl")
	os.MkdirAll(filepath.Dir(sub), 0o700)
	writeLines(t, p, ccPrompt(0), ccReply(4, "parent-id", "m", "high", "", 100, 1000, "tool_use", false))
	writeLines(t, sub, strings.ReplaceAll(ccPrompt(1), `"isSidechain":false`, `"isSidechain":true`), ccReply(5, "child-id", "m", "low", "", 200, 1000, "end_turn", true))
	ObserveClaude(cache, p, false, Ingest{}, t0.Add(6*time.Second))
	live := view(t, cache, t0.Add(6*time.Second)).LiveSessions()
	if len(live) != 2 || live[0].Ref == live[1].Ref {
		t.Fatalf("separate %+v", live)
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
	l := PerfLedger{}
	for _, s := range []string{"2026-11-01T01:20:00-04:00", "2026-11-01T01:20:00-05:00", "2026-11-01T23:59:00-05:00", "2026-11-02T00:01:00-05:00"} {
		at, _ := time.Parse(time.RFC3339, s)
		l.addHourly("codex", request{cfg: config{model: "m"}, out: 1, end: at})
	}
	now, _ := time.Parse(time.RFC3339, "2026-11-02T12:00:00-05:00")
	v := PerfView{OK: true, Now: now, Ledger: l}
	h := v.Hourly()
	if len(h) != 4 || h[0].Hour == h[1].Hour || !strings.HasSuffix(h[0].Hour, "-04:00") || !strings.HasSuffix(h[1].Hour, "-05:00") {
		t.Fatalf("fold %+v", h)
	}
	// 25-hour yesterday + 24-hour today: retain newest 48 per source/model.
	l.Hourly = nil
	start, _ := time.Parse(time.RFC3339, "2026-11-01T00:00:00-04:00")
	for i := 0; i < 49; i++ {
		l.addHourly("codex", request{cfg: config{model: "m"}, out: 1, end: start.Add(time.Duration(i) * time.Hour)})
	}
	l.pruneHourly(start.Add(49*time.Hour - time.Second))
	if len(l.Hourly) != 48 {
		t.Fatalf("cap %d", len(l.Hourly))
	}
	// Spring-forward has no invented 02:00 bucket.
	l.Hourly = nil
	start, _ = time.Parse(time.RFC3339, "2026-03-08T01:30:00-05:00")
	l.addHourly("codex", request{cfg: config{model: "m"}, end: start})
	l.addHourly("codex", request{cfg: config{model: "m"}, end: start.Add(time.Hour)})
	if strings.Contains(fmt.Sprint(l.Hourly), "T02:00") {
		t.Fatal("invented DST hour")
	}
}
func TestNewRecordingOff(t *testing.T) {
	utc(t)
	cache := t.TempDir()
	t.Setenv("MODELPLAN_HISTORY", "off")
	path, _ := filepath.Abs("testdata/claude-token-kinds.jsonl")
	ObserveClaude(cache, path, false, Ingest{}, t0.Add(time.Minute))
	observeCx(t, cache, t0.Add(time.Minute), "testdata/codex-token-kinds.jsonl")
	if _, e := os.Stat(filepath.Join(cache, "observed")); !os.IsNotExist(e) {
		t.Fatal("recording created state while off")
	}
}

// The cumulative baseline belongs to the committed cursor, not to an unfinished read. The
// first cumulative-only line without any baseline is intentionally not guessed from all history.
func TestCodexTotalsAcrossIncrementalReads(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "totals.jsonl")
	total := func(s float64, input, cached, out int64) string {
		return cx(s, "event_msg", fmt.Sprintf(`{"type":"token_count","info":{"total_token_usage":{"input_tokens":%d,"cached_input_tokens":%d,"output_tokens":%d}}}`, input, cached, out))
	}
	writeLines(t, p, cx(0, "event_msg", `{"type":"task_started"}`), cx(0, "turn_context", high), total(1, 100, 50, 10), cx(2, "response_item", `{"type":"function_call_output"}`), total(3, 200, 100, 40), cx(4, "event_msg", `{"type":"task_complete"}`))
	observeCx(t, cache, t0.Add(5*time.Second), p)
	writeLines(t, p, cx(6, "event_msg", `{"type":"task_started"}`), cx(6, "turn_context", high), total(7, 400, 150, 90))
	observeCx(t, cache, t0.Add(8*time.Second), p)
	observeCx(t, cache, t0.Add(9*time.Second), p)
	writeLines(t, p, cx(10, "event_msg", `{"type":"task_complete"}`))
	observeCx(t, cache, t0.Add(11*time.Second), p)
	d := view(t, cache, t0.Add(11*time.Second)).Daily()[0]
	if d.ObservedRequests != 2 || d.ObservedOutputTokens != 80 || d.InputTokens == nil || *d.InputTokens != 200 || d.CacheReadTokens == nil || *d.CacheReadTokens != 100 {
		t.Fatalf("cumulative %+v", d)
	}
}
func TestCodexOptionalCacheWrites(t *testing.T) {
	p := newCodex()
	p.line(0, 1, []byte(cx(0, "event_msg", `{"type":"task_started"}`)))
	p.line(1, 2, []byte(cx(0, "turn_context", high)))
	p.line(2, 3, []byte(cx(1, "token_usage_record", `{"usage":{"input_tokens":100,"cached_input_tokens":80,"cache_write_input_tokens":10,"output_tokens":30}}`)))
	p.line(3, 4, []byte(cx(2, "event_msg", `{"type":"task_complete"}`)))
	ts, _ := p.finish()
	if len(ts) != 1 || ts[0].all[0].cacheWrite == nil || *ts[0].all[0].cacheWrite != 10 {
		t.Fatalf("newer protocol field %+v", ts)
	}
}

func TestLiveAbortDoesNotLeaveRunning(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "abort.jsonl")
	writeLines(t, p, cx(0, "event_msg", `{"type":"task_started"}`), cx(0, "turn_context", high))
	observeCx(t, cache, t0.Add(time.Second), p)
	writeLines(t, p, cx(2, "event_msg", `{"type":"turn_aborted"}`))
	observeCx(t, cache, t0.Add(3*time.Second), p)
	live := view(t, cache, t0.Add(3*time.Second)).LiveSessions()
	if len(live) != 1 || live[0].Status != "idle" {
		t.Fatalf("abort %+v", live)
	}
}

func TestCodexUsageEnrichmentDoesNotDuplicate(t *testing.T) {
	p := newCodex()
	p.line(0, 1, []byte(cx(0, "event_msg", `{"type":"task_started"}`)))
	p.line(1, 2, []byte(cx(0, "turn_context", high)))
	p.line(2, 3, []byte(cx(1, "token_usage_record", `{"usage":{"input_tokens":100,"output_tokens":30}}`)))
	p.line(3, 4, []byte(cx(1, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"cached_input_tokens":80,"output_tokens":30}}}`)))
	p.line(4, 5, []byte(cx(2, "event_msg", `{"type":"task_complete"}`)))
	ts, _ := p.finish()
	if len(ts) != 1 || len(ts[0].all) != 1 || ts[0].all[0].input == nil || *ts[0].all[0].input != 20 {
		t.Fatalf("enrichment %+v", ts)
	}
}
func TestLiveRetentionAndFileBudget(t *testing.T) {
	l := PerfLedger{SchemaVersion: 1, Since: t0}
	for i := 0; i < maxLive+10; i++ {
		r := LiveRecord{Ref: fmt.Sprint(i), LastAt: t0, StartedAt: t0}
		for j := 0; j < maxLiveSamples+10; j++ {
			r.Samples = append(r.Samples, LiveSample{End: t0, Key: fmt.Sprintf("%d-%d", i, j), Model: strings.Repeat("m", 96), Effort: "high", Out: 100, GenMs: 1000, Eligible: true})
		}
		l.Live = append(l.Live, r)
	}
	b := l.prune(t0)
	if len(l.Live) > maxLive || len(b) >= maxFile {
		t.Fatalf("bounds: %d sessions, %d bytes", len(l.Live), len(b))
	}
	for _, r := range l.Live {
		if len(r.Samples) > maxLiveSamples {
			t.Fatal("sample bound")
		}
	}
	l.prune(t0.Add(LiveWithin + time.Second))
	if len(l.Live) != 0 {
		t.Fatal("expired local live state kept")
	}
}

func TestHourlyHalfHourDST(t *testing.T) {
	old := time.Local
	t.Cleanup(func() { time.Local = old })
	loc, e := time.LoadLocation("Australia/Lord_Howe")
	if e != nil {
		t.Fatal(e)
	}
	time.Local = loc
	l := PerfLedger{}
	for _, s := range []string{"2026-04-05T01:45:00+11:00", "2026-04-05T01:45:00+10:30"} {
		at, _ := time.Parse(time.RFC3339, s)
		l.addHourly("codex", request{cfg: config{model: "m"}, end: at})
	}
	if len(l.Hourly) != 2 || l.Hourly[0].Hour != "2026-04-05T01:00:00+11:00" || l.Hourly[1].Hour != "2026-04-05T01:00:00+10:30" {
		t.Fatalf("half-hour fold %+v", l.Hourly)
	}
}

package speed

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// utc runs the test with local time in UTC, so local days are predictable.
func utc(t *testing.T) {
	old := time.Local
	time.Local = time.UTC
	t.Cleanup(func() { time.Local = old })
}

// seedPerf creates the performance ledger as a run at since would have.
func seedPerf(t *testing.T, cache string, since time.Time) {
	t.Helper()
	os.MkdirAll(filepath.Join(cache, "observed"), 0o700)
	b, _ := json.Marshal(PerfLedger{SchemaVersion: 1, Since: since.UTC(), Rows: []PerfRow{}})
	if err := os.WriteFile(PerfPath(cache), b, 0o600); err != nil {
		t.Fatal(err)
	}
}

// req is one Codex request: output tokens, generation seconds and seconds to the first token.
type req struct{ out, gen, ttft float64 }

// cxTurnLines: a Codex turn starting at s under cfg (a turn_context payload), its requests back to back,
// each after the previous one's tool output, finished after dur seconds.
func cxTurnLines(s float64, cfg string, dur float64, reqs ...req) []string {
	ms := func(x float64) int64 { return t0.Add(time.Duration(x * float64(time.Second))).UnixMilli() }
	lines := []string{cx(s, "event_msg", `{"type":"task_started"}`), cx(s, "turn_context", cfg)}
	at := s
	for i, q := range reqs {
		if i > 0 {
			lines = append(lines, cx(at, "response_item", `{"type":"function_call_output","call_id":"c","output":"x"}`))
		}
		first, end := at+q.ttft, at+q.ttft+q.gen
		lines = append(lines,
			cx(end, "event_msg", fmt.Sprintf(`{"type":"item_completed","item":{"type":"AgentMessage","id":"i"},"started_at_ms":%d}`, ms(first))),
			cx(end, "event_msg", fmt.Sprintf(`{"type":"token_count","info":{"last_token_usage":{"output_tokens":%g}}}`, q.out)))
		at = end
	}
	return append(lines, cx(s+dur, "event_msg", fmt.Sprintf(`{"type":"task_complete","duration_ms":%g}`, dur*1000)))
}

const high = `{"model":"fixture-model","effort":"high"}`

func observeCx(t *testing.T, cache string, now time.Time, rollouts ...string) {
	t.Helper()
	if err := ObserveCodex(cache, rollouts, func(string) bool { return false }, now); err != nil {
		t.Fatal(err)
	}
}

func view(t *testing.T, cache string, now time.Time) PerfView {
	t.Helper()
	l, ok := LoadPerf(cache)
	return PerfView{Ledger: l, OK: ok, Recording: true, Now: now}
}

// The worked example of the contract: four requests in one turn, the fourth too short to count.
func TestPerfWorkedExample(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "rollout-a.jsonl")
	writeLines(t, p, cxTurnLines(0, high, 90, req{600, 10, 2}, req{60, 3, 1}, req{1500, 20, 4}, req{12, 0.5, 0.8})...)
	now := t0.Add(5 * time.Minute)
	observeCx(t, cache, now, p)
	st := view(t, cache, now).Stats()
	if len(st) != 1 {
		t.Fatalf("stats = %+v", st)
	}
	s := st[0]
	w := s.Windows.Recent7d
	want := PerfSums{ObservedRequests: 4, ObservedOutputTokens: 2172, EligibleRequests: 3, EligibleOutputTokens: 2160, GenMs: 33000, Turns: 1, TurnMs: 90000, TurnOutputTokens: 2172}
	if w.Sums != want || s.EffortStatus != "reported" || s.Effort != "high" || s.Parser != ParserCodex || s.Eligibility != EligibilityV1 || s.Attribution != "unattributed" || s.Freshness != "fresh" {
		t.Fatalf("stat = %+v", s)
	}
	h, _ := json.Marshal(w.Hist)
	if string(h) != `{"ttftMs":{"scheme":"log1.1/v1","unit":"ms","counts":{"70":1,"72":1,"79":1,"87":1}},"turnMsHist":{"scheme":"log1.1/v1","unit":"ms","counts":{"119":1}},"turnTokensHist":{"scheme":"log1.1/v1","unit":"tokens","counts":{"80":1}}}` {
		t.Errorf("hist = %s", h)
	}
	m := w.Metrics
	if m.GenerationTps != (Metric{Status: "insufficient", N: 3, Min: 5}) || m.TTFTMs != (Metric{Status: "insufficient", N: 4, Min: 5}) || m.WholeTurnTps != (Metric{Status: "insufficient", N: 1, Min: 5}) {
		t.Errorf("metrics = %+v", m)
	}
	if s.LastAt == nil || !s.LastAt.Equal(t0.Add(time.Minute)) {
		t.Errorf("lastAt = %v (the turn ended at 9:01:30)", s.LastAt)
	}
	b, _ := json.Marshal(s)
	if !bytes.Contains(b, []byte(`"basis":{"tokenBasis":"harness-reported-output","timing":{"start":"input-logged","first":"item-started-at","end":"usage-logged","quality":"harness-log-proxy"},"quantile":"log1.1-centre-lower"}`)) {
		t.Errorf("basis in %s", b)
	}

	// Two more requests in the next turn: 3360 tokens in 54 s.
	writeLines(t, p, cxTurnLines(120, high, 30, req{900, 15, 1.5}, req{300, 6, 1.2})...)
	observeCx(t, cache, now, p)
	w = view(t, cache, now).Stats()[0].Windows.Recent7d
	if g := w.Metrics.GenerationTps; g.Status != "ok" || g.N != 5 || *g.Value != 62.2 {
		t.Errorf("generation = %+v", g)
	}
	var union Hist
	for _, v := range []float64{2000, 1000, 4000, 800, 1500, 1200} {
		union = union.add(v)
	}
	if f := w.Metrics.TTFTMs; f.Status != "ok" || f.N != 6 || *f.Value != float64(int64(union.Median()+0.5)) {
		t.Errorf("ttft = %+v, union estimate %v", f, union.Median())
	}
	if l := Load(cache); len(l.Rows) != 1 || l.Rows[0].Requests != 5 || l.Rows[0].Turns != 2 {
		t.Errorf("speed.json goes on as before: %+v", l.Rows)
	}
}

func TestPerfMixedClaudeTurn(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "s.jsonl")
	writeLines(t, p,
		ccPrompt(0),
		ccReply(3, "r1", "claude-opus-5-5", "high", "", 300, 1000, "tool_use", false),
		ccTool(5),
		ccReply(9, "r2", "claude-opus-5-5", "low", "", 200, 1000, "end_turn", false),
	)
	if err := ObserveClaude(cache, p, false, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	l, _ := LoadPerf(cache)
	by := map[string]PerfRow{}
	for _, r := range l.Rows {
		by[r.Effort] = r
	}
	if len(l.Rows) != 2 || by["high"].ObservedRequests != 1 || by["low"].ObservedRequests != 1 || by["high"].Turns+by["low"].Turns != 0 ||
		by["low"].MixedConfigTurnsExcluded != 1 || by["low"].TurnMsHist != nil || by["high"].Parser != ParserClaude {
		t.Fatalf("rows = %+v", l.Rows)
	}
	b, _ := os.ReadFile(PerfPath(cache))
	for _, leak := range []string{"question", "answer", "hmm", "toolsaid", dir, "r1"} {
		if bytes.Contains(b, []byte(leak)) {
			t.Errorf("perf.json holds %q", leak)
		}
	}
}

func TestPerfCutover(t *testing.T) {
	utc(t)
	old := t0
	t0 = time.Date(2026, 10, 17, 23, 58, 0, 0, time.UTC)
	t.Cleanup(func() { t0 = old })
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(time.Minute)) // since 23:59:00
	a, b := filepath.Join(dir, "rollout-a.jsonl"), filepath.Join(dir, "rollout-b.jsonl")
	writeLines(t, a, cxTurnLines(30, high, 70, req{100, 5, 1})...)  // started before since, ended after it
	writeLines(t, a, cxTurnLines(110, high, 30, req{200, 5, 1})...) // after since, across midnight
	observeCx(t, cache, t0.Add(5*time.Minute), a)
	writeLines(t, b, cxTurnLines(10, high, 20, req{300, 5, 1})...) // a log first read later: an old turn
	writeLines(t, b, cxTurnLines(200, high, 20, req{400, 5, 1})...)
	for i := 0; i < 3; i++ {
		observeCx(t, cache, t0.Add(10*time.Minute), a, b)
	}
	l, _ := LoadPerf(cache)
	got := map[string]int64{}
	for _, r := range l.Rows {
		got[r.Day] += r.ObservedOutputTokens
	}
	if len(got) != 2 || got["2026-10-17"] != 200 || got["2026-10-18"] != 400 {
		t.Fatalf("by day = %v", got)
	}
}

func TestPerfWindowsAndRetention(t *testing.T) {
	utc(t)
	now := time.Date(2026, 10, 21, 10, 0, 0, 0, time.UTC)
	dayAgo := func(n int) string { return now.AddDate(0, 0, -n).Format("2006-01-02") }
	row := func(d, model string, tokens int64) PerfRow {
		return PerfRow{Day: d, Source: "codex", Model: model, EffortStatus: "reported", Effort: "high", Parser: ParserCodex, Eligibility: EligibilityV1,
			ObservedRequests: 1, ObservedOutputTokens: tokens}
	}
	l := PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -40), Rows: []PerfRow{row(dayAgo(36), "m", 1), row(dayAgo(34), "m", 2), row(dayAgo(29), "m", 4), row(dayAgo(30), "m", 8), row(dayAgo(0), "m", 16), row(dayAgo(0), "n", 32)}}
	l.prune(now)
	if len(l.Rows) != 5 || l.Rows[0].Day != dayAgo(34) {
		t.Fatalf("36 days ago pruned, 34 kept: %+v", l.Rows)
	}
	v := PerfView{Ledger: l, OK: true, Recording: true, Now: now}
	if s := v.Stats()[0].Windows; s.Recent30d.Sums.ObservedOutputTokens != 20 || s.Recent7d.Sums.ObservedOutputTokens != 16 {
		t.Errorf("recent30d covers 30 days including today (4 + 16), recent7d today: %+v", s)
	}
	d := v.Daily()
	if len(d) != 3 || d[0] != (Daily{Day: dayAgo(29), Source: "codex", Model: "m", ObservedOutputTokens: 4, ObservedRequests: 1}) {
		t.Errorf("daily = %+v", d)
	}
	if c := v.Coverage(); c.From == nil || *c.From != dayAgo(29) || !c.Recording {
		t.Errorf("coverage = %+v", c)
	}
	v.Ledger.Since = now.Add(-2 * 24 * time.Hour)
	if c := v.Coverage(); *c.From != dayAgo(2) || len(v.Daily()) != 2 {
		t.Errorf("days before since are not covered: %+v %+v", c, v.Daily())
	}
}

func TestPerfUnreadableLedgerIsLeftAlone(t *testing.T) {
	cache, dir := t.TempDir(), t.TempDir()
	os.MkdirAll(filepath.Join(cache, "observed"), 0o700)
	bad := []byte(`{"schemaVersion":2,"since":"2026-10-01T00:00:00Z","rows":[]}`)
	os.WriteFile(PerfPath(cache), bad, 0o600)
	p := filepath.Join(dir, "rollout-a.jsonl")
	writeLines(t, p, cxTurnLines(0, high, 30, req{600, 10, 2})...)
	observeCx(t, cache, t0.Add(time.Minute), p)
	if b, _ := os.ReadFile(PerfPath(cache)); !bytes.Equal(b, bad) {
		t.Errorf("rewrote a ledger it cannot read: %s", b)
	}
	v := view(t, cache, t0.Add(time.Minute))
	if r := v.WorkloadRate("codex"); v.OK || r.Status != "unavailable" || r.Reason != "ledger-unreadable" || len(v.Stats()) != 0 {
		t.Errorf("unreadable: %+v %+v", v.OK, r)
	}
	if len(Load(cache).Rows) != 1 {
		t.Error("speed.json goes on")
	}
}

func TestPerfRecordingOff(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "off")
	cache, dir := t.TempDir(), t.TempDir()
	p := filepath.Join(dir, "rollout-a.jsonl")
	writeLines(t, p, cxTurnLines(0, high, 30, req{600, 10, 2})...)
	observeCx(t, cache, t0.Add(time.Minute), p)
	for _, f := range []string{Path(cache), PerfPath(cache)} {
		if _, err := os.Stat(f); !os.IsNotExist(err) {
			t.Errorf("%s written with recording off", f)
		}
	}
	v := PerfView{OK: true, Ledger: PerfLedger{Rows: []PerfRow{{Source: "codex", Day: "2026-10-17", ObservedRequests: 9, EligibleRequests: 9, GenMs: 9000, EligibleOutputTokens: 900}}}, Now: t0}
	if r := v.WorkloadRate("codex"); r.Status != "off" || r.Value != nil {
		t.Errorf("rate with recording off = %+v", r)
	}
}

// rows: n identical eligible requests per row, in rows of the given efforts.
func rateRows(day string, effort string, n int, tokens, ms int64, last time.Time) PerfRow {
	status := "reported"
	if effort == "" {
		status = "unreported"
	}
	return PerfRow{Day: day, Source: "codex", Model: "fixture-model", EffortStatus: status, Effort: effort, Parser: ParserCodex, Eligibility: EligibilityV1,
		ObservedRequests: n, EligibleRequests: n, EligibleOutputTokens: tokens, GenMs: ms, LastAt: &last}
}

func TestEngineRates(t *testing.T) {
	utc(t)
	now := time.Date(2026, 10, 21, 10, 0, 0, 0, time.UTC)
	last := now.Add(-time.Hour)
	v := PerfView{OK: true, Recording: true, Now: now, Ledger: PerfLedger{Since: now.AddDate(0, 0, -3), Rows: []PerfRow{
		rateRows("2026-10-21", "high", 5, 2000, 20000, last), rateRows("2026-10-20", "low", 5, 1200, 40000, last)}}}
	w := v.WorkloadRate("codex")
	if w.Status != "ok" || *w.Value != 53.3 || *w.ConfigCount != 2 || w.N != 10 || w.Scope != "all-configurations" || w.Freshness != "fresh" {
		t.Errorf("workload = %+v (3200 tokens in 60 s, not the mean of 100 and 30)", w)
	}
	if r := v.TokenRate("codex", "fixture-model", "high", ""); r.Status != "ok" || *r.Value != 100 || r.ConfigKey != "codex|fixture-model|reported|high||codex-rollout/1|gen-v1" {
		t.Errorf("own configuration = %+v", r)
	}
	if r := v.TokenRate("codex", "fixture-model", "", ""); r.Status != "unavailable" || r.Reason != "effort-unreported" || r.Value != nil {
		t.Errorf("unreported effort = %+v", r)
	}
	if r := v.TokenRate("codex", "fixture-model", "medium", ""); r.Status != "insufficient" || r.Value != nil || r.N != 0 {
		t.Errorf("no other configuration stands in: %+v", r)
	}
	v.Ledger.Rows = append(v.Ledger.Rows, rateRows("2026-10-21", "", 5, 500, 5000, last))
	if w := v.WorkloadRate("codex"); w.Status != "ok" || *w.ConfigCount != 3 || *w.Value != 56.9 {
		t.Errorf("an unreported effort still counts in the workload: %+v", w)
	}

	// Two sessions of one configuration at the same time: the per-request rate, not their sum.
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	a, b := filepath.Join(dir, "rollout-a.jsonl"), filepath.Join(dir, "rollout-b.jsonl")
	five := []req{{600, 10, 1}, {600, 10, 1}, {600, 10, 1}, {600, 10, 1}, {600, 10, 1}}
	writeLines(t, a, cxTurnLines(0, high, 60, five...)...)
	writeLines(t, b, cxTurnLines(2, high, 60, five...)...)
	observeCx(t, cache, t0.Add(5*time.Minute), a, b)
	if w := view(t, cache, t0.Add(5*time.Minute)).WorkloadRate("codex"); *w.Value != 60 || w.N != 10 {
		t.Errorf("overlapping sessions = %+v", w)
	}

	// The clock alone ages a reading: fresh for a day, stale after a week.
	if bs := v.Boundaries(); len(bs) == 0 {
		t.Fatal("no boundaries")
	}
	v.Now = last.Add(7*24*time.Hour + time.Minute)
	if r := v.TokenRate("codex", "fixture-model", "high", ""); r.Status != "stale" || r.Freshness != "stale" || r.Value != nil {
		t.Errorf("a week later = %+v", r)
	}
}

func TestSessionRanking(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	parent, other := filepath.Join(dir, "rollout-p.jsonl"), filepath.Join(dir, "rollout-o.jsonl")
	sub1, sub2, loose := filepath.Join(dir, "rollout-s1.jsonl"), filepath.Join(dir, "rollout-s2.jsonl"), filepath.Join(dir, "rollout-x.jsonl")
	writeLines(t, parent, append([]string{cx(0, "session_meta", `{"id":"p","source":"cli","title":"Secret project title"}`)}, cxTurnLines(1, high, 30, req{3000, 20, 1})...)...)
	writeLines(t, other, append([]string{cx(0, "session_meta", `{"id":"o","source":"cli"}`)}, cxTurnLines(1, `{"model":"fixture-model"}`, 30, req{1000, 10, 1})...)...)
	// Two subagent threads of the parent, and one with no link: Codex's own threads, never counted.
	for _, p := range []string{sub1, sub2} {
		writeLines(t, p, append([]string{cx(0, "session_meta", `{"id":"s","source":{"subagent":{"thread_spawn":{"parent_thread_id":"p","depth":1}}}}`)}, cxTurnLines(1, high, 30, req{5000, 20, 1})...)...)
	}
	writeLines(t, loose, append([]string{cx(0, "session_meta", `{"id":"x","source":{"subagent":"review"}}`)}, cxTurnLines(1, high, 30, req{7000, 20, 1})...)...)
	sub := map[string]bool{sub1: true, sub2: true, loose: true}
	now := t0.Add(5 * time.Minute)
	if err := ObserveCodex(cache, []string{parent, other, sub1, sub2, loose}, func(p string) bool { return sub[p] }, now); err != nil {
		t.Fatal(err)
	}
	r := view(t, cache, now).Ranking()
	w := r.Recent7d
	if r.Measure != "observed-output-tokens" || w.Sessions != 2 || w.TotalObservedOutputTokens != 4000 || len(w.Top) != 2 {
		t.Fatalf("ranking = %+v", r)
	}
	top := w.Top[0]
	if top.Source != "codex" || top.ObservedOutputTokens != 3000 || top.Share != 0.75 || len(top.Ref) != 16 || top.Configs[0] != (SessionConfig{Model: "fixture-model", EffortStatus: "reported", Effort: "high", ObservedOutputTokens: 3000}) {
		t.Errorf("top = %+v", top)
	}
	if w.Top[1].Configs[0].EffortStatus != "unreported" || w.Top[1].Share != 0.25 {
		t.Errorf("second = %+v", w.Top[1])
	}
	b, _ := os.ReadFile(PerfPath(cache))
	out, _ := json.Marshal(r)
	for _, leak := range []string{"Secret project title", dir, `"p"`, "rollout-p"} {
		if bytes.Contains(b, []byte(leak)) || bytes.Contains(out, []byte(leak)) {
			t.Errorf("%q leaked", leak)
		}
	}
	if bytes.Contains(out, []byte(`"key"`)) {
		t.Error("the file key is not exported")
	}

	// A session last active 36 days ago is pruned with its days.
	l, _ := LoadPerf(cache)
	old := l.Sessions[0]
	old.Ref, old.Key = "old", "k"
	old.Days = []SessionDay{{Day: t0.AddDate(0, 0, -36).Format("2006-01-02"), Model: "fixture-model", EffortStatus: "reported", Effort: "high", ObservedRequests: 1, ObservedOutputTokens: 9}}
	l.Sessions = append(l.Sessions, old)
	l.prune(t0)
	if len(l.Sessions) != 2 {
		t.Errorf("sessions after pruning = %d", len(l.Sessions))
	}
}

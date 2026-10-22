package speed

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"testing"
	"time"
)

func longView(t *testing.T, cache string, now time.Time) PerfView {
	t.Helper()
	v := view(t, cache, now)
	v.Long, v.LongOK = LoadLong(cache)
	return v
}

// The ledger rolls perf.json's days up as they are counted, keeps them after perf.json lets them
// go, never counts a request twice and holds nothing but days, sources, models and two sums.
func TestDailyLongFromLogs(t *testing.T) {
	utc(t)
	cache, logs := t.TempDir(), t.TempDir()
	cwd := filepath.Join(t.TempDir(), "secret-project")
	os.MkdirAll(cwd, 0o700)
	p := filepath.Join(logs, "rollout-2026-10-17T09-00-00-019a7c3e-thread.jsonl")
	writeLines(t, p, append([]string{
		cx(0, "session_meta", fmt.Sprintf(`{"id":"019a7c3e-secret-thread","source":"cli","cwd":%q}`, cwd)),
		cx(0.5, "response_item", `{"type":"message","role":"user","content":[{"type":"input_text","text":"PROMPT-CANARY"}]}`),
	}, cxTurnLines(1, fmt.Sprintf(`{"model":"fixture-model","effort":"high","cwd":%q}`, cwd), 30, req{3000, 20, 1})...)...)
	since := t0.Add(-time.Minute)
	seedPerf(t, cache, since)
	now := t0.Add(5 * time.Minute)
	for i := 0; i < 3; i++ { // read again: nothing is counted twice
		if err := ObserveCodex(cache, []string{p}, func(string) bool { return false }, Ingest{Labels: true, Subscription: "9b1e44d07a2c3f58"}, now); err != nil {
			t.Fatal(err)
		}
	}
	l, ok := LoadLong(cache)
	want := []Daily{{Day: "2026-10-17", Source: "codex", Model: "fixture-model", ObservedOutputTokens: 3000, ObservedRequests: 1}}
	if !ok || !l.Since.Equal(since) || fmt.Sprint(l.Rows) != fmt.Sprint(want) {
		t.Fatalf("daily-long = %+v %v", l, ok)
	}

	// Only these fields, so no prompt, path, project, session, subscription or id can be in it.
	b, _ := os.ReadFile(LongPath(cache))
	var raw map[string]any
	if err := json.Unmarshal(b, &raw); err != nil {
		t.Fatal(err)
	}
	if k := keys(raw); fmt.Sprint(k) != "[rows schemaVersion since]" {
		t.Errorf("top-level fields %v", k)
	}
	for _, r := range raw["rows"].([]any) {
		if k := keys(r.(map[string]any)); fmt.Sprint(k) != "[day model observedOutputTokens observedRequests source]" {
			t.Errorf("row fields %v", k)
		}
	}
	for _, leak := range []string{"PROMPT-CANARY", "secret", "019a7c3e", cwd, logs, fileKey(p), "9b1e44d07a2c3f58"} {
		if bytes.Contains(b, []byte(leak)) {
			t.Errorf("%q in daily-long.json", leak)
		}
	}
	if pb, _ := os.ReadFile(PerfPath(cache)); !bytes.Contains(pb, []byte("secret-project")) {
		t.Error("the fixture does carry a label in perf.json, so its absence above is the ledger's doing")
	}

	// 40 days later perf.json has let 17 October go; daily-long.json keeps it.
	later := t0.Add(40 * 24 * time.Hour)
	writeLines(t, p, cxTurnLines(40*86400, high, 30, req{500, 5, 1})...)
	observeCx(t, cache, later.Add(time.Hour), p)
	v := longView(t, cache, later.Add(time.Hour))
	if d := v.Daily(); len(d) != 1 || d[0].Day != "2026-11-26" {
		t.Fatalf("daily = %+v", d)
	}
	d := v.DailyLong()
	if len(d) != 2 || d[0] != want[0] || d[1] != (Daily{Day: "2026-11-26", Source: "codex", Model: "fixture-model", ObservedOutputTokens: 500, ObservedRequests: 1}) {
		t.Fatalf("dailyLong = %+v", d)
	}
	if c := v.LongCoverage(); c.From == nil || *c.From != "2026-10-17" || !c.Recording {
		t.Errorf("coverage = %+v", c)
	}
}

func keys(m map[string]any) []string {
	var out []string
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func TestDailyLongRetention(t *testing.T) {
	utc(t)
	now := time.Date(2026, 10, 21, 10, 0, 0, 0, time.UTC)
	dayAgo := func(n int) string { return now.AddDate(0, 0, -n).Format("2006-01-02") }
	row := func(d string, tokens int64) Daily {
		return Daily{Day: d, Source: "claude-code", Model: "m", ObservedOutputTokens: tokens, ObservedRequests: 1}
	}
	l := LongLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -400), Rows: []Daily{row(dayAgo(0), 1), row(dayAgo(372), 2), row(dayAgo(371), 4), row(dayAgo(370), 8)}}
	if _, dropped := l.prune(now); !dropped || len(l.Rows) != 2 || l.Rows[0] != row(dayAgo(370), 8) {
		t.Fatalf("371 days, today included, are kept: %+v", l.Rows)
	}
	v := PerfView{OK: true, Recording: true, Now: now, Long: l, LongOK: true}
	if c := v.LongCoverage(); c.From == nil || *c.From != dayAgo(370) {
		t.Errorf("coverage = %+v", c)
	}
	// A view a day later leaves the oldest day out without a write.
	v.Now = now.AddDate(0, 0, 1)
	if d := v.DailyLong(); len(d) != 1 || d[0].Day != dayAgo(0) {
		t.Errorf("dailyLong a day later = %+v", d)
	}
	// With only old days left, local midnight still moves the window.
	if b := v.Boundaries(); len(b) != 1 || !b[0].Equal(time.Date(2026, 10, 23, 0, 0, 0, 0, time.UTC)) {
		t.Errorf("boundaries = %v", b)
	}
}

func TestDailyLongSizeCap(t *testing.T) {
	utc(t)
	cache := t.TempDir()
	now := time.Date(2026, 10, 21, 10, 0, 0, 0, time.UTC)
	var roll []Daily
	for d := 0; d < LongDays; d++ {
		for m := 0; m < 30; m++ {
			roll = append(roll, Daily{Day: now.AddDate(0, 0, -d).Format("2006-01-02"), Source: "claude-code", Model: fmt.Sprintf("model-with-a-long-name-%02d", m),
				ObservedOutputTokens: 123456789, ObservedRequests: 4321})
		}
	}
	os.MkdirAll(filepath.Join(cache, "observed"), 0o700)
	if err := observeLong(cache, now, now.AddDate(-2, 0, 0), nil); err != nil {
		t.Fatal(err)
	}
	l, _ := LoadLong(cache)
	l.Since = now.AddDate(-2, 0, 0) // as if created long ago
	l.merge(roll)
	b, _ := l.prune(now)
	if len(b) > maxLongFile || len(b) < maxLongFile*9/10 {
		t.Fatalf("size %d, cap %d", len(b), maxLongFile)
	}
	if err := write(LongPath(cache), b); err != nil {
		t.Fatal(err)
	}
	l, ok := LoadLong(cache)
	if !ok {
		t.Fatal("a capped file can be read back")
	}
	per := map[string]int{}
	for _, r := range l.Rows {
		per[r.Day]++
	}
	first := l.Rows[0].Day
	if per[first] != 30 || l.TrimmedFrom != first || first <= windowFrom(now, LongDays) {
		t.Fatalf("the oldest days go whole: first %s with %d rows, trimmedFrom %q", first, per[first], l.TrimmedFrom)
	}
	v := PerfView{OK: true, Recording: true, Now: now, Long: l, LongOK: true}
	if c := v.LongCoverage(); *c.From != first {
		t.Errorf("coverage starts after the trim: %+v", c)
	}
	// A day before the trim is not taken back in.
	if l.merge([]Daily{{Day: windowFrom(now, LongDays), Source: "codex", Model: "x", ObservedOutputTokens: 1, ObservedRequests: 1}}) {
		t.Error("merged a day before trimmedFrom")
	}
}

func TestDailyLongCoverage(t *testing.T) {
	utc(t)
	now := time.Date(2026, 10, 21, 10, 0, 0, 0, time.UTC)
	dayAgo := func(n int) string { return now.AddDate(0, 0, -n).Format("2006-01-02") }
	if v := (PerfView{OK: true, Now: now}); v.LongCoverage().From != nil || len(v.DailyLong()) != 0 {
		t.Error("no ledger, no coverage")
	}
	// Without daily-long.json, perf.json's own days: from its since, at most the days it keeps whole.
	perf := PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -2), Rows: []PerfRow{
		{Day: dayAgo(1), Source: "codex", Model: "m", ObservedRequests: 2, ObservedOutputTokens: 20},
		{Day: dayAgo(1), Source: "codex", Model: "m", Effort: "high", EffortStatus: "reported", ObservedRequests: 1, ObservedOutputTokens: 5},
	}}
	v := PerfView{OK: true, Recording: true, Now: now, Ledger: perf}
	if c := v.LongCoverage(); *c.From != dayAgo(2) || fmt.Sprint(v.DailyLong()) != fmt.Sprint(v.Daily()) || v.DailyLong()[0].ObservedOutputTokens != 25 {
		t.Errorf("perf.json only: %+v %+v", c, v.DailyLong())
	}
	v.Ledger.Since = now.AddDate(0, 0, -100)
	if c := v.LongCoverage(); *c.From != dayAgo(35) {
		t.Errorf("perf.json keeps 35 days whole: %+v", c)
	}
	v.OK = false
	if c := v.LongCoverage(); c.From != nil || len(v.DailyLong()) != 0 {
		t.Error("nothing is recorded while perf.json cannot be read")
	}

	// Made from an older perf.json, daily-long.json starts where perf.json still has whole days.
	cache := t.TempDir()
	os.MkdirAll(filepath.Join(cache, "observed"), 0o700)
	roll := []Daily{{Day: dayAgo(50), Source: "codex", Model: "m", ObservedOutputTokens: 1, ObservedRequests: 1}, {Day: dayAgo(30), Source: "codex", Model: "m", ObservedOutputTokens: 2, ObservedRequests: 1}}
	if err := observeLong(cache, now, now.AddDate(0, 0, -100), roll); err != nil {
		t.Fatal(err)
	}
	l, _ := LoadLong(cache)
	if day(l.Since) != dayAgo(35) || len(l.Rows) != 1 || l.Rows[0].Day != dayAgo(30) {
		t.Fatalf("created = %+v", l)
	}
	// From a newer one, at its since.
	cache2 := t.TempDir()
	os.MkdirAll(filepath.Join(cache2, "observed"), 0o700)
	observeLong(cache2, now, now.Add(-time.Hour), nil)
	if l, _ := LoadLong(cache2); !l.Since.Equal(now.Add(-time.Hour)) || l.Rows == nil {
		t.Fatalf("created = %+v", l)
	}

	// An unreadable file is left as it is, and the view falls back to perf.json.
	bad := []byte(`{"schemaVersion":2,"since":"2026-01-01T00:00:00Z","rows":[]}`)
	os.WriteFile(LongPath(cache), bad, 0o600)
	if err := observeLong(cache, now, now, roll); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(LongPath(cache)); !bytes.Equal(b, bad) {
		t.Errorf("rewrote a ledger it cannot read: %s", b)
	}
	l, ok := LoadLong(cache)
	v = PerfView{OK: true, Now: now, Ledger: perf, Long: l, LongOK: ok}
	if ok || *v.LongCoverage().From != dayAgo(2) {
		t.Errorf("unreadable: %v %+v", ok, v.LongCoverage())
	}
}

func TestDailyLongRecordingOff(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "off")
	cache, dir := t.TempDir(), t.TempDir()
	p := filepath.Join(dir, "rollout-a.jsonl")
	writeLines(t, p, cxTurnLines(0, high, 30, req{600, 10, 2})...)
	seedPerf(t, cache, t0.Add(-time.Minute))
	observeCx(t, cache, t0.Add(time.Minute), p)
	if _, err := os.Stat(LongPath(cache)); !os.IsNotExist(err) {
		t.Errorf("daily-long.json written with recording off: %v", err)
	}
	l, _ := LoadPerf(cache)
	v := PerfView{OK: true, Recording: false, Now: t0, Ledger: l}
	if c := v.LongCoverage(); c.Recording || c.From == nil {
		t.Errorf("coverage with recording off = %+v", c)
	}
}

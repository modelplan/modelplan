// SPDX-License-Identifier: MIT
package speed

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// D402 (the Overview heatmap, D390). Invariant: the ledger keeps 30 days of hourly counts, computed as each request
// is counted, and a restart reads them back from perf.json together with the file cursors, so nothing is rescanned
// to refill them. Only aggregate counts are stored.
func TestD402ThirtyDaysOfHourlyCountsSurviveARestartWithoutRescans(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 24, 12, 30, 0, 0, time.UTC)
	l := PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -60), Files: map[string]Cursor{"session.jsonl": {Offset: 4096, Seen: "2026-11-24", Source: "codex"}}}
	cfg := config{model: "m"}
	want := 0
	for at := time.Date(2026, 10, 26, 0, 0, 0, 0, time.UTC); at.Before(now); at = at.Add(time.Hour) { // 30 local days, today included
		l.addHourly("codex", request{cfg: cfg, end: at.Add(time.Minute), out: 3}, at)
		want++
	}
	for at := time.Date(2026, 10, 20, 0, 0, 0, 0, time.UTC); at.Before(time.Date(2026, 10, 26, 0, 0, 0, 0, time.UTC)); at = at.Add(time.Hour) { // older than the window
		l.addHourly("codex", request{cfg: cfg, end: at.Add(time.Minute), out: 3}, at)
	}
	cache := t.TempDir()
	if err := os.MkdirAll(filepath.Dir(PerfPath(cache)), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(PerfPath(cache), l.prune(now), 0o600); err != nil {
		t.Fatal(err)
	}
	// A restart: a new process reads the file and nothing else.
	reloaded, ok := loadPerf(cache)
	if !ok {
		t.Fatal("perf.json unreadable after the restart")
	}
	v := PerfView{OK: true, Ledger: reloaded, Now: now}
	if got := v.HourlyDays(HourlyKeepDays); len(got) != want {
		t.Fatalf("30 days: %d hourly rows after the restart, want %d", len(got), want)
	}
	if got := v.HourlyDays(7); len(got) != 6*24+13 {
		t.Fatalf("7 days: %d rows, want %d", len(got), 6*24+13)
	}
	if got := v.HourlyDays(2); len(got) != 24+13 || len(v.Hourly()) != 24+13 {
		t.Fatalf("2 days: %d rows (%d in the default view)", len(got), len(v.Hourly()))
	}
	if c := reloaded.Files["session.jsonl"]; c.Offset != 4096 || c.Seen != "2026-11-24" {
		t.Fatalf("the file cursor was lost, so the log would be read again: %+v", c)
	}
	// The next day's write prunes by the day: the oldest day leaves, the rest stay.
	next := now.AddDate(0, 0, 1)
	pruned := reloaded
	pruned.prune(next)
	if first := (PerfView{OK: true, Ledger: pruned, Now: next}).HourlyDays(HourlyKeepDays)[0].Hour; first != "2026-10-27T00:00:00Z" {
		t.Fatalf("oldest kept hour %s", first)
	}
	raw, _ := os.ReadFile(PerfPath(cache))
	for _, word := range []string{"prompt", "message"} {
		if strings.Contains(strings.ToLower(string(raw)), word) {
			t.Fatalf("perf.json holds %q: counts only", word)
		}
	}
}

// macrev2-1213-1. Invariant: under ordinary multi-model use every one of the 30 days is retained whole and correct: pruning never
// drops part of a day, and the cursor never outlives rows it vouches for. Dense fixture: four sources, six models, a consent
// epoch change, every hour of 30 days.
func TestD402DenseMultiModelThirtyDaysKeepEveryDayAfterAReload(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 24, 12, 30, 0, 0, time.UTC)
	l := PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -60), Files: map[string]Cursor{"session.jsonl": {Offset: 4096, Seen: "2026-11-24", Source: "codex"}}}
	sources := []string{"codex", "claude-code", "zcode", "opencode"}
	want := map[[2]string]int64{} // hour, source -> output tokens
	for at := time.Date(2026, 10, 26, 0, 0, 0, 0, time.UTC); at.Before(now); at = at.Add(time.Hour) {
		for si, s := range sources {
			for m := 0; m < 6; m++ {
				out := int64(si*100 + m + at.Hour() + 1)
				l.Hourly = append(l.Hourly, Hourly{GrantEpoch: &GrantEpoch{StoreEpoch: "e1", RevokedGeneration: uint64(at.Day() % 2)}, Hour: at.Format(time.RFC3339), Source: s, Model: "model-" + string(rune('a'+m)),
					ObservedOutputTokens: out, ObservedRequests: 2})
				want[[2]string{at.Format(time.RFC3339), s}] += out
			}
		}
	}
	raw := l.prune(now)
	if len(raw) >= maxFile {
		t.Fatalf("perf.json is %d bytes, the loader refuses %d and above", len(raw), maxFile)
	}
	cache := t.TempDir()
	if err := os.MkdirAll(filepath.Dir(PerfPath(cache)), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(PerfPath(cache), raw, 0o600); err != nil {
		t.Fatal(err)
	}
	reloaded, ok := loadPerf(cache)
	if !ok {
		t.Fatal("perf.json refused after the restart")
	}
	got := map[[2]string]int64{}
	days := map[string]bool{}
	for _, h := range (PerfView{OK: true, Ledger: reloaded, Now: now}).HourlyDays(HourlyKeepDays) {
		got[[2]string{h.Hour, h.Source}] += h.ObservedOutputTokens
		days[h.Hour[:10]] = true
	}
	if len(days) != 30 {
		t.Fatalf("%d of 30 days survived", len(days))
	}
	if len(got) != len(want) {
		t.Fatalf("%d hour/source totals, want %d", len(got), len(want))
	}
	for k, v := range want {
		if got[k] != v {
			t.Fatalf("%v: %d, want %d", k, got[k], v)
		}
	}
	// Both consent epochs survive compaction, so a revoked source can still be filtered out hour by hour.
	epochs := map[uint64]bool{}
	for _, r := range reloaded.Hourly {
		if r.GrantEpoch != nil {
			epochs[r.GrantEpoch.RevokedGeneration] = true
		}
	}
	if len(epochs) != 2 {
		t.Fatalf("epochs after compaction: %v", epochs)
	}
	// Yesterday and today keep their per-model rows.
	if n := len((PerfView{OK: true, Ledger: reloaded, Now: now}).Hourly()); n != 37*4*6 {
		t.Fatalf("recent per-model rows: %d", n)
	}
	t.Logf("perf.json %d bytes, %d hourly rows", len(raw), len(reloaded.Hourly))
}

// Over the byte cap the oldest whole days go, never part of a day; yesterday and today always stay whole.
func TestD402OverTheByteCapOnlyWholeOldestDaysGo(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 24, 12, 30, 0, 0, time.UTC)
	var rows []Hourly
	for at := time.Date(2026, 10, 26, 0, 0, 0, 0, time.UTC); at.Before(now); at = at.Add(time.Hour) {
		epochs := 400 // far more consent epochs than real use on the older days, to force the cap
		if at.Format("2006-01-02") >= "2026-11-22" {
			epochs = 4
		}
		for s := 0; s < epochs; s++ {
			rows = append(rows, Hourly{GrantEpoch: &GrantEpoch{StoreEpoch: "e", RevokedGeneration: uint64(s)}, Hour: at.Format(time.RFC3339), Source: "codex", Model: "m", ObservedOutputTokens: 1, ObservedRequests: 1})
		}
	}
	kept := hourlyKept(rows, now)
	perDay := map[string]int{}
	for _, r := range kept {
		perDay[r.Hour[:10]]++
	}
	if perDay["2026-11-23"] != 24*4 || perDay["2026-11-22"] == 0 || perDay["2026-11-24"] != 13*4 {
		t.Fatalf("recent days not whole: %v", perDay)
	}
	for d, n := range perDay {
		if d < "2026-11-22" && n != 24*400 {
			t.Fatalf("%s is a partial day: %d rows", d, n)
		}
	}
	if len(perDay) >= 30 {
		t.Fatal("nothing was pruned")
	}
}

// macrev2-1213-2. Invariant: the writer never produces a perf.json the loader refuses, and a file that is already over the limit
// is shrunk by the next write instead of staying unreadable. Whole oldest hourly days go first; cursors and recent history stay.
func denseHourly(from, now time.Time) []Hourly {
	var rows []Hourly
	for at := from; at.Before(now); at = at.Add(time.Hour) {
		for si, s := range []string{"codex", "claude-code", "zcode", "opencode"} {
			for m := 0; m < 6; m++ {
				rows = append(rows, Hourly{GrantEpoch: &GrantEpoch{StoreEpoch: "e1"}, Hour: at.Format(time.RFC3339), Source: s, Model: "model-" + string(rune('a'+m)),
					ObservedOutputTokens: int64(si*100 + m + 1), ObservedRequests: 2})
			}
		}
	}
	return rows
}

func bigCursors(n int) map[string]Cursor {
	files := map[string]Cursor{}
	for i := 0; i < n; i++ {
		files[fileKey(string(rune('a'+i%26))+strings.Repeat("x", i%7)+time.Duration(i).String())] = Cursor{Offset: int64(i), Seen: "2026-11-24", Source: "codex"}
	}
	return files
}

func TestD402DenseHourlyPlusALargeCursorTableStaysLoadable(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 24, 12, 30, 0, 0, time.UTC)
	cache := t.TempDir()
	seed := PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -60), Files: bigCursors(21000)}
	if err := os.MkdirAll(filepath.Dir(PerfPath(cache)), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(PerfPath(cache), seed.prune(now), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, ok := loadPerf(cache); !ok {
		t.Fatal("the seed ledger must be loadable")
	}
	if err := observePerf(cache, now, Ingest{}, func(l *PerfLedger) bool {
		l.Hourly = append(l.Hourly, denseHourly(time.Date(2026, 10, 26, 0, 0, 0, 0, time.UTC), now)...)
		return true
	}); err != nil {
		t.Fatal(err)
	}
	fi, err := os.Stat(PerfPath(cache))
	if err != nil || fi.Size() >= maxFile-fileMargin+1 {
		t.Fatalf("written file %v bytes (err %v), want under %d", fi.Size(), err, writeLimit)
	}
	l, ok := loadPerf(cache)
	if !ok {
		t.Fatal("the next load rejects the file the writer just made")
	}
	if len(l.Files) != 21000 {
		t.Fatalf("%d of 21000 cursors survived", len(l.Files))
	}
	days := map[string]int{}
	for _, h := range l.Hourly {
		days[h.Hour[:10]]++
	}
	if days["2026-11-24"] == 0 || days["2026-11-23"] == 0 {
		t.Fatalf("yesterday and today must stay: %v", days)
	}
	if len(days) >= 30 {
		t.Fatalf("nothing was trimmed: %d days", len(days))
	}
	// Trimmed by whole oldest days: what is left is one unbroken run ending today, each older day complete.
	first := ""
	for d := range days {
		if first == "" || d < first {
			first = d
		}
	}
	for d := time.Date(2026, 11, 24, 0, 0, 0, 0, time.UTC); d.Format("2006-01-02") >= first; d = d.AddDate(0, 0, -1) {
		if days[d.Format("2006-01-02")] == 0 {
			t.Fatalf("day %s missing inside the kept run starting %s", d.Format("2006-01-02"), first)
		}
	}
	if per := days[first]; first < "2026-11-22" && per != 24*4 {
		t.Fatalf("oldest kept day %s is partial: %d rows", first, per)
	}
}

func TestD402AnOverLimitPerfFileIsShrunkByTheNextWrite(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 24, 12, 30, 0, 0, time.UTC)
	cache := t.TempDir()
	big := PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -60), Files: bigCursors(6000), Hourly: denseHourly(time.Date(2026, 10, 26, 0, 0, 0, 0, time.UTC), now)}
	raw, _ := json.Marshal(big)
	if len(raw) <= maxFile {
		t.Fatalf("fixture is only %d bytes", len(raw))
	}
	if err := os.MkdirAll(filepath.Dir(PerfPath(cache)), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(PerfPath(cache), raw, 0o600); err != nil {
		t.Fatal(err)
	}
	if _, ok := loadPerf(cache); ok {
		t.Fatal("readers must still refuse an over-limit file")
	}
	if err := observePerf(cache, now, Ingest{}, func(*PerfLedger) bool { return false }); err != nil {
		t.Fatal(err)
	}
	l, ok := loadPerf(cache)
	if !ok || len(l.Files) != 6000 || len(l.Hourly) == 0 {
		t.Fatalf("not recovered: ok=%v cursors=%d hourly=%d", ok, len(l.Files), len(l.Hourly))
	}
}

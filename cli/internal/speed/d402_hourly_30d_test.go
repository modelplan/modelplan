// SPDX-License-Identifier: MIT
package speed

import (
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

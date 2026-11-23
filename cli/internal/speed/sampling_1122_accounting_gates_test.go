// SPDX-License-Identifier: MIT
package speed

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// Post-merge sampling 11-22 over #1146: recorded usage survives a clock correction, an empty
// scan cannot hide eligible usage after a time-zone change, and old logs stop reparsing.

func sampling1122Line(at, id string, in int) string {
	return fmt.Sprintf(`{"type":"assistant","timestamp":%q,"sessionId":"synthetic","requestId":"req-%s","message":{"id":"msg_%s","model":"claude-sonnet-4-5-20250929","role":"assistant","content":[],"usage":{"input_tokens":%d,"output_tokens":10}}}`+"\n", at, id, id, in)
}

// A1: a clock correction (the wall clock set back) must not delete a response the ledger
// already recorded live under the current grant; a response dated ahead is still admitted once
// the clock passes it.
func TestSampling1122ClockRollbackKeepsRecordedUsage(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	base := time.Date(2026, 11, 17, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	seedPerf(t, cache, base.Add(-24*time.Hour))
	path := filepath.Join(t.TempDir(), "session.jsonl")
	body := sampling1122Line("2026-11-17T11:59:00Z", "early", 100) + "\n" +
		sampling1122Line("2026-11-17T12:10:00Z", "ahead", 200) + "\n"
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	records := func() map[string]int {
		t.Helper()
		l, ok := loadAccounting(cache)
		if !ok {
			t.Fatal("no accounting ledger")
		}
		seen := map[string]int{}
		for _, file := range l.Files {
			for _, r := range file.Records {
				if !r.Imported {
					seen[r.Key]++
				}
			}
		}
		return seen
	}
	// 12:00: the 11:59 response is recorded; 12:10 is ahead of the clock.
	if err := ObserveClaude(cache, path, false, Ingest{}, base); err != nil {
		t.Fatal(err)
	}
	if seen := records(); len(seen) != 1 {
		t.Fatalf("fixture: want one recorded response, got %+v", seen)
	}
	// The clock is corrected back to 11:58: the recorded response must survive.
	if err := ObserveClaude(cache, path, false, Ingest{}, base.Add(-2*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if seen := records(); len(seen) != 1 {
		t.Fatalf("a clock correction deleted already recorded usage: %+v", seen)
	}
	// The clock catches up: the ahead response appears exactly once, the early one stays.
	if err := ObserveClaude(cache, path, false, Ingest{}, base.Add(15*time.Minute)); err != nil {
		t.Fatal(err)
	}
	seen := records()
	if len(seen) != 2 {
		t.Fatalf("want both responses recorded, got %+v", seen)
	}
	for key, count := range seen {
		if count != 1 {
			t.Fatalf("response %s recorded %d times", key, count)
		}
	}
}

// A2: an empty scan is cached with the recording-day cutoff it was taken under. After a
// time-zone change moves that cutoff, the unchanged file is scanned again and the now eligible
// response counts exactly once.
func TestSampling1122ZoneChangeRescansAnEmptyCachedScan(t *testing.T) {
	grantLocalHistory(t)
	zone := func(name string) {
		t.Helper()
		loc, err := time.LoadLocation(name)
		if err != nil {
			t.Fatal(err)
		}
		old := time.Local
		time.Local = loc
		t.Cleanup(func() { time.Local = old })
	}
	path := filepath.Join(t.TempDir(), "session.jsonl")
	body := sampling1122Line("2026-11-16T18:00:00Z", "early", 100) + "\n"
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	seedPerf(t, cache, time.Date(2026, 11, 17, 6, 0, 0, 0, time.UTC))
	now := time.Date(2026, 11, 17, 7, 0, 0, 0, time.UTC)

	zone("America/New_York")
	if err := ObserveClaude(cache, path, false, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if l, _ := loadAccounting(cache); countRecords(l) != 0 {
		t.Fatalf("fixture: the response must be outside the New York recording day: %+v", l.Files)
	}
	zone("America/Los_Angeles")
	if err := ObserveClaude(cache, path, false, Ingest{}, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	l, _ := loadAccounting(cache)
	if countRecords(l) != 1 {
		t.Fatalf("an empty cached scan hid eligible usage after the zone change: %+v", l.Files)
	}
}

func TestSampling1122ZoneChangeRescansAFileWithExistingUsage(t *testing.T) {
	grantLocalHistory(t)
	oldLocal := time.Local
	t.Cleanup(func() { time.Local = oldLocal })
	newYork, err := time.LoadLocation("America/New_York")
	if err != nil {
		t.Fatal(err)
	}
	losAngeles, err := time.LoadLocation("America/Los_Angeles")
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "session.jsonl")
	body := sampling1122Line("2026-11-16T18:00:00Z", "early", 100) + sampling1122Line("2026-11-17T06:30:00Z", "later", 200)
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	seedPerf(t, cache, time.Date(2026, 11, 17, 6, 0, 0, 0, time.UTC))
	now := time.Date(2026, 11, 17, 7, 0, 0, 0, time.UTC)
	time.Local = newYork
	if err := ObserveClaude(cache, path, false, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if l, _ := loadAccounting(cache); countRecords(l) != 1 {
		t.Fatal("fixture must initially record only one response")
	}
	time.Local = losAngeles
	if err := ObserveClaude(cache, path, false, Ingest{}, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if l, _ := loadAccounting(cache); countRecords(l) != 2 {
		t.Fatal("time-zone change hid the newly eligible response")
	}
}

// A3: an old log (mtime and responses past the retention window) selected by the observer is
// parsed once; the scheduled passes after it neither reparse it nor rewrite the ledger.
func TestSampling1122OldLogIsNotReparsedEveryPass(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	seedPerf(t, cache, now.Add(-12*time.Hour))
	old := now.Add(-40 * 24 * time.Hour)
	body := sampling1122Line(old.Format(time.RFC3339Nano), "archived", 100) + "\n"
	path := filepath.Join(t.TempDir(), "archived.jsonl")
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(path, old, old); err != nil {
		t.Fatal(err)
	}
	ledger := filepath.Join(cache, "observed", "accounting.json.gz")
	if err := ObserveClaude(cache, path, false, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	first, err := os.Stat(ledger)
	if err != nil {
		t.Fatal(err)
	}
	for i := 1; i <= 3; i++ {
		if err := ObserveClaude(cache, path, false, Ingest{}, now.Add(time.Duration(i)*30*time.Second)); err != nil {
			t.Fatal(err)
		}
		again, err := os.Stat(ledger)
		if err != nil {
			t.Fatal(err)
		}
		if !os.SameFile(first, again) || !again.ModTime().Equal(first.ModTime()) {
			t.Fatalf("observation %d rewrote the usage ledger for an unchanged old log", i)
		}
	}
	if l, _ := loadAccounting(cache); countRecords(l) != 0 {
		t.Fatalf("history outside the retention window became live usage: %+v", l.Files)
	}
	// A change to the old log is still read.
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatal(err)
	}
	fmt.Fprintf(f, "%s", sampling1122Line(now.Add(-2*time.Minute).Format(time.RFC3339Nano), "fresh", 300))
	f.Close()
	if err := os.Chtimes(path, now, now); err != nil {
		t.Fatal(err)
	}
	if err := ObserveClaude(cache, path, false, Ingest{}, now.Add(2*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if l, _ := loadAccounting(cache); countRecords(l) != 1 {
		t.Fatalf("a changed old log was not read: %+v", l.Files)
	}
}

// A remembered old scan must be reconsidered if the wall clock moves far enough back to
// bring a response into the retention window, even though the file itself is unchanged.
func TestSampling1122OldScanReconsideredAfterClockRollback(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	old := now.Add(-40 * 24 * time.Hour)
	cache := t.TempDir()
	seedPerf(t, cache, old.Add(-24*time.Hour))
	path := filepath.Join(t.TempDir(), "archived.jsonl")
	if err := os.WriteFile(path, []byte(sampling1122Line(old.Format(time.RFC3339Nano), "archived", 100)), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(path, old, old); err != nil {
		t.Fatal(err)
	}
	if err := ObserveClaude(cache, path, false, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if l, _ := loadAccounting(cache); countRecords(l) != 0 {
		t.Fatal("fixture must start outside retention")
	}
	if err := ObserveClaude(cache, path, false, Ingest{}, now.Add(-10*24*time.Hour)); err != nil {
		t.Fatal(err)
	}
	if l, _ := loadAccounting(cache); countRecords(l) != 1 {
		t.Fatal("clock rollback made the response eligible but the old scan hid it")
	}
}

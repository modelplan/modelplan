// SPDX-License-Identifier: MIT
package speed

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// G3-147: an unchanged session log whose responses all predate the recording start is read once.
// Its entry was dropped for having no records, so every 30-second observation parsed the whole
// file again and rewrote the usage ledger, which woke the app-server into a new snapshot.
func TestG3147UnchangedLogWithoutRecordsIsNotReadAgain(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	seedPerf(t, cache, now.Add(-12*time.Hour))
	var sb strings.Builder
	start := now.Add(-72 * time.Hour) // before the recording start: imported history, not live
	for i := 0; i < 50; i++ {
		fmt.Fprintf(&sb, `{"type":"assistant","timestamp":%q,"sessionId":"synthetic","requestId":"req-%d","message":{"id":"msg_%d","model":"claude-sonnet-4-5-20250929","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_read_input_tokens":900,"cache_creation_input_tokens":20,"output_tokens":10}}}`+"\n", start.Add(time.Duration(i)*time.Second).Format(time.RFC3339Nano), i, i)
	}
	path := filepath.Join(t.TempDir(), "synthetic.jsonl")
	if err := os.WriteFile(path, []byte(sb.String()), 0o600); err != nil {
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
			t.Fatalf("observation %d rewrote the usage ledger for an unchanged log", i)
		}
	}
	if totals := view(t, cache, now).TodayTotals(); len(totals) != 0 {
		t.Fatalf("history before the recording start became live usage: %+v", totals)
	}
	// A change to the log is still read.
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatal(err)
	}
	fmt.Fprintf(f, `{"type":"assistant","timestamp":%q,"sessionId":"synthetic","requestId":"req-new","message":{"id":"msg_new","model":"claude-sonnet-4-5-20250929","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_read_input_tokens":900,"cache_creation_input_tokens":20,"output_tokens":10}}}`+"\n", now.Add(2*time.Minute).Format(time.RFC3339Nano))
	f.Close()
	if err := ObserveClaude(cache, path, false, Ingest{}, now.Add(3*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if totals := view(t, cache, now.Add(3*time.Minute)).TodayTotals(); len(totals) != 1 || totals[0].Sums.ObservedRequests != 1 {
		t.Fatalf("the new response was not recorded: %+v", totals)
	}
}

// G3-147 review: a response dated ahead of the engine clock is recorded once the clock passes
// it, even though the file does not change; meanwhile the ledger is not rewritten.
func TestG3147ResponseAheadOfTheClockIsRecordedLater(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	seedPerf(t, cache, now.Add(-12*time.Hour))
	path := filepath.Join(t.TempDir(), "ahead.jsonl")
	line := fmt.Sprintf(`{"type":"assistant","timestamp":%q,"sessionId":"synthetic","requestId":"req-ahead","message":{"id":"msg_ahead","model":"claude-sonnet-4-5-20250929","role":"assistant","content":[],"usage":{"input_tokens":100,"cache_read_input_tokens":900,"output_tokens":10}}}`+"\n", now.Add(time.Minute).Format(time.RFC3339Nano))
	if err := os.WriteFile(path, []byte(line), 0o600); err != nil {
		t.Fatal(err)
	}
	ledger := filepath.Join(cache, "observed", "accounting.json.gz")
	if err := ObserveClaude(cache, path, false, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if totals := view(t, cache, now).TodayTotals(); len(totals) != 0 {
		t.Fatalf("a response ahead of the clock was recorded early: %+v", totals)
	}
	first, err := os.Stat(ledger)
	if err != nil {
		t.Fatal(err)
	}
	if err := ObserveClaude(cache, path, false, Ingest{}, now.Add(30*time.Second)); err != nil {
		t.Fatal(err)
	}
	if again, err := os.Stat(ledger); err != nil || !os.SameFile(first, again) {
		t.Fatalf("the ledger was rewritten while the response was still ahead (%v)", err)
	}
	later := now.Add(2 * time.Minute)
	if err := ObserveClaude(cache, path, false, Ingest{}, later); err != nil {
		t.Fatal(err)
	}
	if totals := view(t, cache, later).TodayTotals(); len(totals) != 1 || totals[0].Sums.ObservedRequests != 1 {
		t.Fatalf("the response was not recorded after the clock passed it: %+v", totals)
	}
}

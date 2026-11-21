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

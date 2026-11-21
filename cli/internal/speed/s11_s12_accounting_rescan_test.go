// SPDX-License-Identifier: MIT
package speed

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Sampling 11-21 S11 (#1125, MP1125-1). An older response was imported from a transcript that also
// has a live response in the untiered (pre-upgrade) cache. The upgrade rescan of the unchanged
// transcript admitted the imported response as live (its key counted as already recorded), so
// "Remove imported history" deleted only its imported copy and the response stayed in the totals.
// Invariant: after removal, a response that was only imported is absent and the live response
// still counts exactly once.
func TestS11RemovingImportedHistoryAfterTheUpgradeRescanLeavesOnlyLiveUsage(t *testing.T) {
	f := newFixture(t)
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "config"))
	t.Setenv("MODELPLAN_READERS", "")
	raw, _ := json.Marshal(both().State())
	if err := os.MkdirAll(filepath.Dir(consent.Path()), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(consent.Path(), raw, 0o600); err != nil {
		t.Fatal(err)
	}
	// One response three days before live recording started, one on the live recording day.
	path, out := accountingImportLog(t, f, "claude-code", -3, 0.1)
	seedPerf(t, f.cache, t0)
	observe := func() {
		t.Helper()
		if err := ObserveClaude(f.cache, path, false, Ingest{}, f.now); err != nil {
			t.Fatal(err)
		}
	}
	observe()
	if got := accountingImportedOutput(t, f, "claude-code"); got != out {
		t.Fatalf("live recording counts %d, want only the live response %d", got, out)
	}
	stripTiers(t, f.cache) // the previous build's untiered cache
	f.run(7, both())
	if got := accountingImportedOutput(t, f, "claude-code"); got != 2*out {
		t.Fatalf("after import: %d want %d", got, 2*out)
	}
	observe() // the upgrade rescan of the unchanged transcript
	if got := accountingImportedOutput(t, f, "claude-code"); got != 2*out {
		t.Fatalf("after the upgrade rescan: %d want %d", got, 2*out)
	}
	if err := RemoveImported(f.cache); err != nil {
		t.Fatal(err)
	}
	if got := accountingImportedOutput(t, f, "claude-code"); got != out {
		t.Fatalf("after Remove imported history: %d output tokens, want only the live response %d", got, out)
	}
}

// Sampling 11-21 S12 (#1125, S16 follow-up). After the Los Angeles to New York upgrade rescan kept
// the early response, the next normal append to the same session dropped it: the file was tiered,
// so the recorded key no longer exempted it from the recomputed recording-day start. Invariant: a
// response this file already recorded live stays recorded when the file is parsed again under the
// same grant; an append adds to it.
func TestS12AnAppendAfterTheTimeZoneRescanKeepsEveryRecordedResponse(t *testing.T) {
	grantLocalHistory(t)
	zone := func(name string) {
		loc, err := time.LoadLocation(name)
		if err != nil {
			t.Fatal(err)
		}
		old := time.Local
		time.Local = loc
		t.Cleanup(func() { time.Local = old })
	}
	line := func(at, id string, in int) string {
		return fmt.Sprintf(`{"type":"assistant","timestamp":%q,"sessionId":"tz-session","requestId":"req-%s","message":{"id":"msg_%s","model":"claude-sonnet-4-5-20250929","role":"assistant","content":[],"usage":{"input_tokens":%d,"output_tokens":10}}}`, at, id, id, in)
	}
	path := filepath.Join(t.TempDir(), "session.jsonl")
	body := line("2026-11-16T18:00:00Z", "early", 100) + "\n" + line("2026-11-17T06:30:00Z", "late", 200) + "\n"
	if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	seedPerf(t, cache, time.Date(2026, 11, 17, 6, 0, 0, 0, time.UTC))
	now := time.Date(2026, 11, 17, 7, 0, 0, 0, time.UTC)

	zone("America/Los_Angeles")
	if err := ObserveClaude(cache, path, false, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	stripTiers(t, cache)
	zone("America/New_York")
	if err := ObserveClaude(cache, path, false, Ingest{}, now.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if l, _ := loadAccounting(cache); countRecords(l) != 2 {
		t.Fatalf("the upgrade rescan dropped a recorded response: %+v", l.Files)
	}
	// The same Claude session continues; the next scan parses the appended file.
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.WriteString(line("2026-11-17T07:05:00Z", "next", 300) + "\n"); err != nil {
		t.Fatal(err)
	}
	f.Close()
	later := now.Add(10 * time.Minute)
	if err := ObserveClaude(cache, path, false, Ingest{}, later); err != nil {
		t.Fatal(err)
	}
	l, _ := loadAccounting(cache)
	seen := map[string]int{}
	for _, file := range l.Files {
		for _, r := range file.Records {
			seen[r.Key]++
		}
	}
	if countRecords(l) != 3 || len(seen) != 3 {
		t.Fatalf("after the append: %d records (%d distinct), want the three responses once each: %+v", countRecords(l), len(seen), l.Files)
	}
}

// SPDX-License-Identifier: MIT
package speed

// Post-merge sampling 2026-11-19, S2-S6: one regression test per finding.

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// S2/S6: usage the timing ledger recorded before accounting began stays in the recent windows.
// Accounting replaces timing usage only from the first day it fully covers.
func TestAccountingKeepsLegacyUsageOutsideCoverage(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	epoch := currentEpoch(consent.Capture(), "codex")
	if epoch == nil {
		t.Fatal("codex history not granted")
	}
	// An earlier session, observed only by the older engine three days ago, never re-read.
	legacy := PerfRow{GrantEpoch: epoch, Day: day(now.AddDate(0, 0, -3)), Source: "codex", Model: "fixture-model", EffortStatus: "unreported",
		Parser: ParserCodex, Eligibility: EligibilityV1, ObservedRequests: 4, ObservedOutputTokens: 400}
	if err := os.MkdirAll(filepath.Join(cache, "observed"), 0o700); err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -5).UTC(), Rows: []PerfRow{legacy}})
	if err := os.WriteFile(PerfPath(cache), b, 0o600); err != nil {
		t.Fatal(err)
	}
	observeCx(t, cache, now, filepath.Join("testdata", "accounting", "sessions", "2026", "11", "16", "rollout-redacted.jsonl"))
	v := view(t, cache, now)
	var recent PerfSums
	for _, w := range v.HistoryWindows() {
		if w.Source == "codex" {
			recent = w.Recent7d
		}
	}
	if recent.ObservedOutputTokens != 430 || recent.ObservedRequests != 6 {
		t.Fatalf("upgrade erased never-scanned usage: want 400 legacy + 30 accounted output over 6 requests, got %+v", recent)
	}
	if today := v.TodayTotals(); len(today) != 1 || today[0].Sums.ObservedOutputTokens != 30 {
		t.Fatalf("covered day must count accounting once: %+v", today)
	}
}

// S3: a user fork replays parent usage A, compaction B, then C. The replayed prefix runs across
// the compaction record (deduplicated by its response identity), so C is not counted again.
func TestAccountingForkPrefixSpansCompaction(t *testing.T) {
	utc(t)
	cache := t.TempDir()
	at := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	rec := func(key string, minute int, input int64, response bool) usageRecord {
		return usageRecord{Key: key, At: at.Add(time.Duration(minute) * time.Minute), Model: "m", usageBuckets: usageBuckets{Input: input, Output: 1}, Response: response}
	}
	parent := usageFile{Source: "codex", Session: "parent-session", Records: []usageRecord{rec("a", 0, 10, false), rec("response:b", 1, 20, true), rec("c", 2, 30, false)}}
	fork := usageFile{Source: "codex", Session: "child-session", Parent: "parent-session", Started: at.Add(time.Hour),
		Records: []usageRecord{rec("child-a", 0, 10, false), rec("response:b", 1, 20, true), rec("child-c", 2, 30, false), rec("child-d", 70, 40, false)}}
	l := accountingLedger{Version: 1, Files: map[string]usageFile{"parent": parent, "fork": fork}}
	if err := os.MkdirAll(filepath.Dir(accountingPath(cache)), 0700); err != nil {
		t.Fatal(err)
	}
	if err := saveAccounting(cache, l); err != nil {
		t.Fatal(err)
	}
	rows, _ := accountingRows(cache)
	requests, total := 0, int64(0)
	for _, r := range rows {
		requests += r.ObservedRequests
		total += *r.TotalTokens
	}
	if requests != 4 || total != 104 {
		t.Fatalf("fork replay after a compaction counted again: want A, B, C, D = 4 requests, 104 tokens; got %d, %d", requests, total)
	}
}

// S4: an imported Codex background thread spends tokens exactly as a live-observed one does.
// Its turns stay out of the timing samples.
func TestAccountingImportCountsBackgroundThreads(t *testing.T) {
	f := newFixture(t)
	f.codexLog("rollout-background.jsonl", -1)
	seedPerf(t, f.cache, t0)
	if _, err := Import(context.Background(), f.cache, ImportOptions{Days: 7, Codex: &ImportRoot{Dir: f.home, Background: func(string) bool { return true }}, Now: f.now, Admission: both()}); err != nil {
		t.Fatal(err)
	}
	if got := accountingImportedOutput(t, f, "codex"); got != 300 {
		t.Fatalf("imported background thread counted %d output tokens, live observation counts 300", got)
	}
	imp, _ := LoadImported(f.cache)
	if reqs, _ := total(imp, "codex"); reqs != 0 {
		t.Fatalf("background turns became timing samples: %d", reqs)
	}
}

// S5: Codex input_tokens includes cache reads and cache writes. A session day counts each once:
// input 100, cached 60, cache write 10, output 5 is 105, not 115 — also when only the
// token_count notice after a usage record reports the cache write.
func TestCodexSessionTotalCountsCacheWritesOnce(t *testing.T) {
	utc(t)
	full := `{"input_tokens":100,"cached_input_tokens":60,"cache_write_input_tokens":10,"output_tokens":5}`
	cases := map[string][]string{}
	cases["token_count"] = []string{cx(3, "event_msg", `{"type":"token_count","info":{"last_token_usage":`+full+`}}`)}
	cases["record then notice"] = []string{
		cx(3, "token_usage_record", `{"response_id":"r","usage":{"input_tokens":100,"cached_input_tokens":60,"output_tokens":5}}`),
		cx(3, "event_msg", `{"type":"token_count","info":{"last_token_usage":`+full+`}}`),
	}
	for name, usage := range cases {
		t.Run(name, func(t *testing.T) {
			cache, dir := t.TempDir(), t.TempDir()
			seedPerf(t, cache, t0.Add(-time.Minute))
			p := filepath.Join(dir, "rollout-w.jsonl")
			lines := []string{cx(0, "session_meta", `{"id":"w","source":"cli"}`), cx(0, "event_msg", `{"type":"task_started"}`), cx(0, "turn_context", high),
				cx(1, "event_msg", `{"type":"item_completed","item":{"type":"AgentMessage","id":"i"},"started_at_ms":`+fmt.Sprint(t0.Add(time.Second).UnixMilli())+`}`)}
			lines = append(lines, usage...)
			lines = append(lines, cx(4, "event_msg", `{"type":"task_complete","duration_ms":4000}`))
			writeLines(t, p, lines...)
			if err := ObserveCodex(cache, []string{p}, func(string) bool { return false }, Ingest{}, t0.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			l, ok := LoadPerf(cache)
			if !ok || len(l.Sessions) != 1 || len(l.Sessions[0].Days) == 0 {
				t.Fatalf("ledger: %+v", l)
			}
			d := l.Sessions[0].Days[0]
			if d.Kinds == nil || d.Kinds.InputTokens == nil || *d.Kinds.InputTokens != 30 || d.Kinds.CacheWriteTokens == nil || *d.Kinds.CacheWriteTokens != 10 {
				t.Fatalf("uncached input must exclude cache writes: %+v", d.Kinds)
			}
			if got, ok := d.CompleteTotal(); !ok || got != 105 {
				t.Fatalf("CompleteTotal = %d, %v; want 105", got, ok)
			}
		})
	}
}

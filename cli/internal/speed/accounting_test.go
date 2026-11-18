// SPDX-License-Identifier: MIT
package speed

import (
	"encoding/json"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestAccountingUnfinishedResponsesNotSpeedSamples(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	seedPerf(t, cache, now.Add(-12*time.Hour))
	path := filepath.Join("testdata", "accounting", "sessions", "2026", "11", "16", "rollout-redacted.jsonl")
	observeCx(t, cache, now, path)
	totals := view(t, cache, now).TodayTotals()
	if len(totals) != 1 {
		t.Fatalf("usage missing for unfinished turn: %+v", totals)
	}
	s := totals[0].Sums
	if s.ObservedRequests != 2 || s.ObservedOutputTokens != 30 || s.InputTokens == nil || *s.InputTokens != 300 || s.CacheReadTokens == nil || *s.CacheReadTokens != 2700 {
		t.Fatalf("want ccusage: 2 responses, 300 input + 2700 cache + 30 output = 3030; got %+v", s)
	}
	if s.EligibleRequests != 0 || s.GenMs != 0 {
		t.Fatal("accounting invented speed samples")
	}
	observeCx(t, cache, now.Add(time.Second), path)
	if got := view(t, cache, now).TodayTotals()[0].Sums.ObservedOutputTokens; got != 30 {
		t.Fatalf("re-read double-counted: %d", got)
	}
}

// Opt-in read-only comparison harness. Prints only aggregates, never log text or identities.
func TestAccountingReferenceLocalLogs(t *testing.T) {
	root := os.Getenv("MODELPLAN_ACCOUNTING_VALIDATE_ROOT")
	if root == "" {
		t.Skip("set MODELPLAN_ACCOUNTING_VALIDATE_ROOT for a read-only real-log comparison")
	}
	source := os.Getenv("MODELPLAN_ACCOUNTING_VALIDATE_SOURCE")
	if source == "" {
		source = "codex"
	}
	date := os.Getenv("MODELPLAN_ACCOUNTING_VALIDATE_DAY")
	zone := os.Getenv("MODELPLAN_ACCOUNTING_VALIDATE_ZONE")
	if zone == "" {
		zone = "America/Los_Angeles"
	}
	loc, err := time.LoadLocation(zone)
	if err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	l := accountingLedger{Version: 1, Files: map[string]usageFile{}}
	err = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() || !strings.HasSuffix(path, ".jsonl") {
			return nil
		}
		p := newAccountingParser(source, fileKey(path))
		if _, err := readWhole(func() error { return nil }, path, p); err != nil {
			return err
		}
		records := []usageRecord{}
		for _, r := range p.records {
			if r.At.In(loc).Format("2006-01-02") == date {
				records = append(records, r)
			}
		}
		if len(records) > 0 {
			l.Files[fileKey(path)] = usageFile{Source: source, Records: records, Session: usageHash(p.session), Parent: p.parent, Started: p.started}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	os.MkdirAll(filepath.Dir(accountingPath(cache)), 0700)
	if err := saveAccounting(cache, l); err != nil {
		t.Fatal(err)
	}
	rows, _ := accountingRows(cache)
	var sums PerfSums
	for _, r := range rows {
		sums.add(&r)
	}
	b, _ := json.Marshal(sums)
	fmt.Printf("ACCOUNTING_VALIDATION %s\n", b)
}

func TestAccountingClaudeStreamingAndCopiedResponses(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	path, err := filepath.Abs(filepath.Join("testdata", "accounting", "claude", "projects", "redacted", "session.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	if err := ObserveClaude(cache, path, false, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	copy := filepath.Join(t.TempDir(), "copy.jsonl")
	if err := os.WriteFile(copy, b, 0600); err != nil {
		t.Fatal(err)
	}
	if err := ObserveClaude(cache, copy, false, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	totals := view(t, cache, now).TodayTotals()
	if len(totals) != 1 {
		t.Fatalf("missing Claude responses: %+v", totals)
	}
	s := totals[0].Sums
	if s.TotalTokens == nil || *s.TotalTokens != 3090 || s.ObservedOutputTokens != 30 || s.ObservedRequests != 2 || *s.InputTokens != 300 || *s.CacheReadTokens != 2700 || *s.CacheWriteTokens != 60 {
		t.Fatalf("want pinned ccusage totals (3090), got %+v", s)
	}
}

func TestAccountingCodexCumulativeAndResponseNotice(t *testing.T) {
	utc(t)
	p := newAccountingParser("codex", "file")
	lines := []string{
		cx(0, "session_meta", `{"id":"redacted"}`), cx(0, "turn_context", high),
		cx(1, "event_msg", `{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":60,"cache_write_input_tokens":10,"output_tokens":5,"reasoning_output_tokens":2}}}`),
		cx(2, "token_usage_record", `{"response_id":"redacted-response","usage":{"input_tokens":200,"cached_input_tokens":150,"cache_write_input_tokens":20,"output_tokens":10,"reasoning_output_tokens":3}}`),
		cx(3, "response_item", `{"type":"function_call_output","output":"CONTENT-CANARY"}`),
		cx(4, "event_msg", `{"type":"token_count","info":{"total_token_usage":{"input_tokens":300,"cached_input_tokens":210,"cache_write_input_tokens":30,"output_tokens":15,"reasoning_output_tokens":5}}}`),
		cx(5, "event_msg", `{"type":"token_count","info":{"total_token_usage":{"input_tokens":300,"cached_input_tokens":210,"cache_write_input_tokens":30,"output_tokens":15,"reasoning_output_tokens":5}}}`),
	}
	for _, line := range lines {
		p.line(0, 0, []byte(line))
	}
	p.finish()
	if len(p.records) != 2 {
		t.Fatalf("response/notice or unchanged cumulative counted twice: %+v", p.records)
	}
	var total usageBuckets
	for _, r := range p.records {
		total.Input += r.Input
		total.CacheRead += r.CacheRead
		total.CacheWrite += r.CacheWrite
		total.Output += r.Output
		total.Reasoning += r.Reasoning
	}
	if total != (usageBuckets{Input: 60, CacheRead: 210, CacheWrite: 30, Output: 10, Reasoning: 5}) || total.Sum() != 315 {
		t.Fatalf("normalized total: %+v", total)
	}
}

func TestAccountingLocalWindowsAndSpeedStaySeparate(t *testing.T) {
	old := time.Local
	loc, err := time.LoadLocation("America/Los_Angeles")
	if err != nil {
		t.Fatal(err)
	}
	time.Local = loc
	t.Cleanup(func() { time.Local = old })
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, loc)
	b := usageBuckets{Input: 1, CacheRead: 9, Output: 1, Reasoning: 1}
	v := PerfView{OK: true, Recording: true, Now: now, Ledger: PerfLedger{Rows: []PerfRow{{Source: "codex", Day: day(now), ObservedRequests: 5, ObservedOutputTokens: 25, EligibleRequests: 5, EligibleOutputTokens: 100, GenMs: 2000}}}}
	for _, at := range []time.Time{now, now.AddDate(0, 0, -6), now.AddDate(0, 0, -29), now.AddDate(0, 0, -30)} {
		v.Ledger.UsageRows = append(v.Ledger.UsageRows, PerfRow{Source: "codex", Day: day(at), TokenKinds: usageKinds(b), ObservedRequests: 1, ObservedOutputTokens: b.Output + b.Reasoning})
	}
	today := v.TodayTotals()[0].Sums
	if *today.TotalTokens != 12 || today.ObservedOutputTokens != 2 || today.EligibleOutputTokens != 100 || today.GenMs != 2000 {
		t.Fatalf("usage changed speed: %+v", today)
	}
	shared := v.AccountingWindows()["codex"]
	if shared.Today.Total != 12 || shared.Last7d.Total != 24 || shared.Last30d.Total != 36 {
		t.Fatalf("shared windows: %+v", shared)
	}
	windows := v.HistoryWindows()[0]
	if *windows.Recent7d.TotalTokens != 24 || *windows.Recent30d.TotalTokens != 36 {
		t.Fatalf("local windows: %+v", windows)
	}
	// UTC midnight still belongs to yesterday in the chosen local zone.
	if day(time.Date(2026, 11, 17, 0, 30, 0, 0, time.UTC)) != "2026-11-16" {
		t.Fatal("used UTC grouping")
	}
}

func TestAccountingCodexCopiesAndSameTimestampOccurrences(t *testing.T) {
	utc(t)
	cache := t.TempDir()
	p := newAccountingParser("codex", "first")
	line := cx(1, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"output_tokens":2}}}`)
	p.line(0, 0, []byte(cx(0, "session_meta", `{"id":"redacted","source":"cli"}`)))
	p.line(0, 0, []byte(line))
	p.line(0, 0, []byte(line))
	p.finish()
	l := accountingLedger{Version: 1, Files: map[string]usageFile{"first": {Source: "codex", Records: p.records}, "copied": {Source: "codex", Records: p.records}}}
	os.MkdirAll(filepath.Dir(accountingPath(cache)), 0700)
	if err := saveAccounting(cache, l); err != nil {
		t.Fatal(err)
	}
	rows, _ := accountingRows(cache)
	if len(rows) != 1 || rows[0].ObservedRequests != 2 || *rows[0].TotalTokens != 24 {
		t.Fatalf("copies vs distinct occurrences: %+v", rows)
	}
}

func TestAccountingClearEraseAndPrivateCache(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	path := filepath.Join("testdata", "accounting", "sessions", "2026", "11", "16", "rollout-redacted.jsonl")
	observeCx(t, cache, now, path)
	l, ok := loadAccounting(cache)
	if !ok || len(l.Files) == 0 {
		t.Fatal("accounting missing")
	}
	raw, _ := json.Marshal(l)
	for _, secret := range []string{"redacted-accounting-fixture", path, "last_token_usage", "CONTENT-CANARY"} {
		if strings.Contains(string(raw), secret) {
			t.Fatalf("private cache copied identity/text: %s", secret)
		}
	}
	if err := MarkCleared(cache, "codex", now); err != nil {
		t.Fatal(err)
	}
	rows, _ := accountingRows(cache)
	if len(rows) != 0 {
		t.Fatal("clear resurrected prior usage")
	}
	if err := ForgetAccountingLocked(cache, "codex"); err != nil {
		t.Fatal(err)
	}
	l, _ = loadAccounting(cache)
	if len(l.Files) != 0 {
		t.Fatal("erasure retained event hashes")
	}
}

func TestAccountingForkReplayAndClaudeSidechain(t *testing.T) {
	utc(t)
	cache := t.TempDir()
	at := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	record := usageRecord{Key: "parent", At: at, Model: "m", usageBuckets: usageBuckets{Input: 10, Output: 2}}
	child := record
	child.Key = "rewritten-child"
	child.At = at.Add(10 * time.Millisecond)
	own := record
	own.Key = "own"
	own.At = at.Add(10 * time.Second)
	own.Input = 20
	parent := usageFile{Source: "codex", Session: "parent-session", Records: []usageRecord{record}}
	fork := usageFile{Source: "codex", Session: "child-session", Parent: "parent-session", Started: at, Records: []usageRecord{child, own}}
	main := record
	main.Key = "main"
	main.Replay = "same-session-message"
	side := main
	side.Key = "different-request-id"
	side.Sidechain = true
	side.Output = 100
	l := accountingLedger{Version: 1, Files: map[string]usageFile{"parent": parent, "fork": fork, "claude": {Source: "claude-code", Records: []usageRecord{side, main}}}}
	os.MkdirAll(filepath.Dir(accountingPath(cache)), 0700)
	if err := saveAccounting(cache, l); err != nil {
		t.Fatal(err)
	}
	rows, _ := accountingRows(cache)
	for _, r := range rows {
		switch r.Source {
		case "codex":
			if r.ObservedRequests != 2 || *r.TotalTokens != 34 {
				t.Fatalf("fork replay: %+v", r)
			}
		case "claude-code":
			if r.ObservedRequests != 1 || r.ObservedOutputTokens != 2 {
				t.Fatalf("main must win over sidechain: %+v", r)
			}
		}
	}
}

func TestAccountingImportMigrationAndRemoval(t *testing.T) {
	f := newFixture(t)
	f.codexLog("rollout-import.jsonl", -1)
	seedPerf(t, f.cache, t0)
	a := both()
	f.run(30, a)
	l, ok := LoadPerf(f.cache)
	if !ok {
		t.Fatal("perf load")
	}
	v := (PerfView{Ledger: l, OK: true, Recording: true, Now: f.now}).Admitted(*a)
	windows := v.HistoryWindows()
	if len(windows) != 1 || windows[0].Recent7d.TotalTokens == nil || *windows[0].Recent7d.TotalTokens != 300 {
		t.Fatalf("usage import missing: %+v", windows)
	}
	imp, _ := LoadImported(f.cache)
	if imp.Coverage["codex"].AccountingVersion != 1 {
		t.Fatal("old imports will not be migrated once")
	}
	if err := RemoveImportedUnder(f.cache, *a); err != nil {
		t.Fatal(err)
	}
	l, _ = LoadPerf(f.cache)
	if len(l.UsageRows) != 0 {
		t.Fatal("removed imported usage returned through live ledger")
	}
}

func TestAccountingAdmissionRejectsOldGrant(t *testing.T) {
	a := both()
	epoch := currentEpoch(*a, "codex")
	v := PerfView{Ledger: PerfLedger{UsageRows: []PerfRow{{Source: "codex", GrantEpoch: epoch}, {Source: "codex"}}}, OK: true}
	if got := v.Admitted(*a); len(got.Ledger.UsageRows) != 1 {
		t.Fatal("unstamped accounting admitted")
	}
	state := a.State()
	state.Revoked["codex.local_history"]++
	next := consent.NewAdmission(state, consent.Automatic)
	if got := v.Admitted(next); len(got.Ledger.UsageRows) != 0 {
		t.Fatal("old-grant usage revived")
	}
}

func TestAccountingClaudeAdvisorCacheWrites(t *testing.T) {
	for _, test := range []struct {
		usage string
		want  int64
	}{
		{`{"cache_creation":{"ephemeral_5m_input_tokens":3,"ephemeral_1h_input_tokens":4}}`, 7},
		{`{"cache_creation":{"ephemeral_5m_input_tokens":3},"iterations":[{"type":"message","cache_creation":{"ephemeral_5m_input_tokens":3}},{"type":"message","cache_creation":{"ephemeral_1h_input_tokens":4}}]}`, 7},
		{`{"cache_creation":{"ephemeral_5m_input_tokens":3},"iterations":[{"type":"message"}]}`, 3},
		{`{"cache_creation":{"ephemeral_5m_input_tokens":3},"iterations":false}`, 3},
	} {
		if got := claudeCacheWrites([]byte(test.usage), 99); got != test.want {
			t.Fatalf("cache writes=%d want %d: %s", got, test.want, test.usage)
		}
	}
}

func TestAccountingMigrationPreservesOlderImportedCoverage(t *testing.T) {
	f := newFixture(t)
	f.codexLog("rollout-older.jsonl", -50, -1)
	seedPerf(t, f.cache, t0)
	a := both()
	f.run(70, a)
	old, _ := LoadImported(f.cache)
	span := old.Coverage["codex"]
	from := span.From
	span.AccountingVersion = 0
	old.Coverage["codex"] = span
	if err := writeImported(f.cache, old); err != nil {
		t.Fatal(err)
	}
	f.run(30, a)
	migrated, _ := LoadImported(f.cache)
	if !migrated.Coverage["codex"].From.Equal(from) {
		t.Fatal("migration shortened existing import")
	}
	found := false
	for _, r := range migrated.Rows {
		if r.Day == day(t0.AddDate(0, 0, -50)) {
			found = true
		}
	}
	if !found {
		t.Fatal("migration discarded older history")
	}
}

func TestAccountingRemoteCompactionResponseCountedOnce(t *testing.T) {
	p := newAccountingParser("codex", "file")
	for _, line := range []string{
		cx(0, "turn_context", high),
		cx(1, "token_usage_record", `{"response_id":"redacted","usage":{"input_tokens":100,"cached_input_tokens":90,"output_tokens":10,"reasoning_output_tokens":2}}`),
		cx(2, "compacted", `{"compaction_response_id":"redacted"}`),
		cx(3, "compacted", `{"compaction_response_id":"redacted"}`),
	} {
		p.line(0, 0, []byte(line))
	}
	p.finish()
	if len(p.records) != 1 || p.records[0].Sum() != 110 || p.records[0].Output != 8 || p.records[0].Reasoning != 2 {
		t.Fatalf("compaction identity or reasoning double-counted: %+v", p.records)
	}
}

func TestAccountingClaudeRejectsRelativeTranscript(t *testing.T) {
	cache := t.TempDir()
	if err := ObserveClaude(cache, filepath.Join("testdata", "accounting", "claude", "projects", "redacted", "session.jsonl"), false, Ingest{}, time.Now()); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(accountingPath(cache)); !os.IsNotExist(err) {
		t.Fatal("relative transcript bypassed the observer's path guard")
	}
}

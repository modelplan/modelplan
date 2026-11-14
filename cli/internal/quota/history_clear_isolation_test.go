// SPDX-License-Identifier: MIT
package quota

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	_ "modernc.org/sqlite"

	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// stripCursorSources rewrites both ledgers' log cursors into an earlier build's shape: no source.
func stripCursorSources(t *testing.T, cache string) {
	t.Helper()
	for _, name := range []string{"speed.json", "perf.json"} {
		path := filepath.Join(cache, "observed", name)
		b, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		var doc map[string]json.RawMessage
		var files map[string]map[string]json.RawMessage
		if json.Unmarshal(b, &doc) != nil || json.Unmarshal(doc["files"], &files) != nil {
			t.Fatalf("%s unreadable", name)
		}
		for _, c := range files {
			delete(c, "source")
		}
		doc["files"], _ = json.Marshal(files)
		b, _ = json.Marshal(doc)
		if err := os.WriteFile(path, b, 0600); err != nil {
			t.Fatal(err)
		}
	}
}

// Clearing one tool keeps another tool's log cursors written by an earlier build (no source), and
// a turn of the other tool that finished before the clear but was not read yet still counts once.
// The cleared tool's legacy cursor is attributed and goes.
func TestHistoryClearKeepsOtherToolUnreadTurnWithLegacyCursors(t *testing.T) {
	for _, cleared := range []string{"claude", "codex"} {
		t.Run(cleared, func(t *testing.T) {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_HISTORY", "")
			cache, dir := t.TempDir(), t.TempDir()
			now := time.Now().UTC()
			seedPerfLedger(t, cache, now.Add(-time.Hour))
			rollout, transcript := filepath.Join(dir, "rollout-synthetic.jsonl"), filepath.Join(dir, "claude.jsonl")
			appendFile(t, rollout, codexLines(t, now.Add(-5*time.Minute), 100))
			appendFile(t, transcript, claudeLines(t, now.Add(-5*time.Minute), "synthetic-first", 77))
			codex := func(at time.Time) {
				t.Helper()
				if err := speed.ObserveCodex(cache, []string{rollout}, func(string) bool { return false }, speed.Ingest{}, at); err != nil {
					t.Fatal(err)
				}
			}
			claude := func(at time.Time) {
				t.Helper()
				if err := speed.ObserveClaude(cache, transcript, false, speed.Ingest{}, at); err != nil {
					t.Fatal(err)
				}
			}
			codex(now)
			claude(now)
			stripCursorSources(t, cache)
			// The kept tool finishes a turn before the clear; nothing reads it until after.
			keptSource, keptLog, clearedSource, clearedLog := "codex", rollout, "claude-code", transcript
			wantReq, wantOut := 2, int64(140)
			if cleared == "codex" {
				keptSource, keptLog, clearedSource, clearedLog = "claude-code", transcript, "codex", rollout
				wantOut = 132
				appendFile(t, transcript, claudeLines(t, time.Now().UTC().Add(-40*time.Second), "synthetic-unread", 55))
			} else {
				appendFile(t, rollout, codexLines(t, time.Now().UTC().Add(-40*time.Second), 40))
			}
			if err := EraseScope(Paths{Cache: cache}, cleared+".local_history", true); err != nil {
				t.Fatal(err)
			}
			assertNoResidue(t, cache, clearedSource, clearedLog)
			for _, name := range []string{"speed.json", "perf.json"} {
				b, _ := os.ReadFile(filepath.Join(cache, "observed", name))
				if !strings.Contains(string(b), clearTestKey(keptLog)) {
					t.Errorf("%s lost the other tool's legacy cursor", name)
				}
			}
			if c := speed.LoadCleared(cache); len(c.Tools) != 1 || c.Tools[cleared].IsZero() {
				t.Fatalf("boundary beyond the cleared tool: %+v", c)
			}
			for i := 0; i < 2; i++ {
				if keptSource == "codex" {
					codex(time.Now().UTC().Add(time.Minute))
				} else {
					claude(time.Now().UTC().Add(time.Minute))
				}
			}
			// The synthetic Codex turns make no speed.json row (no per-request timing); perf.json has them.
			sr, so, pr, po := ledgerTotals(t, cache, keptSource)
			if keptSource == "codex" {
				sr, so = pr, po
			}
			if sr != wantReq || so != wantOut || pr != wantReq || po != wantOut {
				t.Fatalf("%s after clearing %s: speed %d/%d perf %d/%d, want %d/%d in both", keptSource, cleared, sr, so, pr, po, wantReq, wantOut)
			}
		})
	}
}

func claudeRequestKey(id string) string {
	h := sha256.Sum256([]byte("claude-request\x00" + id))
	return hex.EncodeToString(h[:8])
}

// After a Claude clear, reading the old transcript and a resumed copy of it again records no
// cleared request hash; a new request's hash is recorded.
func TestHistoryClearClaudeRequestHashesStayErased(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, dir := t.TempDir(), t.TempDir()
	now := time.Now().UTC()
	seedPerfLedger(t, cache, now.Add(-time.Hour))
	old := claudeLines(t, now.Add(-3*time.Minute), "synthetic-old-request", 321)
	a, b := filepath.Join(dir, "original.jsonl"), filepath.Join(dir, "resumed.jsonl")
	appendFile(t, a, old)
	if err := speed.ObserveClaude(cache, a, false, speed.Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if err := EraseScope(Paths{Cache: cache}, "claude.local_history", true); err != nil {
		t.Fatal(err)
	}
	appendFile(t, b, old)
	appendFile(t, b, claudeLines(t, time.Now().UTC().Add(5*time.Second), "synthetic-new-request", 55))
	for _, path := range []string{a, b, a} {
		if err := speed.ObserveClaude(cache, path, false, speed.Ingest{}, now.Add(time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	for _, name := range []string{"speed.json", "perf.json"} {
		raw, _ := os.ReadFile(filepath.Join(cache, "observed", name))
		if strings.Contains(string(raw), claudeRequestKey("synthetic-old-request")) {
			t.Errorf("%s recorded the cleared request's hash again", name)
		}
		if !strings.Contains(string(raw), claudeRequestKey("synthetic-new-request")) {
			t.Errorf("%s did not record the new request's hash", name)
		}
	}
	if sr, so, pr, po := ledgerTotals(t, cache, "claude-code"); sr != 1 || so != 55 || pr != 1 || po != 55 {
		t.Fatalf("only the new request counts: speed %d/%d perf %d/%d", sr, so, pr, po)
	}
}

// zcodeSeen: every request start the perf ledger's ZCode database cursors keep.
func zcodeSeen(t *testing.T, cache string) []int64 {
	t.Helper()
	p, ok := speed.LoadPerf(cache)
	if !ok {
		t.Fatal("perf.json unreadable")
	}
	var out []int64
	for key, c := range p.Stores {
		if strings.HasPrefix(key, "zcode:") {
			for _, at := range c.Seen {
				out = append(out, at)
			}
		}
	}
	return out
}

// After a ZCode clear, the next database reads record no hash or start of a pre-clear request,
// while a request after the clear counts once.
func TestHistoryClearDatabaseKeepsOldRequestHashesGone(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, home := t.TempDir(), t.TempDir()
	now := time.Now().UTC()
	seedPerfLedger(t, cache, now.Add(-time.Hour))
	path := speed.ZCodeDB(home)
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	db, err := sql.Open("sqlite", "file:"+path)
	if err != nil {
		t.Fatal(err)
	}
	defer db.Close()
	exec := func(q string, args ...any) {
		t.Helper()
		if _, err := db.Exec(q, args...); err != nil {
			t.Fatal(err)
		}
	}
	exec(`CREATE TABLE model_usage (id TEXT PRIMARY KEY, session_id TEXT, turn_id TEXT, model_id TEXT, started_at INTEGER,
		completed_at INTEGER, duration_ms INTEGER, input_tokens INTEGER, output_tokens INTEGER, reasoning_tokens INTEGER,
		cache_read_input_tokens INTEGER, cache_creation_input_tokens INTEGER, agent TEXT, mode TEXT);
		CREATE TABLE session (id TEXT PRIMARY KEY, directory TEXT, path TEXT, title TEXT);`)
	exec(`INSERT INTO session VALUES ('z-1', '', '', 'synthetic')`)
	row := func(id string, start time.Time, out int) {
		t.Helper()
		exec(`INSERT INTO model_usage (id, session_id, turn_id, model_id, started_at, completed_at, input_tokens, output_tokens, reasoning_tokens)
			VALUES (?, 'z-1', 't', 'GLM-5.2', ?, ?, 100, ?, 0)`, id, start.UnixMilli(), start.Add(10*time.Second).UnixMilli(), out)
	}
	observe := func(at time.Time) {
		t.Helper()
		if err := speed.ObserveZCode(cache, home, speed.Ingest{}, at); err != nil {
			t.Fatal(err)
		}
	}
	row("old", now.Add(-3*time.Minute), 321)
	observe(now)
	if seen := zcodeSeen(t, cache); len(seen) != 1 {
		t.Fatalf("seed not observed: %v", seen)
	}
	oldAnchors := zcodeAnchors(t, cache)
	if len(oldAnchors) != 1 {
		t.Fatalf("seed made no anchor: %v", oldAnchors)
	}
	if err := EraseScope(Paths{Cache: cache}, "zai.local_history", true); err != nil {
		t.Fatal(err)
	}
	if seen := zcodeSeen(t, cache); len(seen) != 0 {
		t.Fatalf("clear kept request hashes: %v", seen)
	}
	clearedAt := time.Now().UTC()
	observe(clearedAt.Add(time.Minute))
	if seen := zcodeSeen(t, cache); len(seen) != 0 {
		t.Fatalf("the first read after the clear recorded pre-clear request hashes: %v", seen)
	}
	if anchors := zcodeAnchors(t, cache); len(anchors) != 0 {
		t.Fatalf("the first read after the clear recorded a pre-clear request's anchor: %v (before the clear: %v)", anchors, oldAnchors)
	}
	row("new", clearedAt.Add(5*time.Second), 55)
	observe(clearedAt.Add(2 * time.Minute))
	observe(clearedAt.Add(3 * time.Minute))
	seen := zcodeSeen(t, cache)
	if len(seen) != 1 || seen[0] < clearedAt.UnixMilli() {
		t.Fatalf("want only the post-clear request's hash, got starts %v (clear at %d)", seen, clearedAt.UnixMilli())
	}
	if _, _, pr, po := ledgerTotals(t, cache, "zcode"); pr != 1 || po != 55 {
		t.Fatalf("only the new request counts: perf %d/%d", pr, po)
	}
	if anchors := zcodeAnchors(t, cache); len(anchors) != 1 || anchors[0] == oldAnchors[0] {
		t.Fatalf("want the post-clear request's anchor only, got %v (pre-clear %v)", anchors, oldAnchors)
	}
	row("newer", clearedAt.Add(10*time.Second), 11)
	observe(clearedAt.Add(4 * time.Minute))
	observe(clearedAt.Add(5 * time.Minute))
	if _, _, pr, po := ledgerTotals(t, cache, "zcode"); pr != 2 || po != 66 {
		t.Fatalf("later requests count once each: perf %d/%d", pr, po)
	}
}

// claudeUnfinishedLines: a user turn still waiting for its first reply (no request, no session).
func claudeUnfinishedLines(t *testing.T, at time.Time) []byte {
	t.Helper()
	prompt, _ := json.Marshal(map[string]any{"type": "user", "timestamp": at.Format(time.RFC3339Nano), "message": map[string]any{"content": "synthetic prompt"}})
	return append(prompt, '\n')
}

// codexAbortedLines: a Codex turn that was aborted before any token usage (no cumulative total).
func codexAbortedLines(t *testing.T, at time.Time) []byte {
	t.Helper()
	return []byte(fmt.Sprintf(`{"timestamp":%q,"type":"event_msg","payload":{"type":"task_started"}}`+"\n"+
		`{"timestamp":%q,"type":"turn_context","payload":{"model":"synthetic-model","effort":"high"}}`+"\n"+
		`{"timestamp":%q,"type":"event_msg","payload":{"type":"turn_aborted"}}`+"\n",
		at.Format(time.RFC3339Nano), at.Format(time.RFC3339Nano), at.Add(time.Second).Format(time.RFC3339Nano)))
}

// stripCursorEvidence removes, besides each cursor's source, everything else the ledgers could
// attribute a cursor key from: Codex totals, Claude counted hashes, perf sessions and live records.
func stripCursorEvidence(t *testing.T, cache string) {
	t.Helper()
	stripCursorSources(t, cache)
	for _, name := range []string{"speed.json", "perf.json"} {
		path := filepath.Join(cache, "observed", name)
		b, _ := os.ReadFile(path)
		var doc map[string]json.RawMessage
		var files map[string]map[string]json.RawMessage
		if json.Unmarshal(b, &doc) != nil || json.Unmarshal(doc["files"], &files) != nil {
			t.Fatalf("%s unreadable", name)
		}
		for _, c := range files {
			delete(c, "total")
		}
		doc["files"], _ = json.Marshal(files)
		delete(doc, "counted")
		delete(doc, "live")
		if _, ok := doc["sessions"]; ok {
			doc["sessions"] = json.RawMessage("[]")
		}
		b, _ = json.Marshal(doc)
		if err := os.WriteFile(path, b, 0600); err != nil {
			t.Fatal(err)
		}
	}
}

func hasCursor(t *testing.T, cache, log string) (speedHas, perfHas bool) {
	t.Helper()
	for i, name := range []string{"speed.json", "perf.json"} {
		b, _ := os.ReadFile(filepath.Join(cache, "observed", name))
		var doc struct {
			Files map[string]json.RawMessage `json:"files"`
		}
		_ = json.Unmarshal(b, &doc)
		_, found := doc.Files[clearTestKey(log)]
		if i == 0 {
			speedHas = found
		} else {
			perfHas = found
		}
	}
	return
}

// A legacy (source-less) cursor of the cleared tool that nothing in the ledgers attributes (an
// unfinished Claude turn, an aborted Codex turn, outside the tools' log folders) is removed by the
// clear: its path hash, offset and last-read date are the cleared tool's history.
func TestHistoryClearErasesUnattributedLegacyCursor(t *testing.T) {
	for _, tool := range []string{"claude", "codex"} {
		t.Run(tool, func(t *testing.T) {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_HISTORY", "")
			cache, dir := t.TempDir(), t.TempDir()
			now := time.Now().UTC()
			seedPerfLedger(t, cache, now.Add(-time.Hour))
			var log string
			if tool == "claude" {
				log = filepath.Join(dir, "unfinished.jsonl")
				appendFile(t, log, claudeUnfinishedLines(t, now.Add(-time.Minute)))
				if err := speed.ObserveClaude(cache, log, false, speed.Ingest{}, now); err != nil {
					t.Fatal(err)
				}
			} else {
				log = filepath.Join(dir, "rollout-aborted.jsonl")
				appendFile(t, log, codexAbortedLines(t, now.Add(-time.Minute)))
				if err := speed.ObserveCodex(cache, []string{log}, func(string) bool { return false }, speed.Ingest{}, now); err != nil {
					t.Fatal(err)
				}
			}
			if s, p := hasCursor(t, cache, log); !s || !p {
				t.Fatalf("seed made no cursor: speed %v perf %v", s, p)
			}
			stripCursorSources(t, cache)
			if got := speed.LegacyCursorSources(cache, nil)[clearTestKey(log)]; got != "" {
				t.Fatalf("seed is attributable (%q); the case needs an unattributable cursor", got)
			}
			if err := EraseScope(Paths{Cache: cache}, tool+".local_history", true); err != nil {
				t.Fatal(err)
			}
			if s, p := hasCursor(t, cache, log); s || p {
				t.Fatalf("clear kept the unattributed legacy cursor: speed %v perf %v", s, p)
			}
		})
	}
}

// Attribution is taken once, before either ledger is rewritten: a perf.json legacy cursor that only
// speed.json's tagged cursor attributes still goes.
func TestHistoryClearAttributesLegacyCursorsBeforeRewriting(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, dir := t.TempDir(), t.TempDir()
	now := time.Now().UTC()
	seedPerfLedger(t, cache, now.Add(-time.Hour))
	log := filepath.Join(dir, "rollout-aborted.jsonl")
	appendFile(t, log, codexAbortedLines(t, now.Add(-time.Minute)))
	if err := speed.ObserveCodex(cache, []string{log}, func(string) bool { return false }, speed.Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	path := speed.PerfPath(cache)
	b, _ := os.ReadFile(path)
	var doc map[string]json.RawMessage
	var files map[string]map[string]json.RawMessage
	if json.Unmarshal(b, &doc) != nil || json.Unmarshal(doc["files"], &files) != nil {
		t.Fatal("perf.json unreadable")
	}
	for _, c := range files {
		delete(c, "source")
	}
	doc["files"], _ = json.Marshal(files)
	b, _ = json.Marshal(doc)
	if err := os.WriteFile(path, b, 0600); err != nil {
		t.Fatal(err)
	}
	if got := speed.LegacyCursorSources(cache, nil)[clearTestKey(log)]; got != "codex" {
		t.Fatalf("perf.json's legacy cursor not attributable before the clear: %q", got)
	}
	if err := EraseScope(Paths{Cache: cache}, "codex.local_history", true); err != nil {
		t.Fatal(err)
	}
	if s, p := hasCursor(t, cache, log); s || p {
		t.Fatalf("clear kept the cleared tool's cursor: speed %v perf %v", s, p)
	}
}

// Clearing one tool keeps another tool's legacy cursor that nothing in the ledgers attributes when
// its log lies in that tool's log folder, so its already counted turn is not counted again.
func TestHistoryClearKeepsOtherToolLegacyCursorFoundInItsLogFolder(t *testing.T) {
	for _, cleared := range []string{"claude", "codex"} {
		t.Run(cleared, func(t *testing.T) {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_HISTORY", "")
			home, _ := os.UserHomeDir()
			claudeRoot := filepath.Join(t.TempDir(), "claude-config")
			t.Setenv("CLAUDE_CONFIG_DIR", claudeRoot)
			cache := t.TempDir()
			now := time.Now().UTC()
			seedPerfLedger(t, cache, now.Add(-time.Hour))
			rollout := filepath.Join(home, ".codex", "sessions", "2026", "11", "13", "rollout-synthetic.jsonl")
			transcript := filepath.Join(claudeRoot, "projects", "-synthetic", "session.jsonl")
			for _, p := range []string{rollout, transcript} {
				if err := os.MkdirAll(filepath.Dir(p), 0700); err != nil {
					t.Fatal(err)
				}
			}
			appendFile(t, rollout, codexLines(t, now.Add(-5*time.Minute), 100))
			appendFile(t, transcript, claudeLines(t, now.Add(-5*time.Minute), "synthetic-first", 77))
			codex := func(at time.Time) {
				t.Helper()
				if err := speed.ObserveCodex(cache, []string{rollout}, func(string) bool { return false }, speed.Ingest{}, at); err != nil {
					t.Fatal(err)
				}
			}
			claude := func(at time.Time) {
				t.Helper()
				if err := speed.ObserveClaude(cache, transcript, false, speed.Ingest{}, at); err != nil {
					t.Fatal(err)
				}
			}
			codex(now)
			claude(now)
			stripCursorEvidence(t, cache)
			keptSource, keptLog, clearedLog := "codex", rollout, transcript
			wantReq, wantOut := 2, int64(140)
			if cleared == "codex" {
				keptSource, keptLog, clearedLog = "claude-code", transcript, rollout
				wantOut = 132
			}
			if err := EraseScope(Paths{Cache: cache}, cleared+".local_history", true); err != nil {
				t.Fatal(err)
			}
			if s, p := hasCursor(t, cache, clearedLog); s || p {
				t.Fatalf("clear kept the cleared tool's cursor: speed %v perf %v", s, p)
			}
			if s, p := hasCursor(t, cache, keptLog); !s || !p {
				t.Fatalf("clear dropped the other tool's cursor: speed %v perf %v", s, p)
			}
			later := time.Now().UTC()
			if keptSource == "codex" {
				appendFile(t, rollout, codexLines(t, later.Add(5*time.Second), 40))
			} else {
				appendFile(t, transcript, claudeLines(t, later.Add(5*time.Second), "synthetic-second", 55))
			}
			for i := 0; i < 2; i++ {
				if keptSource == "codex" {
					codex(later.Add(time.Minute))
				} else {
					claude(later.Add(time.Minute))
				}
			}
			_, _, pr, po := ledgerTotals(t, cache, keptSource)
			if pr != wantReq || po != wantOut {
				t.Fatalf("%s after clearing %s: perf %d/%d, want %d/%d (no recount)", keptSource, cleared, pr, po, wantReq, wantOut)
			}
		})
	}
}

// zcodeAnchors: every database anchor the perf ledger's ZCode cursors keep.
func zcodeAnchors(t *testing.T, cache string) []string {
	t.Helper()
	p, ok := speed.LoadPerf(cache)
	if !ok {
		t.Fatal("perf.json unreadable")
	}
	var out []string
	for key, c := range p.Stores {
		if strings.HasPrefix(key, "zcode:") && c.Anchor != "" {
			out = append(out, c.Anchor)
		}
	}
	return out
}

// zcodeBatchDB: a synthetic ZCode database at path, with n requests that started at start and
// finished a minute later, one output token each.
func zcodeBatchDB(t *testing.T, path, prefix string, n int, start time.Time) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite", "file:"+path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	if _, err := db.Exec(`CREATE TABLE model_usage (id TEXT PRIMARY KEY, session_id TEXT, model_id TEXT, started_at INTEGER, completed_at INTEGER, output_tokens INTEGER)`); err != nil {
		t.Fatal(err)
	}
	tx, err := db.Begin()
	if err != nil {
		t.Fatal(err)
	}
	stmt, err := tx.Prepare(`INSERT INTO model_usage VALUES (?, 'synthetic-session', 'synthetic-model', ?, ?, 1)`)
	if err != nil {
		t.Fatal(err)
	}
	for i := 0; i < n; i++ {
		if _, err := stmt.Exec(fmt.Sprintf("%s-%d", prefix, i), start.UnixMilli(), start.Add(time.Minute).UnixMilli()); err != nil {
			t.Fatal(err)
		}
	}
	stmt.Close()
	if err := tx.Commit(); err != nil {
		t.Fatal(err)
	}
	return db
}

// zcodeCursor: the one ZCode database cursor of the perf ledger.
func zcodeCursor(t *testing.T, cache string) speed.DBCursor {
	t.Helper()
	p, ok := speed.LoadPerf(cache)
	if !ok {
		t.Fatal("perf.json unreadable")
	}
	var out []speed.DBCursor
	for key, c := range p.Stores {
		if strings.HasPrefix(key, "zcode:") {
			out = append(out, c)
		}
	}
	if len(out) != 1 {
		t.Fatalf("want one ZCode cursor, got %d", len(out))
	}
	return out[0]
}

// A cleared ZCode database with a full read batch (5,000 rows) of pre-clear requests: the clear
// keeps only "cleared through row 5,000" for the tool, the reads start past it and make progress,
// and the requests after the clear count once each, with no pre-clear hash or anchor kept.
func TestHistoryClearDatabaseBatchProgress(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, home := t.TempDir(), t.TempDir()
	now := time.Now().UTC()
	seedPerfLedger(t, cache, now.Add(-time.Hour))
	path := filepath.Join(home, "db.sqlite")
	t.Setenv("MODELPLAN_ZCODE_DB", path)
	db := zcodeBatchDB(t, path, "synthetic-old", 5000, now.Add(-2*time.Minute))
	if err := speed.ObserveZCode(cache, home, speed.Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if err := EraseScope(Paths{Cache: cache}, "zai.local_history", true); err != nil {
		t.Fatal(err)
	}
	cleared := speed.LoadCleared(cache)
	boundary := cleared.Tools["zai"]
	if got := cleared.DBRows["zai"]; got != 5000 {
		t.Fatalf("want the clear to keep the tool's database watermark 5000, got %d (%v)", got, cleared.DBRows)
	}
	raw, err := os.ReadFile(speed.ClearedPath(cache))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(raw), "zcode:") || strings.Contains(string(raw), "synthetic") || strings.Contains(string(raw), home) {
		t.Fatalf("the clear record holds more than tool names, times and row numbers: %s", raw)
	}
	insert := func(id string, at time.Time, out int) {
		t.Helper()
		if _, err := db.Exec(`INSERT INTO model_usage VALUES (?, 'synthetic-session', 'synthetic-model', ?, ?, ?)`, id, at.UnixMilli(), at.Add(time.Second).UnixMilli(), out); err != nil {
			t.Fatal(err)
		}
	}
	insert("synthetic-new", boundary.Add(time.Second), 55)
	for i := 1; i <= 6; i++ {
		if err := speed.ObserveZCode(cache, home, speed.Ingest{}, boundary.Add(time.Duration(i)*time.Minute)); err != nil {
			t.Fatal(err)
		}
		if c := zcodeCursor(t, cache); c.RowID < 5000 || (i > 1 && c.More) {
			t.Fatalf("scan %d made no progress: rowID=%d more=%t", i, c.RowID, c.More)
		}
	}
	if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 1 || out != 55 {
		t.Fatalf("post-clear request must count once after bounded scans: got %d/%d, want 1/55", n, out)
	}
	if seen := zcodeSeen(t, cache); len(seen) != 1 || seen[0] < boundary.UnixMilli() {
		t.Fatalf("want only the post-clear request's hash, got starts %v", seen)
	}
	c := zcodeCursor(t, cache)
	if c.RowID != 5001 || c.Anchor == "" {
		t.Fatalf("want the cursor anchored at the post-clear row 5001, got rowID=%d anchor=%q", c.RowID, c.Anchor)
	}
	insert("synthetic-newer", boundary.Add(2*time.Second), 11)
	for i := 7; i <= 8; i++ {
		if err := speed.ObserveZCode(cache, home, speed.Ingest{}, boundary.Add(time.Duration(i)*time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 2 || out != 66 {
		t.Fatalf("a later request counts once: got %d/%d, want 2/66", n, out)
	}
}

// A database replaced after the clear holds fewer rows than the watermark: the reads fall back to
// the clear time. Its 5,000 pre-clear requests are skipped (and still do not stop the reads), and
// its post-clear request counts once.
func TestHistoryClearDatabaseReplacedFallsBackToClearTime(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, home := t.TempDir(), t.TempDir()
	now := time.Now().UTC()
	seedPerfLedger(t, cache, now.Add(-time.Hour))
	path := filepath.Join(home, "db.sqlite")
	t.Setenv("MODELPLAN_ZCODE_DB", path)
	old := zcodeBatchDB(t, path, "synthetic-old", 6000, now.Add(-2*time.Minute))
	if err := speed.ObserveZCode(cache, home, speed.Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if err := EraseScope(Paths{Cache: cache}, "zai.local_history", true); err != nil {
		t.Fatal(err)
	}
	cleared := speed.LoadCleared(cache)
	boundary := cleared.Tools["zai"]
	if got := cleared.DBRows["zai"]; got != 6000 {
		t.Fatalf("want the watermark 6000, got %d", got)
	}
	old.Close()
	for _, p := range []string{path, path + "-wal", path + "-shm"} {
		os.Remove(p)
	}
	db := zcodeBatchDB(t, path, "synthetic-copied", 5000, now.Add(-90*time.Second))
	if _, err := db.Exec(`INSERT INTO model_usage VALUES ('synthetic-replaced-new', 'synthetic-session', 'synthetic-model', ?, ?, 44)`,
		boundary.Add(time.Second).UnixMilli(), boundary.Add(2*time.Second).UnixMilli()); err != nil {
		t.Fatal(err)
	}
	for i := 1; i <= 6; i++ {
		if err := speed.ObserveZCode(cache, home, speed.Ingest{}, boundary.Add(time.Duration(i)*time.Minute)); err != nil {
			t.Fatal(err)
		}
	}
	if _, _, n, out := ledgerTotals(t, cache, "zcode"); n != 1 || out != 44 {
		t.Fatalf("the replaced database's post-clear request counts once: got %d/%d, want 1/44", n, out)
	}
	if seen := zcodeSeen(t, cache); len(seen) != 1 || seen[0] < boundary.UnixMilli() {
		t.Fatalf("want only the post-clear request's hash, got starts %v", seen)
	}
	if c := zcodeCursor(t, cache); c.RowID != 5001 || c.More {
		t.Fatalf("want the reads through row 5001, got rowID=%d more=%t", c.RowID, c.More)
	}
}

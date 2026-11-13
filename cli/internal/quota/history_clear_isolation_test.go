// SPDX-License-Identifier: MIT
package quota

import (
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
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
}

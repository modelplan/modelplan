// SPDX-License-Identifier: MIT
package quota

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// Clearing a tool's history goes through EraseScope; the ledgers are then filled by the real
// observers and the importer from synthetic logs. Nothing of the cleared history may remain in
// speed.json or perf.json, and nothing of it may be counted again: not by reading its logs from
// the start, not from a resumed Claude Code transcript that copies an old request, not by the
// importer.

func clearTestKey(path string) string {
	h := sha256.Sum256([]byte(path))
	return hex.EncodeToString(h[:8])
}

func claudeLines(t *testing.T, at time.Time, request string, tokens int) []byte {
	t.Helper()
	prompt, _ := json.Marshal(map[string]any{"type": "user", "timestamp": at.Format(time.RFC3339Nano), "message": map[string]any{"content": "synthetic prompt"}})
	reply, _ := json.Marshal(map[string]any{"type": "assistant", "timestamp": at.Add(3 * time.Second).Format(time.RFC3339Nano), "requestId": request, "thinkingDurationMs": 1000,
		"message": map[string]any{"model": "synthetic-model", "content": []map[string]string{{"type": "thinking", "thinking": "synthetic"}}, "stop_reason": "end_turn", "usage": map[string]int{"output_tokens": tokens}}})
	return append(append(append(prompt, '\n'), reply...), '\n')
}

func codexLines(t *testing.T, at time.Time, tokens int) []byte {
	t.Helper()
	var out []byte
	line := func(sec int, kind, payload string) {
		// The rollout's own field order: timestamp, type, payload.
		out = append(out, fmt.Sprintf(`{"timestamp":%q,"type":%q,"payload":%s}`+"\n", at.Add(time.Duration(sec)*time.Second).Format(time.RFC3339Nano), kind, payload)...)
	}
	usage := fmt.Sprintf(`{"input_tokens":50,"output_tokens":%d}`, tokens)
	line(1, "event_msg", `{"type":"task_started"}`)
	line(1, "turn_context", `{"model":"synthetic-model","effort":"high"}`)
	line(2, "event_msg", `{"type":"token_count","info":{"last_token_usage":`+usage+`,"total_token_usage":`+usage+`}}`)
	line(3, "event_msg", `{"type":"task_complete","duration_ms":2000}`)
	return out
}

func appendFile(t *testing.T, path string, b []byte) {
	t.Helper()
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.Write(b); err != nil {
		t.Fatal(err)
	}
	f.Close()
}

// ledgerTotals: requests and output tokens of source in both ledgers.
func ledgerTotals(t *testing.T, cache, source string) (speedReq int, speedOut int64, perfReq int, perfOut int64) {
	t.Helper()
	for _, r := range speed.Load(cache).Rows {
		if r.Source == source {
			speedReq, speedOut = speedReq+r.Requests, speedOut+r.OutputTokens
		}
	}
	p, ok := speed.LoadPerf(cache)
	if !ok {
		t.Fatal("perf.json unreadable")
	}
	for _, r := range p.Rows {
		if r.Source == source {
			perfReq, perfOut = perfReq+r.ObservedRequests, perfOut+r.ObservedOutputTokens
		}
	}
	return
}

// assertNoResidue: neither ledger holds a cursor for any of the cleared tool's logs, any request
// hash, row or session of it.
func assertNoResidue(t *testing.T, cache, source string, logs ...string) {
	t.Helper()
	for _, name := range []string{"speed.json", "perf.json"} {
		b, err := os.ReadFile(filepath.Join(cache, "observed", name))
		if err != nil {
			t.Fatal(err)
		}
		var doc struct {
			Files    map[string]json.RawMessage `json:"files"`
			Counted  []json.RawMessage          `json:"counted"`
			Rows     []struct{ Source string }  `json:"rows"`
			Sessions []struct{ Source string }  `json:"sessions"`
		}
		if err := json.Unmarshal(b, &doc); err != nil {
			t.Fatal(err)
		}
		for _, p := range logs {
			if c, found := doc.Files[clearTestKey(p)]; found {
				t.Errorf("%s kept the cleared log's cursor (path hash, offset, last-read date): %s", name, c)
			}
		}
		if source == "claude-code" && len(doc.Counted) > 0 {
			t.Errorf("%s kept counted request hashes: %d", name, len(doc.Counted))
		}
		for _, r := range append(doc.Rows, doc.Sessions...) {
			if r.Source == source {
				t.Errorf("%s kept a %s row or session", name, source)
			}
		}
		if strings.Contains(string(b), `"total"`) && source == "codex" {
			t.Errorf("%s kept a cumulative Codex total", name)
		}
	}
}

func seedPerfLedger(t *testing.T, cache string, since time.Time) {
	t.Helper()
	if err := os.MkdirAll(filepath.Join(cache, "observed"), 0700); err != nil {
		t.Fatal(err)
	}
	b, _ := json.Marshal(speed.PerfLedger{SchemaVersion: 1, Since: since, Rows: []speed.PerfRow{}})
	if err := os.WriteFile(speed.PerfPath(cache), b, 0600); err != nil {
		t.Fatal(err)
	}
}

// A cleared Claude Code history stays cleared: the original transcript read again, a resumed
// session's copy of the old request, with or without a revoke and regrant around the clear.
func TestHistoryClearClaudeResumeDoesNotRecountClearedRequest(t *testing.T) {
	for _, regrant := range []bool{false, true} {
		t.Run(map[bool]string{false: "clear", true: "revoke-clear-regrant"}[regrant], func(t *testing.T) {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_HISTORY", "")
			cache, dir := t.TempDir(), t.TempDir()
			now := time.Now().UTC()
			grant := func(on bool, at time.Time) {
				t.Helper()
				if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "claude", on, "", "", at) }); err != nil {
					t.Fatal(err)
				}
			}
			grant(true, now.Add(-time.Hour))
			seedPerfLedger(t, cache, now.Add(-time.Hour))
			old := claudeLines(t, now.Add(-3*time.Minute), "synthetic-old-request", 321)
			a, b := filepath.Join(dir, "original.jsonl"), filepath.Join(dir, "resumed.jsonl")
			appendFile(t, a, old)
			if err := speed.ObserveClaude(cache, a, false, speed.Ingest{}, now); err != nil {
				t.Fatal(err)
			}
			if sr, so, pr, po := ledgerTotals(t, cache, "claude-code"); sr != 1 || so != 321 || pr != 1 || po != 321 {
				t.Fatalf("seed not observed: speed %d/%d perf %d/%d", sr, so, pr, po)
			}
			if regrant {
				grant(false, now)
			}
			if err := EraseScope(Paths{Cache: cache}, "claude.local_history", true); err != nil {
				t.Fatal(err)
			}
			assertNoResidue(t, cache, "claude-code", a)
			if regrant {
				grant(true, time.Now().UTC())
			}
			// The resumed session copies the old request, then makes a new one after the clear.
			appendFile(t, b, old)
			appendFile(t, b, claudeLines(t, time.Now().UTC().Add(5*time.Second), "synthetic-new-request", 55))
			for _, path := range []string{a, b, a} {
				if err := consent.LocalWrite("claude", func() error {
					return speed.ObserveClaude(cache, path, false, speed.Ingest{}, now.Add(time.Minute))
				}); err != nil {
					t.Fatal(err)
				}
			}
			if sr, so, pr, po := ledgerTotals(t, cache, "claude-code"); sr != 1 || so != 55 || pr != 1 || po != 55 {
				t.Fatalf("after the clear only the new request counts: want 1/55 in both, speed %d/%d perf %d/%d", sr, so, pr, po)
			}
		})
	}
}

// A cleared Codex history leaves no cursor of its rollouts and is not read again from the start;
// another tool's cursor and rows stay.
func TestHistoryClearCodexRemovesCursorsAndDoesNotRecount(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, dir := t.TempDir(), t.TempDir()
	now := time.Now().UTC()
	seedPerfLedger(t, cache, now.Add(-time.Hour))
	rollout, transcript := filepath.Join(dir, "rollout-synthetic.jsonl"), filepath.Join(dir, "claude.jsonl")
	appendFile(t, rollout, codexLines(t, now.Add(-2*time.Minute), 100))
	appendFile(t, transcript, claudeLines(t, now.Add(-2*time.Minute), "synthetic-kept", 77))
	codex := func(at time.Time) {
		t.Helper()
		if err := speed.ObserveCodex(cache, []string{rollout}, func(string) bool { return false }, speed.Ingest{}, at); err != nil {
			t.Fatal(err)
		}
	}
	codex(now)
	if err := speed.ObserveClaude(cache, transcript, false, speed.Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	if _, _, pr, po := ledgerTotals(t, cache, "codex"); pr != 1 || po != 100 {
		t.Fatalf("seed not observed: perf %d/%d", pr, po)
	}
	if err := EraseScope(Paths{Cache: cache}, "codex.local_history", true); err != nil {
		t.Fatal(err)
	}
	assertNoResidue(t, cache, "codex", rollout)
	for _, name := range []string{"speed.json", "perf.json"} {
		b, _ := os.ReadFile(filepath.Join(cache, "observed", name))
		if !strings.Contains(string(b), clearTestKey(transcript)) {
			t.Errorf("%s lost the other tool's cursor", name)
		}
	}
	codex(now.Add(time.Minute)) // the old rollout, read again without its cursor
	appendFile(t, rollout, codexLines(t, time.Now().UTC().Add(5*time.Second), 40))
	codex(now.Add(2 * time.Minute))
	if sr, so, pr, po := ledgerTotals(t, cache, "codex"); pr != 1 || po != 40 || so > 40 || sr > 1 {
		t.Fatalf("after the clear only the new turn counts: speed %d/%d perf %d/%d", sr, so, pr, po)
	}
	if _, _, pr, po := ledgerTotals(t, cache, "claude-code"); pr != 1 || po != 77 {
		t.Fatalf("the other tool's rows changed: %d/%d", pr, po)
	}
	c := speed.LoadCleared(cache)
	if len(c.Tools) != 1 || c.Tools["codex"].IsZero() {
		t.Fatalf("boundary file holds more than the cleared tool's time: %+v", c)
	}
}

// The importer honours the boundary: a cleared history is not imported again.
func TestHistoryClearImporterDoesNotReimportClearedHistory(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache, root := t.TempDir(), t.TempDir()
	now := time.Now().UTC()
	seedPerfLedger(t, cache, now.Add(-time.Hour))
	project := filepath.Join(root, "projects", "synthetic")
	if err := os.MkdirAll(project, 0700); err != nil {
		t.Fatal(err)
	}
	appendFile(t, filepath.Join(project, "old.jsonl"), claudeLines(t, now.Add(-48*time.Hour), "synthetic-imported", 400))
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
	adm := consent.NewAdmission(state, consent.Automatic)
	run := func() speed.ImportResult {
		t.Helper()
		res, err := speed.Import(t.Context(), cache, speed.ImportOptions{Claude: &speed.ImportRoot{Dir: root}, Now: time.Now(), Admission: &adm})
		if err != nil {
			t.Fatal(err)
		}
		return res
	}
	if res := run(); res.Sources[0].Turns != 1 {
		t.Fatalf("seed not imported: %+v", res)
	}
	if err := EraseScope(Paths{Cache: cache}, "claude.local_history", true); err != nil {
		t.Fatal(err)
	}
	run()
	l, _ := speed.LoadImported(cache)
	for _, r := range l.Rows {
		if r.Source == "claude-code" {
			t.Fatalf("cleared history imported again: %+v", r)
		}
	}
}

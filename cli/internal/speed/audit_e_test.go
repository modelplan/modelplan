package speed

import (
	"path/filepath"
	"testing"
	"time"
)

func perfTotals(t *testing.T, cache, source string) (requests int, out int64) {
	t.Helper()
	l, ok := LoadPerf(cache)
	if !ok {
		t.Fatal("perf ledger unreadable")
	}
	for _, r := range l.Rows {
		if r.Source == source {
			requests += r.ObservedRequests
			out += r.ObservedOutputTokens
		}
	}
	return
}

// Audit E finding 4: a resumed Claude Code session copies request R into a new transcript. Normal
// observation of both transcripts counts R once: two requests and 150 tokens, not three and 250.
func TestAuditEClaudeResumedSessionCountsACopiedRequestOnce(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	a, b := filepath.Join(dir, "a.jsonl"), filepath.Join(dir, "b.jsonl")
	r := []string{ccPrompt(0), ccReply(3, "req-R", "m", "high", "", 100, 1000, "end_turn", false)}
	writeLines(t, a, r...)
	if err := ObserveClaude(cache, a, false, Ingest{}, t0.Add(2*time.Minute)); err != nil {
		t.Fatal(err)
	}
	writeLines(t, b, r...)
	writeLines(t, b, ccPrompt(200), ccReply(203, "req-S", "m", "high", "", 50, 1000, "end_turn", false))
	if err := ObserveClaude(cache, b, false, Ingest{}, t0.Add(10*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if n, out := perfTotals(t, cache, "claude-code"); n != 2 || out != 150 {
		t.Fatalf("perf: want 2 requests / 150 tokens, got %d / %d", n, out)
	}
	var reqs int
	var out int64
	for _, row := range Load(cache).Rows {
		reqs += row.Requests
		out += row.OutputTokens
	}
	if reqs != 2 || out != 150 {
		t.Fatalf("speed: want 2 requests / 150 tokens, got %d / %d", reqs, out)
	}
	// Reading the original transcript again (new lines appended) does not drop its own requests.
	writeLines(t, a, ccPrompt(400), ccReply(403, "req-T", "m", "high", "", 30, 1000, "end_turn", false))
	if err := ObserveClaude(cache, a, false, Ingest{}, t0.Add(20*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if n, out := perfTotals(t, cache, "claude-code"); n != 3 || out != 180 {
		t.Fatalf("after T: want 3 requests / 180 tokens, got %d / %d", n, out)
	}
}

// Audit E finding 5: a cumulative-only Codex usage record appended after a read is measured from
// the total at the cursor, as reading the whole rollout at once would.
func TestAuditECodexCumulativeBaselineSurvivesIncrementalReads(t *testing.T) {
	utc(t)
	turn1 := []string{cx(0, "event_msg", `{"type":"task_started"}`), cx(0, "turn_context", high),
		cx(2, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"input_tokens":50,"output_tokens":100},"total_token_usage":{"input_tokens":50,"output_tokens":100}}}`),
		cx(3, "event_msg", `{"type":"task_complete","duration_ms":3000}`)}
	turn2 := []string{cx(60, "event_msg", `{"type":"task_started"}`), cx(60, "turn_context", high),
		cx(62, "event_msg", `{"type":"token_count","info":{"total_token_usage":{"input_tokens":120,"output_tokens":300}}}`),
		cx(63, "event_msg", `{"type":"task_complete","duration_ms":3000}`)}

	whole := t.TempDir()
	seedPerf(t, whole, t0.Add(-time.Minute))
	pw := filepath.Join(t.TempDir(), "rollout-whole.jsonl")
	writeLines(t, pw, append(append([]string{}, turn1...), turn2...)...)
	observeCx(t, whole, t0.Add(5*time.Minute), pw)
	wn, wout := perfTotals(t, whole, "codex")
	if wn != 2 || wout != 300 {
		t.Fatalf("whole read: want 2 requests / 300 tokens, got %d / %d", wn, wout)
	}

	inc := t.TempDir()
	seedPerf(t, inc, t0.Add(-time.Minute))
	pi := filepath.Join(t.TempDir(), "rollout-inc.jsonl")
	writeLines(t, pi, turn1...)
	observeCx(t, inc, t0.Add(30*time.Second), pi)
	writeLines(t, pi, turn2...)
	observeCx(t, inc, t0.Add(5*time.Minute), pi)
	if n, out := perfTotals(t, inc, "codex"); n != wn || out != wout {
		t.Fatalf("incremental read: want %d requests / %d tokens, got %d / %d", wn, wout, n, out)
	}
}

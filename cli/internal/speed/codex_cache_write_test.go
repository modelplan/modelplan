// SPDX-License-Identifier: MIT
package speed

// Post-merge sampling 2026-11-19 S5: Codex cache writes are counted once in session totals.

import (
	"fmt"
	"path/filepath"
	"testing"
	"time"
)

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

// macrevd-1082-3: a usage record with cache writes, then a notice without them, still counts
// the writes once (105, not 115).
func TestCodexSessionTotalWhenNoticeLacksCacheWrites(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "rollout-n.jsonl")
	writeLines(t, p, cx(0, "session_meta", `{"id":"n","source":"cli"}`), cx(0, "event_msg", `{"type":"task_started"}`), cx(0, "turn_context", high),
		cx(1, "event_msg", `{"type":"item_completed","item":{"type":"AgentMessage","id":"i"},"started_at_ms":`+fmt.Sprint(t0.Add(time.Second).UnixMilli())+`}`),
		cx(3, "token_usage_record", `{"response_id":"r","usage":{"input_tokens":100,"cached_input_tokens":60,"cache_write_input_tokens":10,"output_tokens":5}}`),
		cx(3, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"input_tokens":100,"cached_input_tokens":60,"output_tokens":5}}}`),
		cx(4, "event_msg", `{"type":"task_complete","duration_ms":4000}`))
	if err := ObserveCodex(cache, []string{p}, func(string) bool { return false }, Ingest{}, t0.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	l, ok := LoadPerf(cache)
	if !ok || len(l.Sessions) != 1 || len(l.Sessions[0].Days) == 0 {
		t.Fatalf("ledger: %+v", l)
	}
	d := l.Sessions[0].Days[0]
	if got, ok := d.CompleteTotal(); !ok || got != 105 {
		t.Fatalf("CompleteTotal = %d, %v; want 105 (kinds %+v)", got, ok, d.Kinds)
	}
}

package speed

import (
	"fmt"
	"path/filepath"
	"testing"
	"time"
)

// Codex records a response's token_usage_record when the response completes, then runs the
// response's tools, records their outputs, and only then writes the token_count notice for the
// same response (codex-rs core/src/session/turn.rs: send_token_count_event after drain_in_flight;
// Token Monitor docs/providers/codex.md, "Codex can persist token_count after local tools finish").
// The notice is not a new request: it must neither count the response twice nor stop the next
// response from being timed.
func TestCodexTokenCountAfterToolOutputIsTheSameResponse(t *testing.T) {
	cache, dir := t.TempDir(), t.TempDir()
	p := filepath.Join(dir, "rollout-2026-10-17T09-00-00-t.jsonl")
	ms := func(s float64) int64 { return t0.Add(time.Duration(s * float64(time.Second))).UnixMilli() }
	writeLines(t, p,
		cx(0, "session_meta", `{"id":"t","source":"cli"}`),
		cx(0, "event_msg", `{"type":"task_started","turn_id":"1"}`),
		cx(0.1, "turn_context", `{"model":"gpt-6-sol","effort":"high"}`),
		cx(0.2, "event_msg", `{"type":"user_message","message":"do it"}`),
		cx(1.5, "event_msg", fmt.Sprintf(`{"type":"item_completed","item":{"type":"Reasoning","id":"i1"},"started_at_ms":%d}`, ms(1))),
		cx(3, "response_item", `{"type":"custom_tool_call","call_id":"c1","name":"exec"}`),
		cx(3.1, "token_usage_record", `{"response_id":"r1","usage":{"input_tokens":10,"output_tokens":300}}`),
		cx(20, "response_item", `{"type":"custom_tool_call_output","call_id":"c1","output":"slow tool"}`), // the tool ran 17 s
		cx(20.01, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"output_tokens":300}}}`),
		cx(21.5, "event_msg", fmt.Sprintf(`{"type":"item_completed","item":{"type":"Reasoning","id":"i2"},"started_at_ms":%d}`, ms(21))),
		cx(24, "token_usage_record", `{"response_id":"r2","usage":{"input_tokens":20,"output_tokens":600}}`),
		cx(24.01, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"input_tokens":20,"output_tokens":600}}}`),
		cx(25, "event_msg", `{"type":"task_complete","turn_id":"1","duration_ms":25000}`),
	)
	if err := ObserveCodex(cache, []string{p}, func(string) bool { return false }, Ingest{}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	r := onlyRow(t, Load(cache), "")
	// 300 tokens over 1→3.1 s and 600 over 21→24 s: two requests, 900 tokens in 5.1 s.
	if r.Requests != 2 || r.OutputTokens != 900 || r.GenMs != 5100 {
		t.Fatalf("requests %d, output %d, gen %d ms; want 2, 900, 5100", r.Requests, r.OutputTokens, r.GenMs)
	}
}

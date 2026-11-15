package speed

import (
	"fmt"
	"path/filepath"
	"testing"
	"time"
)

// G3-101: Codex 0.16x writes each response's usage record, runs the tool call, writes the
// tool output and only then the token_count notice for that same response. The notice must
// not count as a second request (doubled output, no generation time, so the today rate
// stayed below MinSamples and the widget showed "-- t/s").
func TestG3101CodexNoticeAfterToolOutputIsNotANewRequest(t *testing.T) {
	utc(t)
	cache := t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	ms := func(s float64) int64 { return t0.Add(time.Duration(s * float64(time.Second))).UnixMilli() }
	lines := []string{cx(0, "event_msg", `{"type":"task_started"}`), cx(0, "turn_context", high), cx(0.1, "event_msg", `{"type":"user_message","message":"x"}`)}
	at := 1.0
	for i := 0; i < MinSamples; i++ {
		lines = append(lines,
			cx(at+0.5, "event_msg", fmt.Sprintf(`{"type":"item_completed","item":{"type":"Reasoning","id":"r%d"},"started_at_ms":%d}`, i, ms(at+0.5))),
			cx(at+2.5, "response_item", `{"type":"custom_tool_call","name":"exec","input":"CONTENT-CANARY"}`),
			cx(at+2.5, "token_usage_record", fmt.Sprintf(`{"response_id":"r%d","usage":{"input_tokens":1000,"cached_input_tokens":900,"output_tokens":100}}`, i)),
			cx(at+3, "response_item", `{"type":"custom_tool_call_output","output":"CONTENT-CANARY"}`),
			cx(at+3, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"input_tokens":1000,"cached_input_tokens":900,"output_tokens":100}}}`))
		at += 4
	}
	lines = append(lines, cx(at, "event_msg", `{"type":"task_complete","duration_ms":20000}`))
	p := filepath.Join(t.TempDir(), "cx.jsonl")
	writeLines(t, p, lines...)
	observeCx(t, cache, t0.Add(time.Minute), p)
	r := view(t, cache, t0.Add(time.Minute)).Ledger.Rows[0]
	if r.ObservedRequests != MinSamples || r.ObservedOutputTokens != 100*MinSamples || r.EligibleRequests != MinSamples || r.GenMs != int64(MinSamples)*2000 {
		t.Fatalf("%+v", r)
	}
}

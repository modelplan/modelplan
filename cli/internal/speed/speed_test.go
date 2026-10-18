package speed

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var t0 = time.Date(2026, 10, 17, 9, 0, 0, 0, time.UTC)

// recent sets the fixtures' clock to just before now, for tests that follow the ledger file's own time.
func recent(t *testing.T) time.Time {
	old := t0
	t0 = time.Now().Add(-2 * time.Minute)
	t.Cleanup(func() { t0 = old })
	return t0
}

func at(s float64) string {
	return t0.Add(time.Duration(s * float64(time.Second))).UTC().Format("2006-01-02T15:04:05.000Z")
}

func ccPrompt(s float64) string {
	return fmt.Sprintf(`{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"a question"},"uuid":"u%g","timestamp":%q}`, s, at(s))
}

func ccTool(s float64) string {
	return fmt.Sprintf(`{"isSidechain":false,"type":"user","message":{"role":"user","content":[{"tool_use_id":"x","type":"tool_result","content":"toolsaid"}]},"timestamp":%q}`, at(s))
}

// ccReply: one block of a reply; thinkingMs > 0 makes it a thinking block.
func ccReply(s float64, req, model, effort, speed string, out int, thinkingMs int, stop string, sidechain bool) string {
	block, extra := `{"type":"text","text":"answer"}`, ""
	if thinkingMs > 0 {
		block, extra = `{"type":"thinking","thinking":"hmm"}`, fmt.Sprintf(`,"thinkingDurationMs":%d`, thinkingMs)
	}
	return fmt.Sprintf(`{"isSidechain":%v,"type":"assistant","requestId":%q,"effort":%q%s,"message":{"model":%q,"role":"assistant","content":[%s],"stop_reason":%q,"usage":{"input_tokens":5,"output_tokens":%d,"speed":%q,"service_tier":"standard"}},"timestamp":%q}`,
		sidechain, req, effort, extra, model, block, stop, out, speed, at(s))
}

func writeLines(t *testing.T, p string, lines ...string) {
	f, err := os.OpenFile(p, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		t.Fatal(err)
	}
	f.WriteString(strings.Join(lines, "\n") + "\n")
	f.Close()
}

func onlyRow(t *testing.T, l Ledger, speed string) Row {
	t.Helper()
	for _, r := range l.Rows {
		if r.Speed == speed {
			return r
		}
	}
	t.Fatalf("no %q row in %+v", speed, l.Rows)
	return Row{}
}

func TestClaudeTranscript(t *testing.T) {
	cache, dir := t.TempDir(), t.TempDir()
	p := filepath.Join(dir, "session.jsonl")
	writeLines(t, p,
		ccPrompt(0),
		ccReply(3, "r1", "claude-opus-5-5", "high", "standard", 300, 1000, "tool_use", false), // first token at 2s
		ccReply(5, "r1", "claude-opus-5-5", "high", "standard", 300, 0, "tool_use", false),
		ccReply(6, "s1", "claude-haiku-5-5", "low", "standard", 999, 500, "end_turn", true), // a subagent: not this turn
		ccTool(8),
		ccReply(10, "r2", "claude-opus-5-5", "high", "standard", 350, 1500, "end_turn", false), // first token at 8.5s
		ccReply(12, "r2", "claude-opus-5-5", "high", "standard", 350, 0, "end_turn", false),
		ccReply(13, "e1", "<synthetic>", "", "", 0, 0, "end_turn", false),
		ccPrompt(60),
		ccReply(64, "r3", "claude-opus-5-5", "high", "fast", 500, 2000, "end_turn", false),
	)
	if err := ObserveClaude(cache, p, false, t0.Add(70*time.Second)); err != nil {
		t.Fatal(err)
	}
	l := Load(cache)
	r := onlyRow(t, l, "")
	if len(l.Rows) != 1 || r.Model != "claude-opus-5-5" || r.Effort != "high" || r.Requests != 2 || r.OutputTokens != 650 || r.GenMs != 6500 || r.Turns != 1 || r.TTFTMs.Count() != 2 {
		t.Fatalf("first turn: %+v", l.Rows)
	}
	if m := r.TurnMs.Median(); m < 11000 || m > 13500 { // 12 s, within a bucket
		t.Errorf("turn median %v", m)
	}
	// The second turn is still open (ended 6 s ago): it is read again next time, and counted once.
	writeLines(t, p, ccPrompt(120))
	if err := ObserveClaude(cache, p, false, t0.Add(121*time.Second)); err != nil {
		t.Fatal(err)
	}
	l = Load(cache)
	if f := onlyRow(t, l, "fast"); f.Turns != 1 || f.Requests != 1 || f.OutputTokens != 500 || onlyRow(t, l, "").Turns != 1 {
		t.Fatalf("after the next prompt: %+v", l.Rows)
	}
	b, _ := os.ReadFile(Path(cache))
	for _, leak := range []string{"question", "answer", "hmm", "toolsaid", dir, "r1", "session"} {
		if strings.Contains(string(b), leak) {
			t.Errorf("ledger holds %q: %s", leak, b)
		}
	}
	if fi, _ := os.Stat(Path(cache)); fi.Mode().Perm() != 0o600 {
		t.Errorf("mode %v", fi.Mode())
	}
}

func TestStatusLineReadsAtMostEveryFewSeconds(t *testing.T) {
	cache, dir := t.TempDir(), t.TempDir()
	p := filepath.Join(dir, "s.jsonl")
	recent(t)
	writeLines(t, p, ccPrompt(0), ccReply(3, "r1", "claude-opus-5-5", "high", "", 300, 1000, "end_turn", false), ccPrompt(50))
	now := time.Now()
	ObserveClaude(cache, p, true, now)
	writeLines(t, p, ccReply(53, "r2", "claude-opus-5-5", "high", "", 300, 1000, "end_turn", false), ccPrompt(90))
	ObserveClaude(cache, p, true, now) // right after a write: skipped
	if l := Load(cache); len(l.Rows) != 1 || l.Rows[0].Turns != 1 {
		t.Fatalf("rows = %+v", l.Rows)
	}
	ObserveClaude(cache, p, false, now) // a hook reads now
	if l := Load(cache); l.Rows[0].Turns != 2 {
		t.Fatalf("rows = %+v", l.Rows)
	}
}

func TestInterruptedClaudeTurnIsDropped(t *testing.T) {
	cache, dir := t.TempDir(), t.TempDir()
	p := filepath.Join(dir, "s.jsonl")
	writeLines(t, p, ccPrompt(0), ccReply(3, "r1", "claude-opus-5-5", "high", "", 300, 1000, "tool_use", false))
	ObserveClaude(cache, p, false, t0.Add(2*time.Hour))
	l := Load(cache)
	fi, _ := os.Stat(p)
	if len(l.Rows) != 0 || l.Files[fileKey(p)].Offset != fi.Size() {
		t.Fatalf("an interrupted turn idle for hours is dropped and not read again: %+v", l)
	}
}

func cx(s float64, kind, payload string) string {
	return fmt.Sprintf(`{"timestamp":%q,"type":%q,"payload":%s}`, at(s), kind, payload)
}

func TestCodexRollout(t *testing.T) {
	cache, dir := t.TempDir(), t.TempDir()
	p := filepath.Join(dir, "rollout-2026-10-17T09-00-00-a.jsonl")
	ms := func(s float64) int64 { return t0.Add(time.Duration(s * float64(time.Second))).UnixMilli() }
	writeLines(t, p,
		cx(0, "session_meta", `{"id":"a","source":"cli"}`),
		cx(0, "event_msg", `{"type":"task_started","turn_id":"1"}`),
		cx(0.1, "turn_context", `{"model":"gpt-6-sol","effort":"high","service_tier":"fast"}`),
		cx(0.2, "event_msg", `{"type":"user_message","message":"do it"}`),
		cx(1.5, "event_msg", fmt.Sprintf(`{"type":"item_completed","item":{"type":"Reasoning","id":"i1"},"started_at_ms":%d,"completed_at_ms":%d}`, ms(1.2), ms(1.5))),
		cx(5.2, "token_usage_record", `{"response_id":"x","usage":{"input_tokens":10,"output_tokens":400}}`),
		cx(5.2, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"output_tokens":400},"total_token_usage":{"output_tokens":400}},"rate_limits":null}`), // the same response again
		cx(6, "response_item", `{"type":"function_call_output","call_id":"c","output":"lots"}`),
		cx(9, "event_msg", fmt.Sprintf(`{"type":"item_completed","item":{"type":"AgentMessage","id":"i2"},"started_at_ms":%d}`, ms(7))),
		cx(9, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"output_tokens":200}},"rate_limits":{"limit_id":"codex"}}`),
		cx(9.5, "event_msg", `{"type":"task_complete","turn_id":"1","duration_ms":9500,"time_to_first_token_ms":1000}`),
		cx(20, "event_msg", `{"type":"task_started","turn_id":"2"}`),
		cx(20.1, "turn_context", `{"model":"gpt-6-sol","effort":"high"}`),
		cx(25, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"output_tokens":50}}}`),
		cx(26, "event_msg", `{"type":"turn_aborted","reason":"interrupted"}`),
		cx(30, "event_msg", `{"type":"task_started","turn_id":"3"}`), // still running
	)
	review := filepath.Join(dir, "rollout-2026-10-17T09-00-00-b.jsonl")
	writeLines(t, review, cx(0, "session_meta", `{"id":"b","source":{"subagent":"review"}}`),
		cx(0, "event_msg", `{"type":"task_started"}`), cx(1, "turn_context", `{"model":"gpt-6-sol"}`), cx(5, "event_msg", `{"type":"task_complete","duration_ms":5000}`))
	bg := func(path string) bool { return path == review }
	if err := ObserveCodex(cache, []string{p, review}, bg, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	l := Load(cache)
	r := onlyRow(t, l, "fast")
	// 400 tokens over 1.2→5.2 s and 200 over 7→9 s: 600 tokens in 6 s.
	if len(l.Rows) != 1 || r.Effort != "high" || r.Requests != 2 || r.OutputTokens != 600 || r.GenMs != 6000 || r.Turns != 1 || r.TTFTMs.Count() != 2 {
		t.Fatalf("rows = %+v", l.Rows)
	}
	if m := r.TurnMs.Median(); m < 9000 || m > 10500 {
		t.Errorf("turn median %v", m)
	}
	if c := l.Files[fileKey(review)]; !c.Skip {
		t.Errorf("the review thread is skipped: %+v", c)
	}
	// The running third turn is read again once it completes.
	writeLines(t, p, cx(30.1, "turn_context", `{"model":"gpt-6-sol","effort":"medium"}`), cx(40, "event_msg", `{"type":"task_complete","duration_ms":10000}`))
	ObserveCodex(cache, []string{p, review}, bg, t0.Add(2*time.Minute))
	if l = Load(cache); len(l.Rows) != 2 {
		t.Fatalf("rows = %+v", l.Rows)
	}
}

func TestSummaryNeedsEnoughSamples(t *testing.T) {
	var l Ledger
	now := time.Now()
	for i := 0; i < MinSamples; i++ {
		l.add("codex", turn{cfg: config{"gpt-6-sol", "medium", ""}, at: now, dur: 40 * time.Second, out: 1000,
			reqs: []request{{out: 500, gen: 5 * time.Second, ttft: 2 * time.Second}}})
	}
	l.add("codex", turn{cfg: config{"gpt-6-sol", "high", ""}, at: now, dur: time.Minute, out: 2000, reqs: []request{{out: 500, gen: 5 * time.Second}}})
	ss := Summarize(l, now)
	if len(ss) != 2 || ss[0].Effort != "high" || ss[0].TurnSeconds != nil || ss[0].OutputTokensPerSecond != nil || ss[0].Turns != 1 {
		t.Fatalf("one sample gives counts only: %+v", ss[0])
	}
	m := ss[1]
	if *m.OutputTokensPerSecond != 100 || *m.TTFTSeconds < 1.9 || *m.TTFTSeconds > 2.2 || *m.TurnSeconds < 38 || *m.TurnSeconds > 42 || *m.TurnOutputTokens < 950 || *m.TurnOutputTokens > 1050 {
		t.Fatalf("medium = %+v", m)
	}
}

func TestOffMeansOff(t *testing.T) {
	t.Setenv("MODELPLAN_HISTORY", "off")
	cache, dir := t.TempDir(), t.TempDir()
	p := filepath.Join(dir, "s.jsonl")
	writeLines(t, p, ccPrompt(0), ccReply(3, "r1", "claude-opus-5-5", "high", "", 300, 1000, "end_turn", false), ccPrompt(50))
	ObserveClaude(cache, p, false, t0.Add(time.Hour))
	if _, err := os.Stat(Path(cache)); !os.IsNotExist(err) {
		t.Fatal("nothing is written when recording is off")
	}
}

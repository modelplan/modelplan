package speed

import (
	"path/filepath"
	"testing"
	"time"
)

const autoReviewCfg = `{"model":"codex-auto-review","effort":"low"}`

// Owner build-6 report 2026-11-27 item #5: Codex's background auto-review thread is never a live session.
func TestAutoReviewIsNotALiveSession(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	review, real := filepath.Join(dir, "review.jsonl"), filepath.Join(dir, "real.jsonl")
	writeLines(t, review, cxTurnLines(1, autoReviewCfg, 5, req{40, 1, 2})...)
	writeLines(t, real, cxTurnLines(1, `{"model":"real-model","effort":"high"}`, 5, req{40, 1, 2})...)
	logs := []LiveLog{{Path: review, Source: "codex"}, {Path: real, Source: "codex"}}
	now := t0.Add(10 * time.Second)
	if err := ObserveLive(cache, logs, false, nil, now); err != nil {
		t.Fatal(err)
	}
	got := view(t, cache, now).LiveSessions()
	if len(got) != 1 || got[0].Model != "real-model" {
		t.Fatalf("only the real session may be listed: %+v", got)
	}
}

func TestAutoReviewIsNotASpeedSampleOrModel(t *testing.T) {
	p := newCodex()
	for _, l := range cxTurnLines(1, autoReviewCfg, 5, req{40, 1, 2}) {
		p.line(0, 0, []byte(l))
	}
	turns, _ := p.finish()
	if len(turns) != 0 {
		t.Fatalf("auto-review turn kept as a speed sample: %+v", turns)
	}
}

// The tokens stay in the Codex total, under no named model.
func TestAutoReviewTokensHaveNoModel(t *testing.T) {
	p := newAccountingParser("codex", "f")
	p.line(0, 0, []byte(cx(0, "session_meta", `{"id":"r","source":"cli"}`)))
	p.line(0, 0, []byte(cx(1, "turn_context", autoReviewCfg)))
	p.line(0, 0, []byte(cx(2, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"output_tokens":2}}}`)))
	p.finish()
	if len(p.records) != 1 || p.records[0].Model != "" {
		t.Fatalf("%+v", p.records)
	}
	if unreviewed("codex-auto-review") != "" || unreviewed("gpt") != "gpt" {
		t.Fatal("records stored before the rule are renamed on read")
	}
}

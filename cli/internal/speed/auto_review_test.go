package speed

import (
	"fmt"
	"path/filepath"
	"slices"
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

// macrevb-1282-2: a live record cached before the auto-review rule is neither published nor kept.
func TestPreUpgradeAutoReviewLiveRecordIsOmitted(t *testing.T) {
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	rec := LiveRecord{Ref: "1111111111111111", Source: "codex", Model: autoReviewModel, Running: true, LastAt: now.Add(-time.Minute)}
	real := LiveRecord{Ref: "2222222222222222", Source: "codex", Model: "real", LastAt: now.Add(-2 * time.Minute)}
	rows := []PerfRow{{Day: now.Format("2006-01-02"), Source: "codex", Model: ""}}
	v := PerfView{OK: true, Recording: true, Now: now, Ledger: PerfLedger{Live: []LiveRecord{rec, real}, Rows: rows}}
	got := v.LiveSessions()
	if len(got) != 1 || got[0].Model != "real" {
		t.Fatalf("%+v", got)
	}
	l := PerfLedger{Live: []LiveRecord{rec, real}, Rows: rows}
	l.pruneLive(now)
	if len(l.Live) != 1 || len(l.Rows) != 1 {
		t.Fatalf("the record is dropped, the Codex row (its total) is kept: %+v", l)
	}
}

// macrevb-1282-3: only the newest LiveIdleMax idle rows show, however recently they finished.
func TestIdleCapAppliesInsideTheLiveWindow(t *testing.T) {
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	var recs []LiveRecord
	for i := 0; i < 7; i++ {
		recs = append(recs, LiveRecord{Ref: fmt.Sprintf("%016d", i), Source: "codex", Model: "m", LastAt: now.Add(-time.Duration(i+1) * time.Second)})
	}
	recs = append(recs, LiveRecord{Ref: "8888888888888888", Source: "codex", Model: "m", Running: true, LastAt: now.Add(-9 * time.Second)})
	for _, shift := range []time.Duration{0, 10 * time.Minute} { // recent, then aged past the live window
		aged := slices.Clone(recs)
		for i := range aged {
			aged[i].LastAt = aged[i].LastAt.Add(-shift)
		}
		got := PerfView{OK: true, Recording: true, Now: now, Ledger: PerfLedger{Live: aged}}.LiveSessions()
		idle, running := 0, 0
		for _, s := range got {
			if s.Status == "running" {
				running++
			} else {
				idle++
			}
		}
		if idle != LiveIdleMax || (shift == 0 && running != 1) {
			t.Fatalf("shift %v: idle %d running %d", shift, idle, running)
		}
	}
}

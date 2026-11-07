package speed

import (
	"testing"
	"time"
)

func i64(n int64) *int64 { return &n }

// historyRows: one synthetic local ledger. Two sources, three models, one row older than both
// windows, and one row whose cache-write sum must stay unknown in the 30-day window.
func historyRows() []PerfRow {
	return []PerfRow{
		{Day: "2026-11-04", Source: "codex", Model: "gpt-5.3", TokenKinds: TokenKinds{InputTokens: i64(1000), CacheReadTokens: i64(4000), CacheWriteTokens: i64(500)},
			ObservedRequests: 10, ObservedOutputTokens: 2000, EligibleRequests: 6, EligibleOutputTokens: 1200, GenMs: 20000},
		{Day: "2026-10-20", Source: "codex", Model: "gpt-5.3", TokenKinds: TokenKinds{InputTokens: i64(500), CacheReadTokens: i64(500)},
			ObservedRequests: 5, ObservedOutputTokens: 1000, EligibleRequests: 5, EligibleOutputTokens: 1000, GenMs: 25000},
		{Day: "2026-11-05", Source: "claude-code", Model: "sonnet", TokenKinds: TokenKinds{InputTokens: i64(200)},
			ObservedRequests: 4, ObservedOutputTokens: 500, EligibleRequests: 4, EligibleOutputTokens: 400, GenMs: 8000},
		{Day: "2026-11-03", Source: "claude-code", Model: "opus", TokenKinds: TokenKinds{InputTokens: i64(100), CacheReadTokens: i64(900), CacheWriteTokens: i64(100)},
			ObservedRequests: 3, ObservedOutputTokens: 300, EligibleRequests: 2, EligibleOutputTokens: 200, GenMs: 10000},
		{Day: "2026-09-15", Source: "codex", Model: "gpt-5.3", TokenKinds: TokenKinds{InputTokens: i64(7), CacheReadTokens: i64(7), CacheWriteTokens: i64(7)},
			ObservedRequests: 1, ObservedOutputTokens: 70},
	}
}

var historyNow = time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)

func historyView(rows []PerfRow) PerfView {
	return PerfView{Ledger: PerfLedger{Since: time.Date(2026, 10, 6, 0, 0, 0, 0, time.UTC), Rows: rows}, OK: true, Recording: true, Now: historyNow}
}

func TestHistoryWindowsSumPerSource(t *testing.T) {
	utc(t)
	out := historyView(historyRows()).HistoryWindows()
	if len(out) != 2 || out[0].Source != "claude-code" || out[1].Source != "codex" {
		t.Fatalf("sources: %+v", out)
	}
	c7, c30 := out[1].Recent7d, out[1].Recent30d
	if *c7.InputTokens != 1000 || *c7.CacheReadTokens != 4000 || *c7.CacheWriteTokens != 500 || c7.ObservedOutputTokens != 2000 ||
		c7.ObservedRequests != 10 || c7.EligibleRequests != 6 || c7.EligibleOutputTokens != 1200 || c7.GenMs != 20000 {
		t.Fatalf("codex 7d: %+v", c7)
	}
	if *c30.InputTokens != 1500 || *c30.CacheReadTokens != 4500 || c30.CacheWriteTokens != nil || c30.ObservedOutputTokens != 3000 ||
		c30.ObservedRequests != 15 || c30.EligibleRequests != 11 || c30.EligibleOutputTokens != 2200 || c30.GenMs != 45000 {
		t.Fatalf("codex 30d keeps the unknown cache write, not zero: %+v", c30)
	}
	l := out[0]
	if *l.Recent7d.InputTokens != 300 || l.Recent7d.CacheReadTokens != nil || l.Recent7d.CacheWriteTokens != nil || l.Recent7d.ObservedOutputTokens != 800 || l.Recent7d.ObservedRequests != 7 {
		t.Fatalf("claude-code windows: %+v", l)
	}
	a, b := l.Recent7d, l.Recent30d
	if *a.InputTokens != *b.InputTokens || a.ObservedOutputTokens != b.ObservedOutputTokens || a.ObservedRequests != b.ObservedRequests ||
		(a.CacheReadTokens == nil) != (b.CacheReadTokens == nil) || (a.CacheWriteTokens == nil) != (b.CacheWriteTokens == nil) {
		t.Fatalf("claude-code 30d should equal its 7d: %+v %+v", a, b)
	}
}

func TestHistoryWindowsWithoutLedger(t *testing.T) {
	utc(t)
	if out := (PerfView{Now: historyNow}).HistoryWindows(); len(out) != 0 {
		t.Fatalf("unreadable ledger produced windows: %+v", out)
	}
}

func TestHistoryRankingsByModelAndTool(t *testing.T) {
	utc(t)
	r := historyView(historyRows()).HistoryRankings(nil)
	if r.Models.Measure != "observed-output-tokens" || r.Models.Attribution != "unattributed" || r.Tools.Measure != "observed-output-tokens" || r.Tools.Attribution != "unattributed" {
		t.Fatalf("measure or attribution: %+v", r)
	}
	w7, w30 := r.Models.Recent7d, r.Models.Recent30d
	if w7.Entities != 3 || w7.TotalObservedOutputTokens != 2800 || len(w7.Top) != 3 {
		t.Fatalf("models 7d: %+v", w7)
	}
	if w7.Top[0].Name != "gpt-5.3" || w7.Top[0].ObservedOutputTokens != 2000 || w7.Top[0].ObservedRequests != 10 || w7.Top[0].Share != 0.714 {
		t.Fatalf("models 7d top: %+v", w7.Top[0])
	}
	if w7.Top[1].Name != "sonnet" || w7.Top[1].Share != 0.179 || w7.Top[2].Name != "opus" || w7.Top[2].Share != 0.107 {
		t.Fatalf("models 7d order: %+v", w7.Top)
	}
	if w30.Entities != 3 || w30.TotalObservedOutputTokens != 3800 || w30.Top[0].ObservedOutputTokens != 3000 || w30.Top[0].Share != 0.789 || w30.Top[1].Share != 0.132 || w30.Top[2].Share != 0.079 {
		t.Fatalf("models 30d: %+v", w30)
	}
	t7, t30 := r.Tools.Recent7d, r.Tools.Recent30d
	if t7.Entities != 2 || t7.TotalObservedOutputTokens != 2800 || t7.Top[0].Name != "codex" || t7.Top[0].Share != 0.714 || t7.Top[1].Name != "claude-code" || t7.Top[1].Share != 0.286 {
		t.Fatalf("tools 7d: %+v", t7)
	}
	if t30.TotalObservedOutputTokens != 3800 || t30.Top[0].ObservedOutputTokens != 3000 || t30.Top[0].Share != 0.789 || t30.Top[1].ObservedOutputTokens != 800 || t30.Top[1].Share != 0.211 {
		t.Fatalf("tools 30d: %+v", t30)
	}
}

func TestHistoryRankingsBoundAndFilter(t *testing.T) {
	utc(t)
	rows := []PerfRow{}
	for i := 0; i < 12; i++ {
		rows = append(rows, PerfRow{Day: "2026-11-05", Source: "codex", Model: string(rune('a'+i)), ObservedRequests: 1, ObservedOutputTokens: int64(i + 1)})
	}
	r := historyView(rows).HistoryRankings(nil)
	if r.Models.Recent7d.Entities != 12 || len(r.Models.Recent7d.Top) != 10 {
		t.Fatalf("bound: %+v", r.Models.Recent7d)
	}
	filtered := historyView(append(rows, PerfRow{Day: "2026-11-05", Source: "claude-code", Model: "sonnet", ObservedRequests: 1, ObservedOutputTokens: 100})).
		HistoryRankings(map[string]bool{"claude-code": true})
	if w := filtered.Models.Recent7d; w.Entities != 1 || w.TotalObservedOutputTokens != 100 || len(w.Top) != 1 || w.Top[0].Name != "sonnet" || w.Top[0].Share != 1 {
		t.Fatalf("unconsented source leaked into rankings: %+v", w)
	}
	if w := filtered.Tools.Recent7d; w.Entities != 1 || w.Top[0].Name != "claude-code" {
		t.Fatalf("tools filter: %+v", w)
	}
}

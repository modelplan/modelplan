// SPDX-License-Identifier: MIT
package main

import (
	"fmt"
	"math"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

func limitsNow(t *testing.T) time.Time {
	t.Helper()
	old := time.Local
	time.Local = time.UTC
	t.Cleanup(func() { time.Local = old })
	return time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC)
}

func dayRow(day, source, model string, input, output int64) speed.PerfRow {
	i := func(n int64) *int64 { return &n }
	return speed.PerfRow{Day: day, Source: source, Model: model, ObservedRequests: 1, ObservedOutputTokens: output,
		TokenKinds: speed.TokenKinds{InputTokens: i(input), CacheReadTokens: i(0), CacheWriteTokens: i(0)}}
}

// macrevd-1050-2 / macrevb-1050-3 / macrev2-1050-3. Invariant: a ranked model carries all of its
// sources, the ranking follows a model's ≈cost over all sources, and no lower-ranked model takes
// the place of one that did not fit.
func TestCostModelCapKeepsWholeModelsInCombinedOrder(t *testing.T) {
	now := limitsNow(t)
	f := func(v float64) *float64 { return &v }
	price := &digest.Price{Input: 1, Output: 1, CacheRead: f(0.1), CacheWrite: f(1), Source: "litellm", AsOf: "2026-11-04"}
	models := []digest.Model{{ID: "split", Price: price}}
	// "split" costs $141.20 over two sources ($70.60 each); 70 single-source models cost $200 down to
	// $131. Ranked by pair, both halves fall below the 64th pair and "split" vanishes.
	rows := []speed.PerfRow{dayRow("2026-11-05", "codex", "split", 70_600_000, 0), dayRow("2026-11-05", "opencode", "split", 70_600_000, 0)}
	for n := 0; n < 70; n++ {
		id := fmt.Sprintf("s%02d", n)
		models = append(models, digest.Model{ID: id, Price: price})
		rows = append(rows, dayRow("2026-11-05", "codex", id, int64(1_000_000*(200-n)), 0))
	}
	c := cockpitCost(speed.PerfView{OK: true, Now: now, Ledger: speed.PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -40), Rows: rows}},
		map[string]bool{"codex": true, "opencode": true}, models, nil, now)
	got := c.Models.Today
	if len(got) != 64 {
		t.Fatalf("rows = %d", len(got))
	}
	// s00…s58 ($200…$142), split's two sources ($141.20), then s59…s61: 64 rows.
	if got[59].Model != "split" || got[60].Model != "split" || got[59].Source == got[60].Source {
		t.Fatalf("split = %+v, %+v", got[59], got[60])
	}
	if got[58].Model != "s58" || got[61].Model != "s59" || got[63].Model != "s61" {
		t.Fatalf("order: %s %s %s", got[58].Model, got[61].Model, got[63].Model)
	}
	// The range total still holds every model: the page's share denominator.
	var day float64
	for _, b := range c.Daily {
		day += b.EstimatedUsd
	}
	if want := 141.2 + float64(70*(200+131)/2); math.Abs(day-want) > 1e-6 {
		t.Fatalf("day total %v, want %v", day, want)
	}
}

// macrev2-1050-5. Invariant: the hourly ≈cost holds at most the last 48 local hours.
func TestCostHoursAreTheLast48(t *testing.T) {
	now := limitsNow(t)
	f := func(v float64) *float64 { return &v }
	models := []digest.Model{{ID: "a", Price: &digest.Price{Input: 1, Output: 1, CacheRead: f(0), CacheWrite: f(0), Source: "litellm", AsOf: "2026-11-04"}}}
	byDay := map[string]*speed.PerfRow{}
	var days []string
	for back := 0; back <= 48; back++ { // 49 hours of responses: the oldest starts exactly 48 hours before now
		at := now.Add(-time.Duration(back) * time.Hour)
		d := at.Format("2006-01-02")
		r := byDay[d]
		if r == nil {
			r = &speed.PerfRow{Day: d, Source: "codex", Model: "a"}
			byDay[d] = r
			days = append(days, d)
		}
		r.ObservedRequests++
		r.Responses = append(r.Responses, speed.Response{At: at, Buckets: tokenacct.Buckets{Input: 1, Output: 1}})
	}
	var usage []speed.PerfRow
	for _, d := range days {
		usage = append(usage, *byDay[d])
	}
	c := cockpitCost(speed.PerfView{OK: true, Now: now, Ledger: speed.PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -40), UsageRows: usage}},
		map[string]bool{"codex": true}, models, nil, now)
	if len(c.Hourly) != 48 {
		t.Fatalf("hours = %d, want 48", len(c.Hourly))
	}
	if first := c.Hourly[0].At; first != now.Add(-47*time.Hour).Format(time.RFC3339) {
		t.Fatalf("oldest hour %s", first)
	}
	var day int64
	for _, b := range c.Daily {
		day += b.PricedTokens
	}
	if day != 49*2 {
		t.Fatalf("days hold %d tokens, want every response once", day)
	}
}

// macrevd-1050-3 / macrev2-1050-6. Invariant: priced use with a positive estimate never reaches
// the page as $0, so the page can say "<$0.01".
func TestTinyPricedUseStaysPositiveOnTheWire(t *testing.T) {
	now := limitsNow(t)
	f := func(v float64) *float64 { return &v }
	i := func(n int64) *int64 { return &n }
	models := []digest.Model{{ID: "tiny", Price: &digest.Price{Input: 1, Output: 1, CacheRead: f(0.1), CacheWrite: f(1), Source: "litellm", AsOf: "2026-11-04"}}}
	row := speed.PerfRow{Day: "2026-11-05", Source: "opencode", Model: "tiny", ObservedRequests: 1, TokenKinds: speed.TokenKinds{InputTokens: i(0), CacheReadTokens: i(1), CacheWriteTokens: i(0)}}
	c := cockpitCost(speed.PerfView{OK: true, Now: now, Ledger: speed.PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -40), Rows: []speed.PerfRow{row}}},
		map[string]bool{"opencode": true}, models, nil, now)
	if len(c.Daily) != 1 || c.Daily[0].PricedTokens != 1 || !(c.Daily[0].EstimatedUsd > 0) {
		t.Fatalf("day: %+v", c.Daily)
	}
	if m := c.Models.Today; len(m) != 1 || m[0].EstimatedUsd == nil || !(*m[0].EstimatedUsd > 0) {
		t.Fatalf("model: %+v", m)
	}
}

// macrevb-1050-3. Invariant: rounding on the wire keeps every estimate's ratio to the others, so
// shares of tiny charges stay true (and positive charges stay positive).
func TestTinyChargesKeepTheirRatio(t *testing.T) {
	now := limitsNow(t)
	f := func(v float64) *float64 { return &v }
	i := func(n int64) *int64 { return &n }
	models := []digest.Model{
		{ID: "a", Price: &digest.Price{Input: 1, Output: 1, CacheRead: f(0.1), CacheWrite: f(1), Source: "litellm", AsOf: "2026-11-04"}},
		{ID: "b", Price: &digest.Price{Input: 1, Output: 1, CacheRead: f(0.4), CacheWrite: f(1), Source: "litellm", AsOf: "2026-11-04"}},
	}
	read := func(model string) speed.PerfRow {
		return speed.PerfRow{Day: "2026-11-05", Source: "opencode", Model: model, ObservedRequests: 1, TokenKinds: speed.TokenKinds{InputTokens: i(0), CacheReadTokens: i(1), CacheWriteTokens: i(0)}}
	}
	c := cockpitCost(speed.PerfView{OK: true, Now: now, Ledger: speed.PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -40), Rows: []speed.PerfRow{read("a"), read("b")}}},
		map[string]bool{"opencode": true}, models, nil, now)
	m := c.Models.Today
	if len(m) != 2 || m[0].Model != "b" || m[1].Model != "a" {
		t.Fatalf("order: %+v", m)
	}
	total := c.Daily[0].EstimatedUsd
	if share := *m[0].EstimatedUsd / total; math.Abs(share-0.8) > 1e-6 {
		t.Fatalf("b's share = %v of %v, want 0.8", share, total)
	}
	if share := *m[1].EstimatedUsd / total; math.Abs(share-0.2) > 1e-6 {
		t.Fatalf("a's share = %v of %v, want 0.2", share, total)
	}
}

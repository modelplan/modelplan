// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

// fakePricer: $1 per input-side token and $10 per output token below the threshold, ten
// times that above it; the tier multiplies. Prices only the models it names.
type fakePricer struct {
	threshold int64
	models    map[string]bool
	tiers     map[string]float64
	calls     []tokenacct.Buckets
}

func (p *fakePricer) Request(source, model, tier string, b tokenacct.Buckets) (float64, bool) {
	p.calls = append(p.calls, b)
	m, ok := p.tiers[tier]
	if !p.models[model] || !ok {
		return 0, false
	}
	scale := 1.0
	if b.Input+b.CacheRead+b.CacheWrite > p.threshold {
		scale = 10
	}
	return m * scale * float64(b.Input+b.CacheRead+b.CacheWrite+10*(b.Output+b.Reasoning)), true
}
func (p *fakePricer) Aggregate(source, model string, b tokenacct.Buckets) (float64, bool, bool) {
	if !p.models[model] {
		return 0, false, false
	}
	return float64(b.Input + b.CacheRead + b.CacheWrite + 10*(b.Output+b.Reasoning)), true, true
}

// WP-06 / COST-51: the long-context rate is chosen per response, never from a day's sum.
// The Codex fixture's two responses carry 1000 and 2000 input tokens; with a 1500 threshold
// only the second is long, and the day total (3000) must not make the first one long.
func TestCostsPricePerResponse(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	seedPerf(t, cache, now.Add(-12*time.Hour))
	observeCx(t, cache, now, filepath.Join("testdata", "accounting", "sessions", "2026", "11", "16", "rollout-redacted.jsonl"))
	p := &fakePricer{threshold: 1500, models: map[string]bool{"gpt-5.2": true}, tiers: map[string]float64{"": 1}}
	rows := view(t, cache, now).Costs(p)
	if len(p.calls) != 2 {
		t.Fatalf("priced %d requests, want one call per response: %+v", len(p.calls), p.calls)
	}
	if len(rows) != 1 {
		t.Fatalf("rows = %+v", rows)
	}
	r := rows[0]
	// first: 100+900 + 10*10 = 1100; second (long): 10*(200+1800 + 10*20) = 22000
	if r.USD != 23100 || r.PricedTokens != 3030 || r.UnpricedTokens != 0 || r.Approximate {
		t.Fatalf("row = %+v", r)
	}
	if r.Day != "2026-11-16" || r.Hour != "2026-11-16T10:00:00Z" || r.Source != "codex" || r.Model != "gpt-5.2" {
		t.Fatalf("row keys = %+v", r)
	}
}

// COST-52: usage of a model without a price counts as unpriced tokens, not as cost.
func TestCostsKeepUnpricedTokens(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	cache := t.TempDir()
	seedPerf(t, cache, now.Add(-12*time.Hour))
	observeCx(t, cache, now, filepath.Join("testdata", "accounting", "sessions", "2026", "11", "16", "rollout-redacted.jsonl"))
	rows := view(t, cache, now).Costs(&fakePricer{models: map[string]bool{}, tiers: map[string]float64{"": 1}})
	if len(rows) != 1 || rows[0].USD != 0 || rows[0].PricedTokens != 0 || rows[0].UnpricedTokens != 3030 {
		t.Fatalf("rows = %+v", rows)
	}
}

// A fast-mode response uses the published API multiplier; without one it stays unpriced.
func TestCostsApplyTheRecordedSpeedTier(t *testing.T) {
	utc(t)
	grantLocalHistory(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	src, err := os.ReadFile(filepath.Join("testdata", "accounting", "claude", "projects", "redacted", "session.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSpace(string(src)), "\n")
	// The second response ran in fast mode.
	lines[2] = strings.Replace(lines[2], `"output_tokens":20}`, `"output_tokens":20,"speed":"fast"}`, 1)
	path := filepath.Join(t.TempDir(), "session.jsonl")
	if err := os.WriteFile(path, []byte(strings.Join(lines, "\n")+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct {
		name           string
		tiers          map[string]float64
		usd            float64
		priced, unpric int64
	}{
		// first: 100+900+20 + 10*10 = 1120; second: 2*(200+1800+40 + 10*20) = 4480
		{"published", map[string]float64{"": 1, "fast": 2}, 1120 + 4480, 1030, 2060},
		{"unpublished", map[string]float64{"": 1}, 1120, 1030, 0},
	} {
		cache := t.TempDir()
		if err := ObserveClaude(cache, path, false, Ingest{}, now); err != nil {
			t.Fatal(err)
		}
		rows := view(t, cache, now).Costs(&fakePricer{threshold: 1 << 40, models: map[string]bool{"claude-sonnet-4-5-20250929": true}, tiers: c.tiers})
		if len(rows) != 1 {
			t.Fatalf("%s: rows = %+v", c.name, rows)
		}
		r := rows[0]
		if c.name == "published" && (r.USD != c.usd || r.PricedTokens != 3090 || r.UnpricedTokens != 0) {
			t.Fatalf("%s: %+v", c.name, r)
		}
		if c.name == "unpublished" && (r.USD != c.usd || r.PricedTokens != 1030 || r.UnpricedTokens != 2060) {
			t.Fatalf("%s: %+v", c.name, r)
		}
	}
}

func TestCodexServiceTierFollowsThreadSettings(t *testing.T) {
	p := newAccountingParser("codex", "f")
	for _, line := range []string{
		`{"timestamp":"2026-11-16T10:00:00Z","type":"session_meta","payload":{"id":"s"}}`,
		`{"timestamp":"2026-11-16T10:00:01Z","type":"turn_context","payload":{"model":"gpt-6-sol"}}`,
		`{"timestamp":"2026-11-16T10:00:01Z","type":"event_msg","payload":{"type":"thread_settings_applied","thread_settings":{"service_tier":"priority"}}}`,
		`{"timestamp":"2026-11-16T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":10,"output_tokens":1}}}}`,
		`{"timestamp":"2026-11-16T10:00:03Z","type":"event_msg","payload":{"type":"thread_settings_applied","thread_settings":{}}}`,
		`{"timestamp":"2026-11-16T10:00:04Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":20,"output_tokens":2}}}}`,
		`{"timestamp":"2026-11-16T10:00:05Z","type":"event_msg","payload":{"type":"thread_settings_applied","thread_settings":{"service_tier":"default"}}}`,
		`{"timestamp":"2026-11-16T10:00:06Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":30,"output_tokens":3}}}}`,
		`{"timestamp":"2026-11-16T10:00:07Z","type":"event_msg","payload":{"type":"thread_settings_applied","thread_settings":{"service_tier":"turbo"}}}`,
		`{"timestamp":"2026-11-16T10:00:08Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":40,"output_tokens":4}}}}`,
	} {
		p.line(0, 0, []byte(line))
	}
	var tiers []string
	for _, r := range p.records {
		tiers = append(tiers, r.Tier)
	}
	if strings.Join(tiers, ",") != "fast,fast,,unknown" {
		t.Fatalf("tiers = %q", tiers)
	}
}

// Rows from tools that log only day totals are priced by their totals and marked
// approximate when the model has a long-context price; a row missing a token kind is unpriced.
func TestCostsForDayTotalRows(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	n := func(v int64) *int64 { return &v }
	rows := []PerfRow{
		{Day: "2026-11-16", Source: "opencode", Model: "glm", ObservedRequests: 1, ObservedOutputTokens: 5, TokenKinds: TokenKinds{InputTokens: n(10), CacheReadTokens: n(0), CacheWriteTokens: n(0)}},
		{Day: "2026-11-15", Source: "zcode", Model: "glm", ObservedRequests: 1, ObservedOutputTokens: 7},
		{Day: "2026-10-01", Source: "opencode", Model: "glm", ObservedRequests: 1, ObservedOutputTokens: 9, TokenKinds: TokenKinds{InputTokens: n(1), CacheReadTokens: n(0), CacheWriteTokens: n(0)}},
	}
	v := PerfView{Ledger: PerfLedger{SchemaVersion: 1, Since: now.Add(-60 * 24 * time.Hour), Rows: rows}, OK: true, Recording: true, Now: now}
	got := v.Costs(&fakePricer{models: map[string]bool{"glm": true}})
	if len(got) != 2 {
		t.Fatalf("rows = %+v", got)
	}
	if r := got[0]; r.Day != "2026-11-15" || r.UnpricedTokens != 7 || r.PricedTokens != 0 {
		t.Fatalf("incomplete kinds priced: %+v", r)
	}
	if r := got[1]; r.Day != "2026-11-16" || r.Hour != "" || r.USD != 60 || r.PricedTokens != 15 || !r.Approximate {
		t.Fatalf("day total: %+v", r)
	}
}

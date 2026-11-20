// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"math"
	"os"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// The production-shaped client-v1.6 projection the digest and JS reader tests share, and the
// cockpit history this test derives from it. desktop/tests/cockpit/unit/estimated-cost-v16.test.mjs
// feeds that history to the page's cost cells, so the two tests together run one publication
// end to end: CLI digest → app-cli wire → cockpit cells. Regenerate with UPDATE_COST_V16=1.
const (
	v16Publication = "../../../testdata/client-v1.6/example.json"
	v16History     = "../../../testdata/client-v1.6/cockpit-history.json"
)

func TestClientV16PublicationPricesTheCockpitHistory(t *testing.T) {
	raw, err := os.ReadFile(v16Publication)
	if err != nil {
		t.Fatal(err)
	}
	envelope, err := json.Marshal(map[string]any{"schemaVersion": 1, "kind": "client", "data": json.RawMessage(raw)})
	if err != nil {
		t.Fatal(err)
	}
	pub, err := digest.Parse("client", envelope)
	if err != nil {
		t.Fatalf("the v1.6 publication was rejected: %v", err)
	}
	if pub.PriceUnit != digest.PriceUnitUSDPer1M || pub.Model("astra-6.2").Evaluation != digest.EvaluationPending {
		t.Fatalf("v1.6 fields: unit %q, astra-6.2 evaluation %q", pub.PriceUnit, pub.Model("astra-6.2").Evaluation)
	}

	oldLocal, oldNow := time.Local, cockpitHistoryNow
	time.Local, cockpitHistoryNow = time.UTC, func() time.Time { return time.Date(2026, 11, 5, 12, 0, 0, 0, time.UTC) }
	t.Cleanup(func() { time.Local, cockpitHistoryNow = oldLocal, oldNow })
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	now := cockpitHistoryNow()
	day := func(n int) string { return now.AddDate(0, 0, -n).Format("2006-01-02") }
	i := func(n int64) *int64 { return &n }
	epoch := &speed.GrantEpoch{StoreEpoch: state.StoreEpoch}
	cache := t.TempDir()
	// Day totals in vendor model IDs, as the readers record them.
	writeHistoryLedger(t, cache, speed.PerfLedger{SchemaVersion: 1, Since: now.AddDate(0, 0, -30), Rows: []speed.PerfRow{
		// sol-6.1 (2/10/0.1/2.5, long-context price): 2 + 0.2 + 1 = $3.20, approximate.
		{GrantEpoch: epoch, Day: day(0), Source: "codex", Model: "gpt-6.1-sol",
			TokenKinds:       speed.TokenKinds{InputTokens: i(1_000_000), CacheReadTokens: i(2_000_000), CacheWriteTokens: i(0)},
			ObservedRequests: 40, ObservedOutputTokens: 100_000, EligibleRequests: 40, EligibleOutputTokens: 100_000, GenMs: 400_000},
		// An unpublished local model: counted in tokens only.
		{GrantEpoch: epoch, Day: day(0), Source: "codex", Model: "local-llama",
			TokenKinds:       speed.TokenKinds{InputTokens: i(500), CacheReadTokens: i(0), CacheWriteTokens: i(0)},
			ObservedRequests: 1, ObservedOutputTokens: 500, EligibleRequests: 1, EligibleOutputTokens: 500, GenMs: 5_000},
		// astra-6.2 is a pending (unscored) row that still carries a public price: 0.8 + 0.4 = $1.20, approximate.
		{GrantEpoch: epoch, Day: day(1), Source: "codex", Model: "gpt-6.2-astra",
			TokenKinds:       speed.TokenKinds{InputTokens: i(100_000), CacheReadTokens: i(0), CacheWriteTokens: i(0)},
			ObservedRequests: 5, ObservedOutputTokens: 10_000, EligibleRequests: 5, EligibleOutputTokens: 10_000, GenMs: 50_000},
		// opus (4/20/0.2/5, no long-context price): 0.04 + 0.2 + 0.5 + 1 = $1.74, exact.
		{GrantEpoch: epoch, Day: day(2), Source: "claude-code", Model: "claude-opus-5-5",
			TokenKinds:       speed.TokenKinds{InputTokens: i(10_000), CacheReadTokens: i(1_000_000), CacheWriteTokens: i(100_000)},
			ObservedRequests: 12, ObservedOutputTokens: 50_000, EligibleRequests: 12, EligibleOutputTokens: 50_000, GenMs: 200_000},
	}})
	refA, refB := "0123456789abcdef", "fedcba9876543210"
	view := appserver.View{PublicModels: pub.Models, PublicSpeedTiers: pub.Speed, QuotaReport: quota.Report{Accounts: []quota.Account{
		{Source: "codex", Subscription: &quota.Binding{Ref: refA, Status: "verified", ObservedAt: now.Add(-30 * time.Minute)}},
		{Source: "claude-code", Subscription: &quota.Binding{Ref: refB, Status: "verified", ObservedAt: now.Add(-30 * time.Minute)}},
	}}}
	admission := queries.CockpitAdmission{Stamp: appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}, Scopes: []string{consent.ScopeClaudeLocalHistory, consent.ScopeCodexLocalHistory}}
	history, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, admission, map[string][]wire.CockpitAccount{refA: {}, refB: {}})
	if err != nil {
		t.Fatal(err)
	}

	c := history.Cost
	if c == nil || c.PricesAsOf == nil || *c.PricesAsOf != "2026-11-19" {
		t.Fatalf("cost header: %+v", c)
	}
	byDay := map[string]wire.CockpitCostBucket{}
	for _, b := range c.Daily {
		byDay[b.At+"/"+b.Source] = b
	}
	near := func(a, b float64) bool { return math.Abs(a-b) < 1e-9 }
	if b := byDay[day(0)+"/codex"]; !near(b.EstimatedUsd, 3.2) || b.PricedTokens != 3_100_000 || b.UnpricedTokens != 1000 || !b.Approximate {
		t.Fatalf("codex today: %+v", b)
	}
	if b := byDay[day(1)+"/codex"]; !near(b.EstimatedUsd, 1.2) || !b.Approximate {
		t.Fatalf("pending astra-6.2: %+v", b)
	}
	if b := byDay[day(2)+"/claude-code"]; !near(b.EstimatedUsd, 1.74) || b.PricedTokens != 1_160_000 || b.Approximate {
		t.Fatalf("opus: %+v", b)
	}
	if r := c.Models.Recent7d; len(r) != 4 || r[0].Model != "sol-6.1" || r[1].Model != "opus" || r[2].Model != "astra-6.2" || r[3].Model != "unknown" || r[3].EstimatedUsd != nil {
		t.Fatalf("7d ranking: %+v", r)
	}

	got, err := json.MarshalIndent(history, "", " ")
	if err != nil {
		t.Fatal(err)
	}
	got = append(got, '\n')
	if os.Getenv("UPDATE_COST_V16") == "1" {
		if err := os.WriteFile(v16History, got, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile(v16History)
	if err != nil || !bytes.Equal(got, want) {
		t.Fatalf("%s drifted from the cockpit history; regenerate with UPDATE_COST_V16=1 (%v)", v16History, err)
	}
}

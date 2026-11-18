// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"math"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

func pricedModels() []digest.Model {
	f := func(v float64) *float64 { return &v }
	return []digest.Model{
		{ID: "gpt-5.3", Price: &digest.Price{Input: 1, Output: 10, CacheRead: f(0.1), CacheWrite: f(1.25), Source: "litellm", AsOf: "2026-11-04"}},
		{ID: "sonnet"},
		{ID: "opus", Price: &digest.Price{Input: 5, Output: 25, CacheRead: f(0.5), CacheWrite: f(6.25), Source: "litellm", AsOf: "2026-11-05",
			LongContext: &digest.LongContextPrice{AboveInputTokens: 200000, Input: 10, Output: 37.5, CacheRead: f(1), CacheWrite: f(12.5)}}},
	}
}

func historyWithModels(t *testing.T, models []digest.Model) wire.CockpitHistory {
	t.Helper()
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
	cache := t.TempDir()
	writeHistoryLedger(t, cache, historyLedger(t, state.StoreEpoch, now))
	refA, refB := "0123456789abcdef", "fedcba9876543210"
	view := appserver.View{PublicModels: models, QuotaReport: quota.Report{Accounts: []quota.Account{
		{Source: "codex", Subscription: &quota.Binding{Ref: refA, Status: "verified", ObservedAt: now.Add(-30 * time.Minute)}},
		{Source: "claude-code", Subscription: &quota.Binding{Ref: refB, Status: "verified", ObservedAt: now.Add(-30 * time.Minute)}},
	}}}
	admission := queries.CockpitAdmission{Stamp: appserver.Stamp{Epoch: state.StoreEpoch, Generation: state.Generation}, Scopes: []string{consent.ScopeClaudeLocalHistory, consent.ScopeCodexLocalHistory}}
	data, err := (sharedCockpit{cache: cache}).cockpitHistory(context.Background(), view, admission, map[string][]wire.CockpitAccount{refA: {}, refB: {}})
	if err != nil {
		t.Fatal(err)
	}
	return data
}

// WP-06 / COST-52, COST-53: one delivery carries ≈cost per day and per model for all three
// ranges; usage without a price is counted in tokens, never in ≈cost.
func TestCockpitHistoryCarriesEstimatedCost(t *testing.T) {
	c := historyWithModels(t, pricedModels()).Cost
	if c == nil {
		t.Fatal("no ≈cost section although the publication carries prices")
	}
	if c.Basis != "api-list-price" || c.Currency != "USD" || c.PricesAsOf == nil || *c.PricesAsOf != "2026-11-05" {
		t.Fatalf("header: %+v", c)
	}
	byDay := map[string]wire.CockpitCostBucket{}
	for _, b := range c.Daily {
		byDay[b.At+"/"+b.Source] = b
	}
	// gpt-5.3 yesterday: 1000×1 + 4000×0.1 + 500×1.25 + 2000×10 = 22025 µ$
	if b := byDay["2026-11-04/codex"]; b.EstimatedUsd != 0.022025 || b.PricedTokens != 7500 || b.UnpricedTokens != 0 || b.Approximate {
		t.Fatalf("codex yesterday: %+v", b)
	}
	// gpt-5.3 16 days ago lacks a cache-write count: unpriced, its known tokens still counted.
	if b := byDay["2026-10-20/codex"]; b.EstimatedUsd != 0 || b.PricedTokens != 0 || b.UnpricedTokens != 2000 {
		t.Fatalf("codex 16 days ago: %+v", b)
	}
	// opus from day totals, with a long-context price: priced and marked approximate.
	if b := byDay["2026-11-03/claude-code"]; b.EstimatedUsd != 0.009075 || b.PricedTokens != 1400 || !b.Approximate {
		t.Fatalf("opus: %+v", b)
	}
	// sonnet has no public price.
	if b := byDay["2026-11-05/claude-code"]; b.EstimatedUsd != 0 || b.UnpricedTokens != 700 {
		t.Fatalf("sonnet: %+v", b)
	}
	if len(c.Models.Today) != 1 || c.Models.Today[0].Model != "sonnet" || c.Models.Today[0].EstimatedUsd != nil || c.Models.Today[0].UnpricedTokens != 700 {
		t.Fatalf("today models: %+v", c.Models.Today)
	}
	if len(c.Models.Recent7d) != 3 || c.Models.Recent7d[0].Model != "gpt-5.3" || c.Models.Recent7d[1].Model != "opus" || c.Models.Recent7d[2].Model != "sonnet" {
		t.Fatalf("7d ranking by ≈cost: %+v", c.Models.Recent7d)
	}
	if m := c.Models.Recent30d[0]; m.Model != "gpt-5.3" || *m.EstimatedUsd != 0.022025 || m.UnpricedTokens != 2000 {
		t.Fatalf("30d gpt-5.3: %+v", m)
	}
	if len(c.Hourly) != 0 {
		t.Fatalf("day totals invented hours: %+v", c.Hourly)
	}
	b, _ := json.Marshal(c)
	if strings.Contains(string(b), "NaN") || strings.Contains(string(b), `"estimatedUsd":0,"pricedTokens":0,"unpricedTokens":0`) {
		t.Fatalf("wire: %s", b)
	}
}

// COST-50: without client-v1.6 prices there is no ≈cost section at all, not a zero.
func TestCockpitHistoryWithoutPricesHasNoCost(t *testing.T) {
	data := historyWithModels(t, []digest.Model{{ID: "gpt-5.3"}, {ID: "sonnet"}, {ID: "opus"}})
	if data.Cost != nil {
		t.Fatalf("cost without prices: %+v", data.Cost)
	}
	b, _ := json.Marshal(data)
	if strings.Contains(string(b), `"cost"`) {
		t.Fatalf("wire carries cost: %s", b)
	}
}

func TestPublicationPricerUsesOnlyPublishedFastMultipliers(t *testing.T) {
	sonnet := "sonnet"
	m := 6.0
	tiers := []digest.SpeedTier{{ID: "claude-fast", Harness: "claude-code", Tier: "fast", Models: []digest.SpeedTierModel{{VendorModelID: "claude-opus", ModelID: &sonnet}}, APIPriceMultiplier: &m}}
	f := func(v float64) *float64 { return &v }
	models := []digest.Model{{ID: "sonnet", HarnessIDs: map[string][]string{"claude-code": {"claude-sonnet-x"}}, Price: &digest.Price{Input: 3, Output: 15, CacheRead: f(0.3), CacheWrite: f(3.75), Source: "litellm", AsOf: "2026-11-05"}}}
	p := newPublicationPricer(models, tiers)
	b := tokenacct.Buckets{Input: 1000, Output: 100}
	std, ok := p.Request("claude-code", "claude-sonnet-x", "", b)
	if !ok || math.Abs(std-0.0045) > 1e-12 {
		t.Fatalf("standard = %v %v", std, ok)
	}
	fast, ok := p.Request("claude-code", "claude-sonnet-x", "fast", b)
	if !ok || fast != std*6 {
		t.Fatalf("fast = %v %v", fast, ok)
	}
	if _, ok := p.Request("codex", "claude-sonnet-x", "", b); ok {
		t.Fatal("an alias of another harness was priced")
	}
	if _, ok := p.Request("claude-code", "claude-sonnet-x", "ultrafast", b); ok {
		t.Fatal("a tier without a published multiplier was priced")
	}
	if _, ok := p.Request("claude-code", "claude-sonnet-x", "unknown", b); ok {
		t.Fatal("an unknown tier was priced as standard")
	}
}

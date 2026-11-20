// SPDX-License-Identifier: MIT
package cost

import (
	"math"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

func f(v float64) *float64 { return &v }

func near(t *testing.T, name string, got, want float64) {
	t.Helper()
	// COST-51: within 1% of ccusage on the same price fixture (these are exact).
	if math.Abs(got-want) > want*0.01 || math.Abs(got-want) > 1e-9 && want == 0 {
		t.Fatalf("%s = %.12f, want %.12f", name, got, want)
	}
}

// Fixture and expected values from ccusage@58866ba6 rust/crates/ccusage-core/src/cost.rs
// prices_two_stage_model_as_whole_request_at_long_context_rates (models.dev units, USD per
// million tokens; context tier size 100).
var twoStage = &digest.Price{Input: 1, Output: 10, CacheRead: f(0.1), Source: "modelsdev", AsOf: "2026-11-18",
	LongContext: &digest.LongContextPrice{AboveInputTokens: 100, Input: 2, Output: 20, CacheRead: f(0.2)}}

func TestRequestMatchesCcusageTwoStagePricing(t *testing.T) {
	for _, c := range []struct {
		name  string
		input int64
		want  float64
	}{{"short", 59, 93e-6}, {"boundary", 60, 94e-6}, {"long", 61, 190e-6}} {
		got, ok := Request(twoStage, tokenacct.Buckets{Input: c.input, Output: 3, CacheRead: 40}, 1)
		if !ok {
			t.Fatalf("%s: unpriced", c.name)
		}
		near(t, c.name, got, c.want)
	}
}

// ccusage cached_context_selects_the_long_context_tier (grok-4.5: $2/$6, cache read $0.3;
// above 200K context $4/$12/$0.6): the tier follows the whole context, cached included.
func TestCachedContextSelectsTheLongContextTier(t *testing.T) {
	grok := &digest.Price{Input: 2, Output: 6, CacheRead: f(0.3), Source: "litellm", AsOf: "2026-11-18",
		LongContext: &digest.LongContextPrice{AboveInputTokens: 200000, Input: 4, Output: 12, CacheRead: f(0.6)}}
	got, _ := Request(grok, tokenacct.Buckets{Input: 10000, Output: 1000, CacheRead: 500000}, 1)
	near(t, "cached-heavy", got, 0.352)
	got, _ = Request(grok, tokenacct.Buckets{Input: 10000, Output: 1000, CacheRead: 100000}, 1)
	near(t, "short", got, 0.056)
}

// Codex logs reasoning inside output; the accounting splits it out (TOK-50). It is billed
// as output, so splitting changes no estimate.
func TestReasoningIsBilledAsOutput(t *testing.T) {
	p := &digest.Price{Input: 1.25, Output: 10, CacheRead: f(0.125), Source: "litellm", AsOf: "2026-11-18"}
	split, _ := Request(p, tokenacct.Buckets{Input: 1000, CacheRead: 9000, Output: 200, Reasoning: 300}, 1)
	whole, _ := Request(p, tokenacct.Buckets{Input: 1000, CacheRead: 9000, Output: 500}, 1)
	near(t, "split", split, whole)
	near(t, "whole", whole, (1000*1.25+9000*0.125+500*10)*1e-6)
}

// ccusage multiplies a fast-mode request by the model's published fast multiplier.
func TestFastMultiplierScalesTheWholeRequest(t *testing.T) {
	p := &digest.Price{Input: 5, Output: 25, CacheRead: f(0.5), CacheWrite: f(6.25), Source: "litellm", AsOf: "2026-11-19"}
	b := tokenacct.Buckets{Input: 10, CacheRead: 1000, CacheWrite: 100, Output: 50}
	standard, _ := Request(p, b, 1)
	fast, ok := Request(p, b, 6)
	if !ok {
		t.Fatal("fast request unpriced")
	}
	near(t, "fast", fast, standard*6)
	if _, ok := Request(p, b, 0); ok {
		t.Fatal("a missing multiplier was treated as a price")
	}
}

// COST-52: no guess. Tokens in a bucket the publication has no rate for leave the request
// unpriced; a model with no price is unpriced.
func TestUnknownRateLeavesTheRequestUnpriced(t *testing.T) {
	noWrite := &digest.Price{Input: 1.25, Output: 10, CacheRead: f(0.125), Source: "modelsdev", AsOf: "2026-11-18"}
	if _, ok := Request(noWrite, tokenacct.Buckets{Input: 10, CacheWrite: 5, Output: 1}, 1); ok {
		t.Fatal("cache write priced without a cache-write rate")
	}
	if _, ok := Request(noWrite, tokenacct.Buckets{Input: 10, Output: 1}, 1); !ok {
		t.Fatal("a request without cache writes needs no cache-write rate")
	}
	if _, ok := Request(nil, tokenacct.Buckets{Input: 10}, 1); ok {
		t.Fatal("a model without a price was priced")
	}
	// The long-context tier has no cache-read rate: never fall back to the short rate.
	partial := &digest.Price{Input: 1, Output: 10, CacheRead: f(0.1), Source: "litellm", AsOf: "2026-11-18",
		LongContext: &digest.LongContextPrice{AboveInputTokens: 100, Input: 2, Output: 20}}
	if _, ok := Request(partial, tokenacct.Buckets{Input: 61, Output: 3, CacheRead: 40}, 1); ok {
		t.Fatal("long-context cache read priced at the short rate")
	}
}

func TestAggregateIsApproximateOnlyWithALongContextPrice(t *testing.T) {
	b := tokenacct.Buckets{Input: 59, Output: 3, CacheRead: 40}
	usd, ok, approximate := Aggregate(twoStage, b)
	if !ok || !approximate {
		t.Fatalf("ok=%v approximate=%v", ok, approximate)
	}
	near(t, "aggregate", usd, 93e-6)
	flat := &digest.Price{Input: 1, Output: 10, CacheRead: f(0.1), Source: "litellm", AsOf: "2026-11-18"}
	if _, ok, approximate := Aggregate(flat, b); !ok || approximate {
		t.Fatalf("flat: ok=%v approximate=%v", ok, approximate)
	}
}

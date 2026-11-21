// SPDX-License-Identifier: MIT

// Package cost turns counted tokens into ≈cost: tokens used × the model's public API list
// price (D291). It is an estimate of what the same use would cost at API list prices, not
// what a subscriber pays. Everything is computed on this device; nothing is sent anywhere.
//
// The rules follow ccusage@58866ba681343634ab6e5add61f18f3b70aa98f7
// rust/crates/ccusage-core/src/cost.rs calculate_cost_from_pricing (two-stage branch, MIT):
// a request whose input (uncached + cache read + cache write) exceeds the long-context
// threshold is billed entirely at the long-context rates; a fast-mode request multiplies the
// whole request. Unlike ccusage, a rate the publication does not carry is never borrowed from
// another rate: such a request stays unpriced.
package cost

import (
	"math"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

const perToken = 1e-6 // prices are USD per million tokens

// Request prices one response. Reasoning is billed as output, as the makers bill it.
// multiplier is the published API price multiple of the request's speed tier; 1 for
// standard. ok is false when the model has no price, or a bucket with tokens has no rate.
func Request(p *digest.Price, b tokenacct.Buckets, multiplier float64) (usd float64, ok bool) {
	if p == nil || !(multiplier > 0) || math.IsInf(multiplier, 0) {
		return 0, false
	}
	input, output, read, write := p.Input, p.Output, p.CacheRead, p.CacheWrite
	if lc := p.LongContext; lc != nil && inputSize(b) > lc.AboveInputTokens {
		input, output, read, write = lc.Input, lc.Output, lc.CacheRead, lc.CacheWrite
	}
	usd, ok = price(b, input, output, read, write)
	return usd * multiplier, ok
}

// Aggregate prices buckets summed over several requests whose individual input sizes are
// not known (tools that log only totals). Short-context rates apply; approximate is true
// when the model also has a long-context price, so the page keeps "≈" and says why.
func Aggregate(p *digest.Price, b tokenacct.Buckets) (usd float64, ok, approximate bool) {
	if p == nil {
		return 0, false, false
	}
	usd, ok = price(b, p.Input, p.Output, p.CacheRead, p.CacheWrite)
	return usd, ok, ok && p.LongContext != nil
}

// inputSize is the request's whole input: the tier is chosen by it, cached or not.
func inputSize(b tokenacct.Buckets) int64 {
	return sat(sat(max(0, b.Input), max(0, b.CacheRead)), max(0, b.CacheWrite))
}

func price(b tokenacct.Buckets, input, output float64, read, write *float64) (float64, bool) {
	usd := float64(max(0, b.Input))*input + float64(sat(max(0, b.Output), max(0, b.Reasoning)))*output
	for _, part := range []struct {
		tokens int64
		rate   *float64
	}{{b.CacheRead, read}, {b.CacheWrite, write}} {
		if part.tokens <= 0 {
			continue
		}
		if part.rate == nil {
			return 0, false
		}
		usd += float64(part.tokens) * *part.rate
	}
	return usd * perToken, true
}

func sat(a, b int64) int64 {
	if b > 0 && a > math.MaxInt64-b {
		return math.MaxInt64
	}
	return a + b
}

// SPDX-License-Identifier: MIT
package speed

import (
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

// Response is one counted response on a response-accounting row (accounting.go).
type Response struct {
	At   time.Time
	Tier string
	tokenacct.Buckets
}

// Pricer prices one source's use of one model (WP-06, D291). Request prices a single
// response; Aggregate prices a sum of responses whose individual input sizes are unknown.
// ok false means unpriced: the tokens count, the estimate does not.
type Pricer interface {
	Request(source, model, tier string, b tokenacct.Buckets) (usd float64, ok bool)
	Aggregate(source, model string, b tokenacct.Buckets) (usd float64, ok, approximate bool)
}

// CostRow is ≈cost for one source and model in one local hour, or one local day when the
// tool's records carry only day totals (Hour ""). Tokens are the five-bucket total.
type CostRow struct {
	Day            string
	Hour           string // local top of the hour, RFC 3339; "" when only the day is known
	Source         string
	Model          string
	Origin         string // "" live | import
	USD            float64
	PricedTokens   int64
	UnpricedTokens int64
	// Approximate: some priced tokens came from day totals of a model that has a
	// long-context price, so the long-context rate could not be applied per request.
	Approximate bool
}

// Costs prices the usage view over the last 30 local days. Response-accounting rows are
// priced per response; other rows by their day totals. Usage without a price stays in
// UnpricedTokens. Nothing is stored.
func (v PerfView) Costs(p Pricer) []CostRow {
	if !v.OK || p == nil {
		return []CostRow{}
	}
	v = v.accounted()
	from, today := windowFrom(v.Now, 30), day(v.Now)
	type key struct{ day, hour, source, model, origin string }
	sums := map[key]*CostRow{}
	add := func(k key, usd float64, tokens int64, priced, approximate bool) {
		if tokens <= 0 {
			return
		}
		r := sums[k]
		if r == nil {
			r = &CostRow{Day: k.day, Hour: k.hour, Source: k.source, Model: k.model, Origin: k.origin}
			sums[k] = r
		}
		if priced {
			r.USD += usd
			r.PricedTokens = sat(r.PricedTokens, tokens)
			r.Approximate = r.Approximate || approximate
		} else {
			r.UnpricedTokens = sat(r.UnpricedTokens, tokens)
		}
	}
	for i := range v.Ledger.Rows {
		r := &v.Ledger.Rows[i]
		if r.Day < from || r.Day > today {
			continue
		}
		if len(r.Responses) != 0 {
			for _, q := range r.Responses {
				if q.At.After(v.Now) {
					continue
				}
				usd, ok := p.Request(r.Source, r.Model, q.Tier, q.Buckets)
				add(key{r.Day, localHour(q.At), r.Source, r.Model, r.Origin}, usd, q.Buckets.Sum(), ok, false)
			}
			continue
		}
		b, known := rowBuckets(r)
		if !known {
			tokens := b.Sum()
			if r.TotalTokens != nil && *r.TotalTokens > tokens {
				tokens = *r.TotalTokens
			}
			add(key{r.Day, "", r.Source, r.Model, r.Origin}, 0, tokens, false, false)
			continue
		}
		usd, ok, approximate := p.Aggregate(r.Source, r.Model, b)
		add(key{r.Day, "", r.Source, r.Model, r.Origin}, usd, b.Sum(), ok, approximate)
	}
	out := make([]CostRow, 0, len(sums))
	for _, r := range sums {
		out = append(out, *r)
	}
	sort.Slice(out, func(i, j int) bool {
		a, b := out[i], out[j]
		if a.Day != b.Day {
			return a.Day < b.Day
		}
		if a.Hour != b.Hour {
			return a.Hour < b.Hour
		}
		if a.Source != b.Source {
			return a.Source < b.Source
		}
		if a.Model != b.Model {
			return a.Model < b.Model
		}
		return a.Origin < b.Origin
	})
	return out
}

// rowBuckets are a timing row's token kinds as accounting buckets. Output there includes
// reasoning; both are billed as output, so the split does not change a price. known is false
// when the row lacks a kind, so a price would have to guess its share; the known kinds are
// still filled so the tokens count.
func rowBuckets(r *PerfRow) (tokenacct.Buckets, bool) {
	b := tokenacct.Buckets{Output: max(0, r.ObservedOutputTokens)}
	known := true
	for _, k := range []struct {
		n  *int64
		to *int64
	}{{r.InputTokens, &b.Input}, {r.CacheReadTokens, &b.CacheRead}, {r.CacheWriteTokens, &b.CacheWrite}} {
		if k.n == nil {
			known = false
		} else {
			*k.to = max(0, *k.n)
		}
	}
	if !known {
		return b, false
	}
	if r.ReasoningTokens != nil && *r.ReasoningTokens > 0 && *r.ReasoningTokens <= b.Output {
		b.Output, b.Reasoning = b.Output-*r.ReasoningTokens, *r.ReasoningTokens
	}
	b.Total = b.Sum()
	return b, true
}

func sat(a, b int64) int64 {
	if b > 0 && a > 1<<63-1-b {
		return 1<<63 - 1
	}
	return a + b
}

// claudeTier reads Claude Code's message.usage.speed (ccusage claude/src/lib.rs).
func claudeTier(speed string) string {
	switch speed {
	case "", "standard":
		return ""
	case "fast":
		return "fast"
	}
	return "unknown"
}

// codexTier maps Codex's recorded service_tier spellings (ccusage codex/src/parser.rs
// codex_service_tier). An unrecognised tier is unknown, never assumed standard.
func codexTier(v string) string {
	switch v {
	case "default", "standard":
		return ""
	case "fast", "priority":
		return "fast"
	case "ultrafast", "flex":
		return v
	}
	return "unknown"
}

// SPDX-License-Identifier: MIT
package main

import (
	"math"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/cost"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

// publicationPricer prices local usage with the verified publication's API list prices
// (client-v1.6). A ledger model string names a price only through the publication's own
// model ID or reviewed harness alias (cockpitModelID); a speed tier only through the
// published API price multiplier for that harness, tier and model.
type publicationPricer struct {
	pub  digest.Digest
	ids  map[[2]string]string
	asOf string
}

func newPublicationPricer(models []digest.Model, tiers []digest.SpeedTier) *publicationPricer {
	return &publicationPricer{pub: digest.Digest{Models: models, Speed: tiers}, ids: map[[2]string]string{}}
}

func (p *publicationPricer) id(source, model string) string {
	k := [2]string{source, model}
	id, ok := p.ids[k]
	if !ok {
		id = cockpitModelID(model, source, p.pub.Models)
		p.ids[k] = id
	}
	return id
}

func (p *publicationPricer) price(source, model string) (string, *digest.Price) {
	id := p.id(source, model)
	if id == "unknown" {
		return id, nil
	}
	return id, p.pub.Price(id)
}

func (p *publicationPricer) used(price *digest.Price) {
	if price.AsOf > p.asOf {
		p.asOf = price.AsOf
	}
}

func (p *publicationPricer) Request(source, model, tier string, b tokenacct.Buckets) (float64, bool) {
	id, price := p.price(source, model)
	if price == nil {
		return 0, false
	}
	multiplier := 1.0
	if tier != "" {
		m := p.pub.APIPriceMultiplier(id, source, tier)
		if m == nil {
			return 0, false // the maker publishes no API price for this speed: no guess
		}
		multiplier = *m
	}
	usd, ok := cost.Request(price, b, multiplier)
	if ok {
		p.used(price)
	}
	return usd, ok
}

func (p *publicationPricer) Aggregate(source, model string, b tokenacct.Buckets) (float64, bool, bool) {
	_, price := p.price(source, model)
	usd, ok, approximate := cost.Aggregate(price, b)
	if ok {
		p.used(price)
	}
	return usd, ok, approximate
}

func publishesPrices(models []digest.Model) bool {
	for _, m := range models {
		if m.Price != nil {
			return true
		}
	}
	return false
}

const (
	cockpitCostDays  = 30
	cockpitCostHours = 48
	cockpitCostTop   = 64
)

// cockpitCost is the negotiated history's ≈cost section, or nil when the publication carries
// no prices. Only admitted sources count; days and hours are the ledgers' own local ones.
func cockpitCost(perf speed.PerfView, allowed map[string]bool, models []digest.Model, tiers []digest.SpeedTier, now time.Time) *wire.CockpitCost {
	if !publishesPrices(models) {
		return nil
	}
	pricer := newPublicationPricer(models, tiers)
	rows := perf.Costs(pricer)
	n := now.Local()
	y, m, d := n.Date()
	today := n.Format("2006-01-02")
	from7 := time.Date(y, m, d-6, 12, 0, 0, 0, time.Local).Format("2006-01-02")
	from30 := time.Date(y, m, d-(cockpitCostDays-1), 12, 0, 0, 0, time.Local).Format("2006-01-02")
	hourFrom := now.Add(-cockpitCostHours * time.Hour)

	type bucketKey struct{ at, source string }
	days, hours := map[bucketKey]*wire.CockpitCostBucket{}, map[bucketKey]*wire.CockpitCostBucket{}
	addBucket := func(into map[bucketKey]*wire.CockpitCostBucket, k bucketKey, r speed.CostRow) {
		b := into[k]
		if b == nil {
			b = &wire.CockpitCostBucket{At: k.at, Source: k.source}
			into[k] = b
		}
		b.EstimatedUsd += r.USD
		b.PricedTokens += r.PricedTokens
		b.UnpricedTokens += r.UnpricedTokens
		b.Approximate = b.Approximate || r.Approximate
	}
	type modelKey struct{ model, source string }
	ranges := [3]map[modelKey]*wire.CockpitModelCost{{}, {}, {}}
	for _, r := range rows {
		if !allowed[r.Source] || r.Day < from30 || r.Day > today {
			continue
		}
		if r.Hour != "" {
			// The last 48 local hours: an hour starting after now−48h and not after now.
			if at, err := time.Parse(time.RFC3339, r.Hour); err == nil && at.After(hourFrom) && !at.After(now) {
				addBucket(hours, bucketKey{r.Hour, r.Source}, r)
			}
		}
		if r.HourOnly {
			continue // already in that day's row
		}
		addBucket(days, bucketKey{r.Day, r.Source}, r)
		k := modelKey{pricer.id(r.Source, r.Model), r.Source}
		for i, from := range [3]string{today, from7, from30} {
			if r.Day < from {
				continue
			}
			c := ranges[i][k]
			if c == nil {
				c = &wire.CockpitModelCost{Model: k.model, Source: k.source}
				ranges[i][k] = c
			}
			if r.PricedTokens > 0 {
				usd := r.USD
				if c.EstimatedUsd != nil {
					usd += *c.EstimatedUsd
				}
				c.EstimatedUsd = &usd
			}
			c.PricedTokens += r.PricedTokens
			c.UnpricedTokens += r.UnpricedTokens
			c.Approximate = c.Approximate || r.Approximate
		}
	}
	out := &wire.CockpitCost{Basis: "api-list-price", Currency: "USD", Daily: costBuckets(days, 480), Hourly: costBuckets(hours, 384)}
	if pricer.asOf != "" {
		at := pricer.asOf
		out.PricesAsOf = &at
	}
	// Models are ranked by their ≈cost over all sources, and a model is kept or left out whole, so a
	// ranked model never loses one source's part. The page takes shares from the range totals.
	ranked := func(in map[modelKey]*wire.CockpitModelCost) []wire.CockpitModelCost {
		type model struct {
			id     string
			usd    float64
			priced bool
			tokens int64
			rows   []wire.CockpitModelCost
		}
		byModel := map[string]*model{}
		for _, c := range in {
			m := byModel[c.Model]
			if m == nil {
				m = &model{id: c.Model}
				byModel[c.Model] = m
			}
			if c.EstimatedUsd != nil {
				m.usd += *c.EstimatedUsd
				m.priced = true
				usd := roundUSD(*c.EstimatedUsd)
				c.EstimatedUsd = &usd
			}
			m.tokens += c.PricedTokens + c.UnpricedTokens
			m.rows = append(m.rows, *c)
		}
		models := make([]*model, 0, len(byModel))
		for _, m := range byModel {
			sort.Slice(m.rows, func(i, j int) bool { return m.rows[i].Source < m.rows[j].Source })
			models = append(models, m)
		}
		usd := func(m *model) float64 {
			if !m.priced {
				return -1
			}
			return m.usd
		}
		sort.Slice(models, func(i, j int) bool {
			a, b := models[i], models[j]
			if usd(a) != usd(b) {
				return usd(a) > usd(b)
			}
			if a.tokens != b.tokens {
				return a.tokens > b.tokens
			}
			return a.id < b.id
		})
		list := []wire.CockpitModelCost{}
		for _, m := range models {
			if len(list)+len(m.rows) > cockpitCostTop {
				break // the next model does not fit whole; no lower-ranked model takes its place
			}
			list = append(list, m.rows...)
		}
		return list
	}
	out.Models = wire.CockpitCostModels{Today: ranked(ranges[0]), Recent7d: ranked(ranges[1]), Recent30d: ranked(ranges[2])}
	return out
}

func costBuckets[K comparable](in map[K]*wire.CockpitCostBucket, limit int) []wire.CockpitCostBucket {
	out := make([]wire.CockpitCostBucket, 0, len(in))
	for _, b := range in {
		b.EstimatedUsd = roundUSD(b.EstimatedUsd)
		out = append(out, *b)
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].At != out[j].At {
			return out[i].At < out[j].At
		}
		return out[i].Source < out[j].Source
	})
	if len(out) > limit {
		out = out[len(out)-limit:] // the newest survive
	}
	return out
}

// roundUSD keeps a micro-dollar: below anything the page shows, and stable on the wire. A positive
// estimate never rounds to zero, so the page can still say "<$0.01" rather than "≈$0".
func roundUSD(v float64) float64 {
	r := math.Round(v*1e6) / 1e6
	if v > 0 && r == 0 {
		return 1e-6
	}
	return r
}

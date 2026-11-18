// SPDX-License-Identifier: MIT
package digest

// client-v1.6 (D291, WP-06): public API list prices. This file is the only place that
// knows the publication's price field names, so a rename in the final shape is one edit.
//
// The reader is lenient. Unknown fields are ignored; a price that fails a check is dropped
// for that model only (never the publication). A dropped or absent price is "no public API
// price": callers count the tokens and show no estimate. Nothing here guesses a price.

import (
	"encoding/json"
	"math"
	"strconv"
	"strings"
	"time"
)

const (
	// PriceUnitUSDPerMillion is the one unit the reader accepts: USD per million tokens.
	PriceUnitUSDPerMillion = "usd-per-1m-tokens"
	// EvaluationPending marks a published model whose efforts are not scored yet (#800).
	EvaluationPending = "pending"
	// priceMinMinor is the first client projection that may carry prices.
	priceMinMinor = 6
)

// Price is one model's public API list price, USD per million tokens. A nil cache rate is
// unknown, never zero.
type Price struct {
	Input      float64
	Output     float64
	CacheRead  *float64
	CacheWrite *float64
	Source     string // litellm | modelsdev
	AsOf       string // YYYY-MM-DD
	// LongContext applies to a whole request whose input (uncached + cache read + cache
	// write) exceeds AboveInputTokens. Nil when the model has no long-context price.
	LongContext *LongContextPrice
}

type LongContextPrice struct {
	AboveInputTokens int64
	Input            float64
	Output           float64
	CacheRead        *float64
	CacheWrite       *float64
}

// Price returns the model's public API list price, or nil when none is published.
func (d *Digest) Price(modelID string) *Price {
	if d == nil {
		return nil
	}
	if m := d.Model(modelID); m != nil {
		return m.Price
	}
	return nil
}

// APIPriceMultiplier is the published API per-token price multiple for a speed tier on one
// model (for example Claude fast mode). Nil when the maker publishes none: a subscription
// ratio is never used in its place.
func (d *Digest) APIPriceMultiplier(modelID, harness, tier string) *float64 {
	if d == nil {
		return nil
	}
	for _, t := range d.SpeedTiers(modelID, harness) {
		if t.Tier == tier && t.APIPriceMultiplier != nil {
			v := *t.APIPriceMultiplier
			return &v
		}
	}
	return nil
}

// readPrices fills Model.Price, Model.Evaluation, SpeedTier.APIPriceMultiplier and
// Digest.PriceUnit from the client data. It never fails the publication.
func readPrices(d *Digest, data json.RawMessage) {
	var raw struct {
		ProjectionVersion string `json:"projectionVersion"`
		PriceUnit         any    `json:"priceUnit"`
		Models            []struct {
			ID         string          `json:"id"`
			Price      json.RawMessage `json:"price"`
			Evaluation json.RawMessage `json:"evaluation"`
		} `json:"models"`
		SpeedTiers []struct {
			APIPriceMultiplier json.RawMessage `json:"apiPriceMultiplier"`
		} `json:"speedTiers"`
	}
	if json.Unmarshal(data, &raw) != nil {
		return
	}
	for i := range raw.Models {
		var evaluation string
		if i < len(d.Models) && d.Models[i].ID == raw.Models[i].ID && json.Unmarshal(raw.Models[i].Evaluation, &evaluation) == nil && evaluation == EvaluationPending {
			d.Models[i].Evaluation = EvaluationPending
		}
	}
	unit, _ := raw.PriceUnit.(string)
	if unit != PriceUnitUSDPerMillion || projectionMinor(raw.ProjectionVersion) < priceMinMinor {
		return
	}
	d.PriceUnit = unit
	for i := range raw.Models {
		if i < len(d.Models) && d.Models[i].ID == raw.Models[i].ID && len(raw.Models[i].Price) != 0 {
			d.Models[i].Price = parsePrice(raw.Models[i].Price)
		}
	}
	for i := range raw.SpeedTiers {
		if i < len(d.Speed) && len(raw.SpeedTiers[i].APIPriceMultiplier) != 0 {
			var v float64
			if json.Unmarshal(raw.SpeedTiers[i].APIPriceMultiplier, &v) == nil && positive(v) {
				d.Speed[i].APIPriceMultiplier = &v
			}
		}
	}
}

// projectionMinor is N of "client-v1.N", or -1.
func projectionMinor(v string) int {
	n, err := strconv.Atoi(strings.TrimPrefix(v, "client-v1."))
	if err != nil || !strings.HasPrefix(v, "client-v1.") || n < 0 {
		return -1
	}
	return n
}

func positive(v float64) bool { return v > 0 && !math.IsInf(v, 0) && !math.IsNaN(v) }

// rate is an optional per-type price: absent is unknown (nil, ok); null or a negative,
// non-finite or non-numeric value is invalid.
func rate(fields map[string]json.RawMessage, key string) (*float64, bool) {
	b, present := fields[key]
	if !present {
		return nil, true
	}
	var v *float64
	if json.Unmarshal(b, &v) != nil || v == nil || *v < 0 || math.IsInf(*v, 0) || math.IsNaN(*v) {
		return nil, false
	}
	return v, true
}

func required(fields map[string]json.RawMessage, key string) (float64, bool) {
	v, ok := rate(fields, key)
	if !ok || v == nil || !positive(*v) {
		return 0, false
	}
	return *v, true
}

func parsePrice(b json.RawMessage) *Price {
	var fields map[string]json.RawMessage
	if json.Unmarshal(b, &fields) != nil || fields == nil {
		return nil
	}
	var p Price
	var ok, okRead, okWrite bool
	if p.Input, ok = required(fields, "input"); !ok {
		return nil
	}
	if p.Output, ok = required(fields, "output"); !ok {
		return nil
	}
	p.CacheRead, okRead = rate(fields, "cacheRead")
	p.CacheWrite, okWrite = rate(fields, "cacheWrite")
	if !okRead || !okWrite {
		return nil
	}
	if json.Unmarshal(fields["source"], &p.Source) != nil || p.Source == "" {
		return nil
	}
	if json.Unmarshal(fields["asOf"], &p.AsOf) != nil {
		return nil
	}
	if _, err := time.Parse("2006-01-02", p.AsOf); err != nil {
		return nil
	}
	if lc, present := fields["longContext"]; present {
		if p.LongContext = parseLongContext(lc); p.LongContext == nil {
			// Pricing a long request at the short rate would be a guess.
			return nil
		}
	}
	return &p
}

func parseLongContext(b json.RawMessage) *LongContextPrice {
	var fields map[string]json.RawMessage
	if json.Unmarshal(b, &fields) != nil || fields == nil {
		return nil
	}
	var p LongContextPrice
	var above float64
	if json.Unmarshal(fields["aboveInputTokens"], &above) != nil || above < 1 || above != math.Trunc(above) || above > math.MaxInt64/2 {
		return nil
	}
	p.AboveInputTokens = int64(above)
	var ok, okRead, okWrite bool
	if p.Input, ok = required(fields, "input"); !ok {
		return nil
	}
	if p.Output, ok = required(fields, "output"); !ok {
		return nil
	}
	p.CacheRead, okRead = rate(fields, "cacheRead")
	p.CacheWrite, okWrite = rate(fields, "cacheWrite")
	if !okRead || !okWrite {
		return nil
	}
	return &p
}

package digest

import (
	"bytes"
	"encoding/json"
	"errors"
	"math"
	"strconv"
	"strings"
	"time"
)

// client-v1.6 adds public API list prices (USD per 1M tokens), a daily usage-rank trend, small
// and pending-evaluation model rows, and a fast-tier API price multiplier. This file validates
// those fields with the same rules and codes as reader/public-reader.mjs; keep the two in
// lockstep. Readers only validate: a model's longContext rates apply per request when that
// request's input tokens exceed aboveInputTokens, and choosing them belongs to the cost code.

const (
	PriceUnitUSDPer1M = "usd-per-1m-tokens"
	usageTrendLimit   = 8192 // bytes of the serialized usageTrend
)

var (
	errV16Projection = errors.New("client: invalid_client_v16_projection")
	errPriceUnit     = errors.New("client: invalid_client_price_unit")
	errPendingModel  = errors.New("client: invalid_client_pending_model")
	errEvaluation    = errors.New("client: invalid_client_evaluation")
)

type v16Model struct {
	ID                  string          `json:"id"`
	Small               json.RawMessage `json:"small"`
	Evaluation          json.RawMessage `json:"evaluation"`
	Price               json.RawMessage `json:"price"`
	Efforts             json.RawMessage `json:"efforts"` // absent, null and [] stay distinct
	Recommended         json.RawMessage `json:"recommended"`
	RecommendationBasis json.RawMessage `json:"recommendationBasis"`
	DefaultSelected     json.RawMessage `json:"defaultSelected"`
}

type v16Data struct {
	ProjectionVersion string          `json:"projectionVersion"`
	PriceUnit         json.RawMessage `json:"priceUnit"`
	UsageTrend        json.RawMessage `json:"usageTrend"`
	Models            []v16Model      `json:"models"`
	SpeedTiers        []struct {
		APIPriceMultiplier json.RawMessage `json:"apiPriceMultiplier"`
	} `json:"speedTiers"`
	Lineups []struct {
		Baseline string   `json:"baseline"`
		Frontier []string `json:"frontier"`
		Members  []struct {
			ID string `json:"id"`
		} `json:"members"`
	} `json:"lineups"`
}

// projectionMinor is N in client-v1.N, or 0 for a historical digest without a projection version.
func projectionMinor(v string) int {
	n, err := strconv.Atoi(strings.TrimPrefix(v, "client-v1."))
	if err != nil || !strings.HasPrefix(v, "client-v1.") {
		return 0
	}
	return n
}

func present(r json.RawMessage) bool { return len(r) > 0 }

// emptyArray is true only for a present JSON [] (not absent, not null).
func emptyArray(r json.RawMessage) bool {
	var a []json.RawMessage
	return present(r) && string(r) != "null" && json.Unmarshal(r, &a) == nil && a != nil && len(a) == 0
}

// screenClientV16 checks the client-v1.6 fields before Parse decodes the digest. It returns the data with every
// malformed optional field removed, one diagnostic per removal, and an error only for a publication-level violation.
//
// The split with reader/public-reader.mjs is deliberate. The JS public reader is the producer's validator and rejects
// any violation. This app-facing CLI digest follows the rule for optional fields (aaScore, planMetering, planModels):
// a bad models[].small, models[].price or price.longContext is dropped for that model, a bad
// speedTiers[].apiPriceMultiplier for that tier, and a bad usageTrend as a whole; the publication survives. These stay
// rejections: v1.6 fields below client-v1.6, an evaluation other than "pending", a pending row with efforts, a
// recommendation, a missing null recommendationBasis, defaultSelected true or a lineup place, and a priceUnit that is
// not usd-per-1m-tokens or does not match whether any model still has a price after the drops.
func screenClientV16(data json.RawMessage) (json.RawMessage, []string, error) {
	var d v16Data
	if err := json.Unmarshal(data, &d); err != nil {
		return nil, nil, err
	}
	if projectionMinor(d.ProjectionVersion) < 6 {
		if present(d.PriceUnit) || present(d.UsageTrend) {
			return nil, nil, errV16Projection
		}
		for _, m := range d.Models {
			if present(m.Small) || present(m.Price) || present(m.Evaluation) {
				return nil, nil, errV16Projection
			}
		}
		for _, t := range d.SpeedTiers {
			if present(t.APIPriceMultiplier) {
				return nil, nil, errV16Projection
			}
		}
		return data, nil, nil
	}
	pending, ids := map[string]bool{}, map[string]bool{}
	for _, m := range d.Models {
		ids[m.ID] = true
		if present(m.Evaluation) {
			var s string
			if json.Unmarshal(m.Evaluation, &s) != nil || s != "pending" {
				return nil, nil, errEvaluation
			}
			pending[m.ID] = true
		}
		if pending[m.ID] && (!emptyArray(m.Efforts) || string(m.Recommended) != "null" || string(m.RecommendationBasis) != "null" || string(m.DefaultSelected) == "true") {
			return nil, nil, errPendingModel
		}
	}
	for _, l := range d.Lineups {
		if pending[l.Baseline] {
			return nil, nil, errPendingModel
		}
		for _, id := range l.Frontier {
			if pending[id] {
				return nil, nil, errPendingModel
			}
		}
		for _, r := range l.Members {
			if pending[r.ID] {
				return nil, nil, errPendingModel
			}
		}
	}
	if present(d.PriceUnit) {
		var u string
		if json.Unmarshal(d.PriceUnit, &u) != nil || u != PriceUnitUSDPer1M {
			return nil, nil, errPriceUnit
		}
	}

	var top map[string]json.RawMessage
	if err := json.Unmarshal(data, &top); err != nil {
		return nil, nil, err
	}
	var dropped []string
	changed, priced := false, false
	var models []map[string]json.RawMessage
	if json.Unmarshal(top["models"], &models) == nil {
		modelsChanged := false
		for i, m := range models {
			id := d.Models[i].ID
			if v, ok := m["small"]; ok {
				var b bool
				if string(v) == "null" || json.Unmarshal(v, &b) != nil {
					delete(m, "small")
					dropped, modelsChanged = append(dropped, "models["+id+"].small"), true
				}
			}
			if v, ok := m["price"]; ok {
				kept, note := screenPrice(v)
				if note != "" {
					dropped, modelsChanged = append(dropped, "models["+id+"]."+note), true
				}
				if kept == nil {
					delete(m, "price")
				} else {
					m["price"], priced = kept, true
				}
			}
		}
		if modelsChanged {
			if b, err := json.Marshal(models); err == nil {
				top["models"], changed = b, true
			}
		}
	}
	var tiers []map[string]json.RawMessage
	if json.Unmarshal(top["speedTiers"], &tiers) == nil {
		tiersChanged := false
		for _, t := range tiers {
			if v, ok := t["apiPriceMultiplier"]; ok {
				if x, ok := number(v); !ok || x <= 1 {
					var id string
					_ = json.Unmarshal(t["id"], &id)
					delete(t, "apiPriceMultiplier")
					dropped, tiersChanged = append(dropped, "speedTiers["+id+"].apiPriceMultiplier"), true
				}
			}
		}
		if tiersChanged {
			if b, err := json.Marshal(tiers); err == nil {
				top["speedTiers"], changed = b, true
			}
		}
	}
	if present(d.PriceUnit) != priced {
		return nil, nil, errPriceUnit
	}
	if present(d.UsageTrend) && !validUsageTrend(d.UsageTrend, ids) {
		delete(top, "usageTrend")
		dropped, changed = append(dropped, "usageTrend"), true
	}
	if !changed {
		return data, nil, nil
	}
	b, err := json.Marshal(top)
	if err != nil {
		return nil, nil, err
	}
	return b, dropped, nil
}

// fields decodes a strict JSON object: only the listed keys, every required key present, no nulls.
func fields(raw json.RawMessage, required, optional []string) (map[string]json.RawMessage, bool) {
	var o map[string]json.RawMessage
	if json.Unmarshal(raw, &o) != nil || o == nil {
		return nil, false
	}
	allowed := map[string]bool{}
	for _, k := range append(append([]string(nil), required...), optional...) {
		allowed[k] = true
	}
	for k, v := range o {
		if !allowed[k] || string(v) == "null" {
			return nil, false
		}
	}
	for _, k := range required {
		if _, ok := o[k]; !ok {
			return nil, false
		}
	}
	return o, true
}

func number(raw json.RawMessage) (float64, bool) {
	var v float64
	if string(raw) == "null" || json.Unmarshal(raw, &v) != nil || math.IsNaN(v) || math.IsInf(v, 0) {
		return 0, false
	}
	return v, true
}

func integer(raw json.RawMessage) (float64, bool) {
	v, ok := number(raw)
	return v, ok && v == math.Trunc(v)
}

// isoDay accepts a calendar date written YYYY-MM-DD.
func isoDay(raw json.RawMessage) bool {
	var s string
	if json.Unmarshal(raw, &s) != nil || len(s) != 10 {
		return false
	}
	_, err := time.Parse("2006-01-02", s)
	return err == nil
}

func validRates(o map[string]json.RawMessage) bool {
	for _, k := range []string{"input", "output"} {
		if v, ok := number(o[k]); !ok || v <= 0 {
			return false
		}
	}
	for _, k := range []string{"cacheRead", "cacheWrite"} {
		if r, set := o[k]; set {
			if v, ok := number(r); !ok || v < 0 {
				return false
			}
		}
	}
	return true
}

// screenPrice returns the price to keep (nil to drop it) and, when something was dropped, what: "price" when the base
// rates are malformed, "price.longContext" when only the long-context rates are.
func screenPrice(raw json.RawMessage) (json.RawMessage, string) {
	// The base rates are validated without longContext, so a malformed longContext (null included) never takes
	// the valid base price down with it.
	var whole map[string]json.RawMessage
	if json.Unmarshal(raw, &whole) != nil || whole == nil {
		return nil, "price"
	}
	lc, hasLC := whole["longContext"]
	delete(whole, "longContext")
	base, err := json.Marshal(whole)
	if err != nil {
		return nil, "price"
	}
	o, ok := fields(base, []string{"input", "output", "source", "asOf"}, []string{"cacheRead", "cacheWrite"})
	if !ok || !validRates(o) || !isoDay(o["asOf"]) {
		return nil, "price"
	}
	var source string
	if json.Unmarshal(o["source"], &source) != nil || (source != "litellm" && source != "modelsdev") {
		return nil, "price"
	}
	if !hasLC || validLongContext(lc) {
		return raw, ""
	}
	return base, "price.longContext"
}

func validLongContext(raw json.RawMessage) bool {
	l, ok := fields(raw, []string{"aboveInputTokens", "input", "output"}, []string{"cacheRead", "cacheWrite"})
	if !ok || !validRates(l) {
		return false
	}
	v, ok := integer(l["aboveInputTokens"])
	return ok && v > 0
}

func validUsageTrend(raw json.RawMessage, models map[string]bool) bool {
	o, ok := fields(raw, []string{"source", "asOf", "days", "ranks"}, nil)
	if !ok || !isoDay(o["asOf"]) {
		return false
	}
	var source string
	if json.Unmarshal(o["source"], &source) != nil || source != "openrouter-paid-daily" {
		return false
	}
	days, ok := integer(o["days"])
	if !ok || days < 1 || days > 90 {
		return false
	}
	var ranks map[string][]json.RawMessage
	if json.Unmarshal(o["ranks"], &ranks) != nil || ranks == nil {
		return false
	}
	for id, series := range ranks {
		if id == "" || !models[id] || series == nil || len(series) != int(days) {
			return false
		}
		for _, r := range series {
			if string(r) == "null" {
				continue
			}
			if v, ok := integer(r); !ok || v < 1 {
				return false
			}
		}
	}
	// Measure the serialized object as the JS reader does (JSON.stringify of the parsed value).
	var v any
	if json.Unmarshal(raw, &v) != nil {
		return false
	}
	var buf bytes.Buffer
	enc := json.NewEncoder(&buf)
	enc.SetEscapeHTML(false)
	if enc.Encode(v) != nil {
		return false
	}
	return buf.Len()-1 <= usageTrendLimit
}

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
	errUsageTrend    = errors.New("client: invalid_client_usage_trend")
	errPendingModel  = errors.New("client: invalid_client_pending_model")
	errPrice         = errors.New("client: invalid_client_price")
	errSmall         = errors.New("client: invalid_client_small")
	errEvaluation    = errors.New("client: invalid_client_evaluation")
	errSpeedPrice    = errors.New("client: invalid_speed_tier_api_price_multiplier")
)

type v16Model struct {
	ID                  string            `json:"id"`
	Small               json.RawMessage   `json:"small"`
	Evaluation          json.RawMessage   `json:"evaluation"`
	Price               json.RawMessage   `json:"price"`
	Efforts             []json.RawMessage `json:"efforts"`
	Recommended         json.RawMessage   `json:"recommended"`
	RecommendationBasis json.RawMessage   `json:"recommendationBasis"`
	DefaultSelected     json.RawMessage   `json:"defaultSelected"`
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

func validateClientV16(data json.RawMessage) error {
	var d v16Data
	if err := json.Unmarshal(data, &d); err != nil {
		return err
	}
	if projectionMinor(d.ProjectionVersion) < 6 {
		if present(d.PriceUnit) || present(d.UsageTrend) {
			return errV16Projection
		}
		for _, m := range d.Models {
			if present(m.Small) || present(m.Price) || present(m.Evaluation) {
				return errV16Projection
			}
		}
		for _, t := range d.SpeedTiers {
			if present(t.APIPriceMultiplier) {
				return errV16Projection
			}
		}
		return nil
	}
	priced, pending, ids := false, map[string]bool{}, map[string]bool{}
	for _, m := range d.Models {
		ids[m.ID] = true
		if present(m.Small) {
			var b bool
			if string(m.Small) == "null" || json.Unmarshal(m.Small, &b) != nil {
				return errSmall
			}
		}
		if present(m.Evaluation) {
			var s string
			if json.Unmarshal(m.Evaluation, &s) != nil || s != "pending" {
				return errEvaluation
			}
			pending[m.ID] = true
		}
		if present(m.Price) {
			if !validModelPrice(m.Price) {
				return errPrice
			}
			priced = true
		}
	}
	for _, t := range d.SpeedTiers {
		if present(t.APIPriceMultiplier) {
			if v, ok := number(t.APIPriceMultiplier); !ok || v <= 1 {
				return errSpeedPrice
			}
		}
	}
	if present(d.PriceUnit) {
		var u string
		if json.Unmarshal(d.PriceUnit, &u) != nil || u != PriceUnitUSDPer1M {
			return errPriceUnit
		}
	}
	if present(d.PriceUnit) != priced {
		return errPriceUnit
	}
	if present(d.UsageTrend) && !validUsageTrend(d.UsageTrend, ids) {
		return errUsageTrend
	}
	for _, m := range d.Models {
		if pending[m.ID] && (len(m.Efforts) > 0 || string(m.Recommended) != "null" || string(m.RecommendationBasis) != "null" || string(m.DefaultSelected) == "true") {
			return errPendingModel
		}
	}
	for _, l := range d.Lineups {
		if pending[l.Baseline] {
			return errPendingModel
		}
		for _, id := range l.Frontier {
			if pending[id] {
				return errPendingModel
			}
		}
		for _, r := range l.Members {
			if pending[r.ID] {
				return errPendingModel
			}
		}
	}
	return nil
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

func validModelPrice(raw json.RawMessage) bool {
	o, ok := fields(raw, []string{"input", "output", "source", "asOf"}, []string{"cacheRead", "cacheWrite", "longContext"})
	if !ok || !validRates(o) || !isoDay(o["asOf"]) {
		return false
	}
	var source string
	if json.Unmarshal(o["source"], &source) != nil || (source != "litellm" && source != "modelsdev") {
		return false
	}
	if lc, set := o["longContext"]; set {
		l, ok := fields(lc, []string{"aboveInputTokens", "input", "output"}, []string{"cacheRead", "cacheWrite"})
		if !ok || !validRates(l) {
			return false
		}
		if v, ok := integer(l["aboveInputTokens"]); !ok || v <= 0 {
			return false
		}
	}
	return true
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

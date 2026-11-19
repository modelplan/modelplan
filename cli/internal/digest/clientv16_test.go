package digest

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

// The production client-v1.6 projection, trimmed to the Anthropic and OpenAI rows. Shared with the JS reader tests.
const v16Example = "../../../testdata/client-v1.6/example.json"
const v16Pending = "astra-6.2"

func exampleData(t *testing.T) map[string]any {
	t.Helper()
	b, err := os.ReadFile(v16Example)
	if err != nil {
		t.Fatal(err)
	}
	var d map[string]any
	if err := json.Unmarshal(b, &d); err != nil {
		t.Fatal(err)
	}
	return d
}

func v16Parse(t *testing.T, edit func(d map[string]any)) (*Digest, error) {
	t.Helper()
	d := exampleData(t)
	if edit != nil {
		edit(d)
	}
	b, err := json.Marshal(map[string]any{"schemaVersion": 1, "kind": "client", "data": d})
	if err != nil {
		t.Fatal(err)
	}
	return Parse("client", b)
}

func exampleModel(d map[string]any, id string) map[string]any {
	for _, m := range d["models"].([]any) {
		if m := m.(map[string]any); m["id"] == id {
			return m
		}
	}
	panic(id)
}

func v16Rejects(t *testing.T, name, code string, edit func(d map[string]any)) {
	t.Helper()
	if _, err := v16Parse(t, edit); err == nil || !strings.Contains(err.Error(), code) {
		t.Fatalf("%s: err=%v, want %s", name, err, code)
	}
}

func TestClientV16ExampleParsesWithPendingRowsAndUnderTheCap(t *testing.T) {
	b, err := os.ReadFile(v16Example)
	if err != nil {
		t.Fatal(err)
	}
	if len(b) > 250_000 {
		t.Fatalf("example is %d bytes, above the 250 kB client cap", len(b))
	}
	d, err := v16Parse(t, nil)
	if err != nil {
		t.Fatal(err)
	}
	m := d.Model(v16Pending)
	if m == nil || len(m.Efforts) != 0 || m.Recommended != "" || m.Rec() != nil {
		t.Fatalf("pending row = %+v", m)
	}
	if d.ProjectionVersion != "client-v1.6" || len(d.Lineups) != 2 {
		t.Fatalf("digest = %s, %d lineups", d.ProjectionVersion, len(d.Lineups))
	}
}

func TestClientV16FieldsAreRejectedBelowV16(t *testing.T) {
	strip := func(d map[string]any) {
		d["projectionVersion"] = "client-v1.5"
		delete(d, "priceUnit")
		delete(d, "usageTrend")
		for _, m := range d["models"].([]any) {
			m := m.(map[string]any)
			delete(m, "small")
			delete(m, "price")
			delete(m, "evaluation")
		}
		for _, s := range d["speedTiers"].([]any) {
			delete(s.(map[string]any), "apiPriceMultiplier")
		}
	}
	if _, err := v16Parse(t, strip); err != nil {
		t.Fatalf("stripped v1.5 digest: %v", err)
	}
	price := exampleModel(exampleData(t), "opus")["price"]
	for name, add := range map[string]func(d map[string]any){
		"priceUnit": func(d map[string]any) { d["priceUnit"] = PriceUnitUSDPer1M },
		"usageTrend": func(d map[string]any) {
			d["usageTrend"] = map[string]any{"source": "openrouter-paid-daily", "asOf": "2026-11-18", "days": 1, "ranks": map[string]any{}}
		},
		"small":              func(d map[string]any) { exampleModel(d, "opus")["small"] = false },
		"price":              func(d map[string]any) { exampleModel(d, "opus")["price"] = price },
		"evaluation":         func(d map[string]any) { exampleModel(d, v16Pending)["evaluation"] = "pending" },
		"apiPriceMultiplier": func(d map[string]any) { d["speedTiers"].([]any)[0].(map[string]any)["apiPriceMultiplier"] = 2 },
	} {
		v16Rejects(t, name, "invalid_client_v16_projection", func(d map[string]any) { strip(d); add(d) })
	}
}

func TestClientV16PriceUnitIsPresentExactlyWithPrices(t *testing.T) {
	v16Rejects(t, "prices without unit", "invalid_client_price_unit", func(d map[string]any) { delete(d, "priceUnit") })
	v16Rejects(t, "unit without prices", "invalid_client_price_unit", func(d map[string]any) {
		for _, m := range d["models"].([]any) {
			delete(m.(map[string]any), "price")
		}
	})
	v16Rejects(t, "other unit", "invalid_client_price_unit", func(d map[string]any) { d["priceUnit"] = "usd-per-1k-tokens" })
	if _, err := v16Parse(t, func(d map[string]any) {
		delete(d, "priceUnit")
		for _, m := range d["models"].([]any) {
			delete(m.(map[string]any), "price")
		}
	}); err != nil {
		t.Fatalf("no prices, no unit: %v", err)
	}
}

// v16Drops parses an edited example and returns the diagnostics and the published models as the app receives them.
func v16Drops(t *testing.T, name string, edit func(d map[string]any)) ([]string, string) {
	t.Helper()
	d, err := v16Parse(t, edit)
	if err != nil {
		t.Fatalf("%s: the publication was rejected: %v", name, err)
	}
	p := d.Publication()
	return d.Dropped, string(p.Models) + "\n" + string(p.SpeedTiers)
}

// publishedModel finds one model in the published models feed returned by v16Drops.
func publishedModel(t *testing.T, feed, id string) map[string]any {
	t.Helper()
	var models []map[string]any
	if err := json.Unmarshal([]byte(strings.SplitN(feed, "\n", 2)[0]), &models); err != nil {
		t.Fatal(err)
	}
	for _, m := range models {
		if m["id"] == id {
			return m
		}
	}
	t.Fatalf("%s not published", id)
	return nil
}

func TestClientV16MalformedModelPricesAreDroppedForThatModel(t *testing.T) {
	for name, edit := range map[string]func(p map[string]any){
		"zero input":      func(p map[string]any) { p["input"] = 0 },
		"negative output": func(p map[string]any) { p["output"] = -1 },
		"null cache read": func(p map[string]any) { p["cacheRead"] = nil },
		"negative write":  func(p map[string]any) { p["cacheWrite"] = -0.1 },
		"unknown source":  func(p map[string]any) { p["source"] = "openrouter" },
		"timestamp asOf":  func(p map[string]any) { p["asOf"] = "2026-11-19T00:00:00Z" },
		"impossible asOf": func(p map[string]any) { p["asOf"] = "2026-02-30" },
		"unknown key":     func(p map[string]any) { p["extra"] = 1 },
		"string input":    func(p map[string]any) { p["input"] = "4" },
	} {
		dropped, models := v16Drops(t, name, func(d map[string]any) { edit(exampleModel(d, "opus")["price"].(map[string]any)) })
		if len(dropped) != 1 || dropped[0] != "models[opus].price" {
			t.Fatalf("%s: dropped %v", name, dropped)
		}
		if _, ok := publishedModel(t, models, "opus")["price"]; ok {
			t.Fatalf("%s: opus price still published", name)
		}
	}
	for name, lc := range map[string]any{
		"zero threshold":    map[string]any{"aboveInputTokens": 0, "input": 1, "output": 1},
		"fraction":          map[string]any{"aboveInputTokens": 1.5, "input": 1, "output": 1},
		"null long cache":   map[string]any{"aboveInputTokens": 200000, "input": 1, "output": 1, "cacheRead": nil},
		"missing longInput": map[string]any{"aboveInputTokens": 200000, "output": 1},
		"not an object":     "272000",
	} {
		dropped, models := v16Drops(t, name, func(d map[string]any) { exampleModel(d, "opus")["price"].(map[string]any)["longContext"] = lc })
		price, _ := publishedModel(t, models, "opus")["price"].(map[string]any)
		if len(dropped) != 1 || dropped[0] != "models[opus].price.longContext" || price == nil || price["input"] != 4.0 || price["longContext"] != nil {
			t.Fatalf("%s: dropped %v, published price %v", name, dropped, price)
		}
	}
	dropped, _ := v16Drops(t, "small", func(d map[string]any) { exampleModel(d, "opus")["small"] = "yes" })
	if len(dropped) != 1 || dropped[0] != "models[opus].small" {
		t.Fatalf("small: dropped %v", dropped)
	}
	if dropped, _ := v16Drops(t, "absent cache rates", func(d map[string]any) {
		p := exampleModel(d, "opus")["price"].(map[string]any)
		delete(p, "cacheRead")
		delete(p, "cacheWrite")
	}); len(dropped) != 0 {
		t.Fatalf("absent cache rates dropped %v", dropped)
	}
	// priceUnit is checked after the drops: no priced model left means the unit must go too.
	v16Rejects(t, "every price dropped", "invalid_client_price_unit", func(d map[string]any) {
		for _, m := range d["models"].([]any) {
			if p, ok := m.(map[string]any)["price"].(map[string]any); ok {
				p["input"] = 0
			}
		}
	})
}

func TestClientV16MalformedUsageTrendIsDroppedAsAWhole(t *testing.T) {
	trend := func(d map[string]any) map[string]any { return d["usageTrend"].(map[string]any) }
	for name, edit := range map[string]func(u map[string]any){
		"unknown model": func(u map[string]any) { u["ranks"].(map[string]any)["not-a-model"] = make([]any, 30) },
		"short series":  func(u map[string]any) { u["ranks"].(map[string]any)["astra"] = make([]any, 29) },
		"zero days":     func(u map[string]any) { u["days"] = 0 },
		"91 days":       func(u map[string]any) { u["days"] = 91 },
		"source":        func(u map[string]any) { u["source"] = "openrouter" },
		"asOf":          func(u map[string]any) { u["asOf"] = "18 Nov 2026" },
		"rank 0":        func(u map[string]any) { u["ranks"].(map[string]any)["astra"].([]any)[0] = 0 },
		"unknown key":   func(u map[string]any) { u["extra"] = true },
	} {
		if dropped, _ := v16Drops(t, name, func(d map[string]any) { edit(trend(d)) }); len(dropped) != 1 || dropped[0] != "usageTrend" {
			t.Fatalf("%s: dropped %v", name, dropped)
		}
	}
	dropped, _ := v16Drops(t, "over 8192 bytes", func(d map[string]any) {
		trend(d)["days"] = 90
		r := map[string]any{}
		for _, m := range d["models"].([]any) {
			s := make([]any, 90)
			for i := range s {
				s[i] = 1000000
			}
			r[m.(map[string]any)["id"].(string)] = s
		}
		trend(d)["ranks"] = r
	})
	if len(dropped) != 1 || dropped[0] != "usageTrend" {
		t.Fatalf("over 8192 bytes: dropped %v", dropped)
	}
}

func TestClientV16PendingRows(t *testing.T) {
	opus := exampleModel(exampleData(t), "opus")
	for name, edit := range map[string]func(m map[string]any){
		"efforts":             func(m map[string]any) { m["efforts"] = opus["efforts"] },
		"recommended":         func(m map[string]any) { m["efforts"], m["recommended"] = opus["efforts"], opus["recommended"] },
		"basis":               func(m map[string]any) { m["recommendationBasis"] = "balanced" },
		"basis absent":        func(m map[string]any) { delete(m, "recommendationBasis") },
		"recommended absent":  func(m map[string]any) { delete(m, "recommended") },
		"default selected":    func(m map[string]any) { m["defaultSelected"] = true },
		"evaluation not word": func(m map[string]any) { m["evaluation"] = "done" },
	} {
		if _, err := v16Parse(t, func(d map[string]any) { edit(exampleModel(d, v16Pending)) }); err == nil {
			t.Fatalf("%s accepted", name)
		}
		if name != "evaluation not word" {
			v16Rejects(t, name, "invalid_client_pending_model", func(d map[string]any) { edit(exampleModel(d, v16Pending)) })
		}
	}
	for _, where := range []string{"members", "frontier", "baseline"} {
		v16Rejects(t, "lineup "+where, "invalid_client_pending_model", func(d map[string]any) {
			for _, l := range d["lineups"].([]any) {
				if l := l.(map[string]any); l["developerId"] == "openai" {
					l["members"] = append(l["members"].([]any), map[string]any{"id": v16Pending, "status": "incomplete", "tags": []any{}, "dominatedBy": nil})
					switch where {
					case "frontier":
						l["frontier"] = append(l["frontier"].([]any), v16Pending)
					case "baseline":
						l["baseline"] = v16Pending
					}
				}
			}
		})
	}
}

func TestClientV16APIPriceMultiplierAtOrBelowOneIsDropped(t *testing.T) {
	for _, v := range []any{1, 0.5, 0, "2", nil} {
		dropped, tiers := v16Drops(t, "apiPriceMultiplier", func(d map[string]any) { d["speedTiers"].([]any)[0].(map[string]any)["apiPriceMultiplier"] = v })
		if len(dropped) != 1 || !strings.HasSuffix(dropped[0], ".apiPriceMultiplier") || strings.Count(tiers, "apiPriceMultiplier") != 1 {
			t.Fatalf("apiPriceMultiplier %v: dropped %v", v, dropped)
		}
	}
	if dropped, _ := v16Drops(t, "1.5", func(d map[string]any) { d["speedTiers"].([]any)[0].(map[string]any)["apiPriceMultiplier"] = 1.5 }); len(dropped) != 0 {
		t.Fatalf("1.5 dropped %v", dropped)
	}
}

// A malformed optional longContext, null included, drops only itself: the base price stays, so the priceUnit stays valid
// even when that model is the only priced one.
func TestClientV16NullLongContextKeepsTheBasePrice(t *testing.T) {
	setNull := func(d map[string]any) { exampleModel(d, "astra")["price"].(map[string]any)["longContext"] = nil }
	onlyAstraPriced := func(d map[string]any) {
		for _, m := range d["models"].([]any) {
			if m := m.(map[string]any); m["id"] != "astra" {
				delete(m, "price")
			}
		}
	}
	for name, edit := range map[string]func(d map[string]any){
		"null longContext":              setNull,
		"null longContext, sole priced": func(d map[string]any) { onlyAstraPriced(d); setNull(d) },
		"bad longContext, sole priced": func(d map[string]any) {
			onlyAstraPriced(d)
			exampleModel(d, "astra")["price"].(map[string]any)["longContext"] = map[string]any{"aboveInputTokens": 0, "input": 1, "output": 1}
		},
	} {
		dropped, models := v16Drops(t, name, edit)
		price, _ := publishedModel(t, models, "astra")["price"].(map[string]any)
		if len(dropped) != 1 || dropped[0] != "models[astra].price.longContext" || price == nil || price["input"] != 10.0 || price["cacheRead"] != 1.0 {
			t.Fatalf("%s: dropped %v, published price %v", name, dropped, price)
		}
		if _, ok := price["longContext"]; ok {
			t.Fatalf("%s: longContext still published", name)
		}
	}
}

// A pending row's efforts must be a present empty array: absent and null are rejected like non-empty.
func TestClientV16PendingEffortsMustBeAPresentEmptyArray(t *testing.T) {
	v16Rejects(t, "efforts absent", "invalid_client_pending_model", func(d map[string]any) { delete(exampleModel(d, v16Pending), "efforts") })
	v16Rejects(t, "efforts null", "invalid_client_pending_model", func(d map[string]any) { exampleModel(d, v16Pending)["efforts"] = nil })
	if _, err := v16Parse(t, func(d map[string]any) { exampleModel(d, v16Pending)["efforts"] = []any{} }); err != nil {
		t.Fatalf("efforts []: %v", err)
	}
}

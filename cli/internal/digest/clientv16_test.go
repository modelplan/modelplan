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

func TestClientV16ModelPricesAreStrict(t *testing.T) {
	for name, edit := range map[string]func(p map[string]any){
		"zero input":      func(p map[string]any) { p["input"] = 0 },
		"negative output": func(p map[string]any) { p["output"] = -1 },
		"null cache read": func(p map[string]any) { p["cacheRead"] = nil },
		"negative write":  func(p map[string]any) { p["cacheWrite"] = -0.1 },
		"unknown source":  func(p map[string]any) { p["source"] = "openrouter" },
		"timestamp asOf":  func(p map[string]any) { p["asOf"] = "2026-11-19T00:00:00Z" },
		"impossible asOf": func(p map[string]any) { p["asOf"] = "2026-02-30" },
		"unknown key":     func(p map[string]any) { p["extra"] = 1 },
		"zero threshold": func(p map[string]any) {
			p["longContext"] = map[string]any{"aboveInputTokens": 0, "input": 1, "output": 1}
		},
		"fraction": func(p map[string]any) {
			p["longContext"] = map[string]any{"aboveInputTokens": 1.5, "input": 1, "output": 1}
		},
		"null long cache": func(p map[string]any) {
			p["longContext"] = map[string]any{"aboveInputTokens": 200000, "input": 1, "output": 1, "cacheRead": nil}
		},
		"string input":      func(p map[string]any) { p["input"] = "4" },
		"missing longInput": func(p map[string]any) { p["longContext"] = map[string]any{"aboveInputTokens": 200000, "output": 1} },
	} {
		if _, err := v16Parse(t, func(d map[string]any) { edit(exampleModel(d, "opus")["price"].(map[string]any)) }); err == nil {
			t.Fatalf("%s accepted", name)
		}
	}
	if _, err := v16Parse(t, func(d map[string]any) {
		p := exampleModel(d, "opus")["price"].(map[string]any)
		delete(p, "cacheRead")
		delete(p, "cacheWrite")
	}); err != nil {
		t.Fatalf("absent cache rates: %v", err)
	}
}

func TestClientV16UsageTrend(t *testing.T) {
	trend := func(d map[string]any) map[string]any { return d["usageTrend"].(map[string]any) }
	v16Rejects(t, "unknown model", "invalid_client_usage_trend", func(d map[string]any) {
		trend(d)["ranks"].(map[string]any)["not-a-model"] = make([]any, 30)
	})
	v16Rejects(t, "short series", "invalid_client_usage_trend", func(d map[string]any) {
		r := trend(d)["ranks"].(map[string]any)
		for k, v := range r {
			r[k] = v.([]any)[1:]
			break
		}
	})
	v16Rejects(t, "over 8192 bytes", "invalid_client_usage_trend", func(d map[string]any) {
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
	for name, edit := range map[string]func(u map[string]any){
		"zero days":   func(u map[string]any) { u["days"] = 0 },
		"91 days":     func(u map[string]any) { u["days"] = 91 },
		"source":      func(u map[string]any) { u["source"] = "openrouter" },
		"asOf":        func(u map[string]any) { u["asOf"] = "18 Nov 2026" },
		"rank 0":      func(u map[string]any) { u["ranks"].(map[string]any)["astra"].([]any)[0] = 0 },
		"unknown key": func(u map[string]any) { u["extra"] = true },
	} {
		v16Rejects(t, name, "invalid_client_usage_trend", func(d map[string]any) { edit(trend(d)) })
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

func TestClientV16APIPriceMultiplierIsAboveOne(t *testing.T) {
	for _, v := range []any{1, 0.5, 0, "2", nil} {
		if _, err := v16Parse(t, func(d map[string]any) { d["speedTiers"].([]any)[0].(map[string]any)["apiPriceMultiplier"] = v }); err == nil {
			t.Fatalf("apiPriceMultiplier %v accepted", v)
		}
	}
	if _, err := v16Parse(t, func(d map[string]any) { d["speedTiers"].([]any)[0].(map[string]any)["apiPriceMultiplier"] = 1.5 }); err != nil {
		t.Fatal(err)
	}
}

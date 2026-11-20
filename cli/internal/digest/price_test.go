// SPDX-License-Identifier: MIT
package digest

import (
	"os"
	"strings"
	"testing"
)

func loadPriceFixture(t *testing.T) []byte {
	t.Helper()
	b, err := os.ReadFile("testdata/client-v1.6-prices.json")
	if err != nil {
		t.Fatal(err)
	}
	return b
}

// WP-06 / COST-50: the client-v1.6 price fields, read per model. A bad price drops that
// model's price only; the publication and every other model's price stay.
func TestClientV16PricesAreReadPerModel(t *testing.T) {
	d, err := Parse("client", loadPriceFixture(t))
	if err != nil {
		t.Fatal(err)
	}
	opus := d.Price("opus")
	if opus == nil || opus.Input != 5 || opus.Output != 25 || opus.CacheRead == nil || *opus.CacheRead != 0.5 || opus.CacheWrite == nil || *opus.CacheWrite != 6.25 || opus.Source != "litellm" || opus.AsOf != "2026-11-19" {
		t.Fatalf("opus price = %+v", opus)
	}
	if lc := opus.LongContext; lc == nil || lc.AboveInputTokens != 200000 || lc.Input != 10 || lc.Output != 37.5 || *lc.CacheRead != 1 || *lc.CacheWrite != 12.5 {
		t.Fatalf("opus long context = %+v", opus.LongContext)
	}
	sol := d.Price("sol")
	if sol == nil || sol.CacheWrite != nil || sol.LongContext != nil || *sol.CacheRead != 0.125 || sol.Source != "modelsdev" {
		t.Fatalf("sol price = %+v (unknown cache write must stay unknown)", sol)
	}
	if d.Price("glm") != nil {
		t.Fatal("a model without a public price got one")
	}
	if d.Price("kimi") != nil || d.Price("mimo") != nil {
		t.Fatal("an invalid price was kept")
	}
	if d.Price("missing") != nil {
		t.Fatal("unknown model priced")
	}
	if d.Model("kimi").Evaluation != EvaluationPending || d.Model("mimo").Evaluation != "" || d.Model("opus").Evaluation != "" {
		t.Fatalf("evaluation = %q %q %q", d.Model("kimi").Evaluation, d.Model("mimo").Evaluation, d.Model("opus").Evaluation)
	}
	if d.PriceUnit != PriceUnitUSDPer1M {
		t.Fatalf("price unit = %q", d.PriceUnit)
	}
}

func TestClientV16APIPriceMultiplierOnlyWhenPublished(t *testing.T) {
	d, err := Parse("client", loadPriceFixture(t))
	if err != nil {
		t.Fatal(err)
	}
	if m := d.APIPriceMultiplier("opus", "claude-code", "fast"); m == nil || *m != 6 {
		t.Fatalf("claude fast multiplier = %v", m)
	}
	if d.APIPriceMultiplier("sol", "codex", "fast") != nil {
		t.Fatal("a subscription ratio was used as an API price multiplier")
	}
	if d.APIPriceMultiplier("sol", "codex", "ultrafast") != nil {
		t.Fatal("an invalid multiplier was kept")
	}
	if d.APIPriceMultiplier("opus", "codex", "fast") != nil || d.APIPriceMultiplier("glm", "claude-code", "fast") != nil {
		t.Fatal("multiplier leaked to another harness or model")
	}
}

// Prices below client-v1.6, or under another or a missing unit, are a publication-level
// violation of the client-v1.6 contract (clientv16.go): the reader rejects the publication.
func TestPricesNeedClientV16AndTheAgreedUnit(t *testing.T) {
	b := string(loadPriceFixture(t))
	for name, raw := range map[string]string{
		"older projection": strings.Replace(b, `"client-v1.6"`, `"client-v1.5"`, 1),
		"other unit":       strings.Replace(b, `"usd-per-1m-tokens"`, `"usd-per-1k-tokens"`, 1),
		"no unit":          strings.Replace(b, `"priceUnit":"usd-per-1m-tokens",`, ``, 1),
	} {
		if d, err := Parse("client", []byte(raw)); err == nil {
			t.Fatalf("%s: publication accepted with prices %+v", name, d.Price("opus"))
		}
	}
	later := strings.Replace(b, `"client-v1.6"`, `"client-v1.12"`, 1)
	if d, err := Parse("client", []byte(later)); err != nil || d.Price("opus") == nil {
		t.Fatalf("a later v1.x lost its prices: %v", err)
	}
}

func TestInvalidLongContextDropsThatPrice(t *testing.T) {
	b := string(loadPriceFixture(t))
	for name, raw := range map[string]string{
		"zero threshold":     strings.Replace(b, `"aboveInputTokens":200000`, `"aboveInputTokens":0`, 1),
		"fractional":         strings.Replace(b, `"aboveInputTokens":200000`, `"aboveInputTokens":200000.5`, 1),
		"missing output":     strings.Replace(b, `"output":37.5,`, ``, 1),
		"negative cache":     strings.Replace(b, `"cacheRead":1,`, `"cacheRead":-1,`, 1),
		"null cache read":    strings.Replace(b, `"cacheRead":0.5,`, `"cacheRead":null,`, 1),
		"bad date":           strings.Replace(b, `"asOf":"2026-11-19",`, `"asOf":"yesterday",`, 1),
		"no source":          strings.Replace(b, `"source":"litellm","asOf":"2026-11-19",`, `"asOf":"2026-11-19",`, 1),
		"string input price": strings.Replace(b, `"input":5,`, `"input":"5",`, 1),
	} {
		d, err := Parse("client", []byte(raw))
		if err != nil {
			t.Fatalf("%s: publication rejected: %v", name, err)
		}
		if d.Price("opus") != nil {
			t.Fatalf("%s: price kept: %+v", name, d.Price("opus"))
		}
		if d.Price("sol") == nil {
			t.Fatalf("%s: another model's price was dropped", name)
		}
	}
}

func TestPublicationWithoutPricesIsUnchanged(t *testing.T) {
	d, err := Parse("client", []byte(`{"schemaVersion":1,"kind":"client","data":{"units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},"models":[{"id":"opus","name":"Claude Opus 5.5","developerId":"anthropic","recommended":"medium","harnessIds":{"api":[]},"efforts":[{"effort":"medium","label":"Med","ability":null,"cost":null,"time":null}]}],"lineups":[],"resets":[],"windows":[]}}`))
	if err != nil || d.Price("opus") != nil || d.PriceUnit != "" {
		t.Fatalf("legacy publication: %v %+v", err, d)
	}
}

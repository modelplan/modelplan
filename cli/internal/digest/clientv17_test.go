package digest

import (
	"math"
	"testing"
)

// client-v1.7 (modelplans #781, design A'): ability compares models on the ability index; a step within one model
// reads the published within-model chain. Built from the v1.6 example, whose ability is that chain.
func v17(d map[string]any) {
	d["projectionVersion"] = "client-v1.7"
	for _, m := range d["models"].([]any) {
		for _, e := range m.(map[string]any)["efforts"].([]any) {
			e := e.(map[string]any)
			e["abilityWithinModel"] = e["ability"]
			if e["abilityBasis"] == "abilityWithinModel" {
				e["abilityBasis"] = "abilityIndex"
			}
		}
	}
}

func effortOf(t *testing.T, d *Digest, model, effort string) *Effort {
	t.Helper()
	m := d.Model(model)
	if m == nil || m.Effort(effort) == nil {
		t.Fatalf("%s %s missing", model, effort)
	}
	return m.Effort(effort)
}

func near(t *testing.T, name string, got *float64, want float64) {
	t.Helper()
	if got == nil || math.Abs(*got-want) > 1e-9 {
		t.Fatalf("%s = %v, want %v", name, got, want)
	}
}

func TestGainReadsAbilityBeforeClientV17(t *testing.T) {
	d, err := v16Parse(t, func(d map[string]any) {
		// A chain field below v1.7 is not part of that projection: dropped, never read.
		e := exampleModel(d, "astra")["efforts"].([]any)[4].(map[string]any)
		e["abilityWithinModel"] = 0.0
	})
	if err != nil {
		t.Fatal(err)
	}
	xhigh, max := effortOf(t, d, "astra", "xhigh"), effortOf(t, d, "astra", "max")
	if xhigh.Chained || max.Chained || max.AbilityWithinModel != nil {
		t.Fatal("a v1.6 effort is chained")
	}
	near(t, "v1.6 gain", Gain(xhigh, max), *max.Ability-*xhigh.Ability)
}

func TestGainReadsTheChainFromClientV17(t *testing.T) {
	d, err := v16Parse(t, func(d map[string]any) {
		v17(d)
		efforts := exampleModel(d, "astra")["efforts"].([]any)
		// The cross-model index falls from XHigh to Max while the same-source chain still rises (+1.58).
		efforts[3].(map[string]any)["ability"], efforts[3].(map[string]any)["abilityWithinModel"] = 50.2, 46.0
		efforts[4].(map[string]any)["ability"], efforts[4].(map[string]any)["abilityWithinModel"] = 48.79, 47.58
		// No bridge reaches Low; a malformed chain value is dropped, never the publication.
		efforts[0].(map[string]any)["abilityWithinModel"] = nil
		efforts[1].(map[string]any)["abilityWithinModel"] = "67"
	})
	if err != nil {
		t.Fatal(err)
	}
	low, medium, xhigh, max := effortOf(t, d, "astra", "low"), effortOf(t, d, "astra", "medium"), effortOf(t, d, "astra", "xhigh"), effortOf(t, d, "astra", "max")
	if !max.Chained || *max.Ability > *xhigh.Ability {
		t.Fatal("fixture")
	}
	near(t, "v1.7 gain", Gain(xhigh, max), 1.58)
	if Gain(low, xhigh) != nil || Gain(xhigh, low) != nil {
		t.Fatal("a missing bridge has a gain")
	}
	if medium.AbilityWithinModel != nil || Gain(medium, max) != nil {
		t.Fatal("a malformed chain value was kept")
	}
	if Gain(nil, max) != nil {
		t.Fatal("nil effort")
	}
}

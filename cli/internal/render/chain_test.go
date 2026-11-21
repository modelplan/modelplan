package render

import (
	"bytes"
	"encoding/json"
	"os"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

// client-v1.7: the effort ladder prints each effort's cross-model ability, but its steps and its "against ★"
// brackets read the published within-model chain, so a step whose index value falls can still be a gain.
func TestEffortLadderStepsReadTheChain(t *testing.T) {
	data, err := os.ReadFile("../../../testdata/client-v1.6/example.json")
	if err != nil {
		t.Fatal(err)
	}
	var d map[string]any
	if err := json.Unmarshal(data, &d); err != nil {
		t.Fatal(err)
	}
	d["projectionVersion"] = "client-v1.7"
	for _, m := range d["models"].([]any) {
		m := m.(map[string]any)
		for i, e := range m["efforts"].([]any) {
			e := e.(map[string]any)
			e["abilityWithinModel"], e["abilityBasis"] = e["ability"], "abilityIndex"
			if m["id"] == "astra" && e["effort"] == "max" {
				e["ability"], e["abilityWithinModel"] = 70.0, 73.6 // index below XHigh (72.0), chain +1.58 above it
			}
			if m["id"] == "astra" && i == 0 {
				e["abilityWithinModel"] = nil // Low: no bridge
			}
		}
	}
	b, _ := json.Marshal(map[string]any{"schemaVersion": 1, "kind": "client", "data": d})
	pub, err := digest.Parse("client", b)
	if err != nil {
		t.Fatal(err)
	}
	var out bytes.Buffer
	Style{T: EN}.Effort(&out, pub.Model("astra"))
	lines := strings.Split(out.String(), "\n")
	var max, low string
	for _, l := range lines {
		if strings.Contains(l, "Max ") {
			max = l
		}
		if strings.Contains(l, "Low ") {
			low = l
		}
	}
	t.Logf("%s", out.String())
	// Max: ability 70.0 on the index, +6.2 against ★ Medium on the chain, +1.6 above XHigh on the chain.
	if !strings.Contains(max, "70.0 (+6.2pts)") || !strings.Contains(max, "↑ +1.6pts") {
		t.Fatalf("max line = %q", max)
	}
	// Low has no chain: its ability is shown, its step against ★ and the step above it are unknown.
	if !strings.Contains(low, "58.6 ") || strings.Contains(low, "58.6 (") {
		t.Fatalf("low line = %q", low)
	}
}

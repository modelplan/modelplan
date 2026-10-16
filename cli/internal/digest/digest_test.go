package digest

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestExactHarnessAndNullableMetrics(t *testing.T) {
	b := []byte(`{"schemaVersion":1,"kind":"client","data":{"units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},"models":[{"id":"opus","name":"Claude Opus 5.5","developerId":"anthropic","recommended":"medium","harnessIds":{"api":["claude-opus-5-5"],"claude-code":["claude-opus-5-5"],"codex":[]},"efforts":[{"effort":"medium","label":"Med","ability":null,"cost":null,"time":null}]}],"lineups":[],"resets":[],"windows":[]}}`)
	d, err := Parse("client", b)
	if err != nil {
		t.Fatal(err)
	}
	if d.Match("claude-code", "claude-opus-5-5") == nil || d.Match("codex", "claude-opus-5-5") != nil || d.Match("claude-code", "Claude Opus 5.5") != nil {
		t.Fatal("unreviewed harness or name was matched")
	}
	if d.Models[0].Rec().Ability != nil || d.Models[0].Rec().Cost != nil || d.Models[0].Rec().Time != nil {
		t.Fatal("unknown metric became zero")
	}
	d.Models[0].HarnessEvidence = &HarnessEvidence{RequiredEndpoints: map[string]string{"claude-code": "https://example.test/custom"}}
	if d.Match("claude-code", "claude-opus-5-5") != nil {
		t.Fatal("conditional alias matched without endpoint context")
	}
	var raw map[string]any
	_ = json.Unmarshal(b, &raw)
	raw["schemaVersion"] = 2
	invalid, _ := json.Marshal(raw)
	if _, err := Parse("client", invalid); err == nil {
		t.Fatal("unsupported schema accepted")
	}
	if _, err := Parse("models", b); err == nil {
		t.Fatal("large fallback accepted")
	}
}

func TestMultiplierContractPreservesZeroAndLegacyAbsence(t *testing.T) {
	raw := map[string]any{"schemaVersion": 1, "kind": "client", "data": map[string]any{"units": map[string]any{"ability": "websiteAbility", "cost": "usdPerReferenceTask", "time": "taskTimeCrossModel"}, "models": []any{}, "lineups": []any{}, "resets": []any{}, "windows": []any{}}}
	b, _ := json.Marshal(raw)
	old, err := Parse("client", b)
	if err != nil || old.Multipliers != nil || old.MultiplierHorizon != nil {
		t.Fatal("legacy absence changed", err)
	}
	data := raw["data"].(map[string]any)
	data["projectionVersion"] = "client-v1.1"
	data["multiplierHorizon"] = map[string]any{"from": "2026-10-11T00:00:00Z", "to": "2026-10-13T00:00:00Z", "selection": "highest-priority-no-stacking"}
	data["multipliers"] = []any{map[string]any{"ruleId": "night", "provider": "zai", "kind": "night", "models": []string{"GLM-5.3-Flash"}, "clients": []string{"ZCode"}, "multiplier": 0, "priority": 30, "status": "CONFIRMED"}}
	b, _ = json.Marshal(raw)
	d, err := Parse("client", b)
	if err != nil || len(d.Multipliers) != 1 || d.Multipliers[0].Multiplier == nil || *d.Multipliers[0].Multiplier != 0 {
		t.Fatal("real zero or contract lost", err)
	}
	delete(data, "multiplierHorizon")
	b, _ = json.Marshal(raw)
	if _, err = Parse("client", b); err == nil {
		t.Fatal("incomplete horizon accepted")
	}
}

func TestSpeedTiersClientV12(t *testing.T) {
	raw := `{"schemaVersion":1,"kind":"client","data":{"projectionVersion":"client-v1.2","multipliers":[],"multiplierHorizon":{"from":"2026-10-15T00:00:00Z","to":"2026-10-17T00:00:00Z","selection":"highest-priority-no-stacking"},
"speedTiers":[{"id":"codex-fast","harness":"codex","tier":"fast","label":"Fast","toggle":"/fast","eligibility":{"plans":["chatgpt-sign-in"],"note":"n"},
"models":[{"vendorModelId":"gpt-6-astra","modelId":"astra","speed":{"ratio":null,"qualifier":"unstated"}},{"vendorModelId":"gpt-6-sol","modelId":null,"speed":{"ratio":null,"qualifier":"unstated"}}],
"billing":[{"account":"subscription","billsTo":"plan-quota","basis":"included-usage","ratio":2.5}],"caveats":[],"sources":["https://example.test"],"reviewedAt":"2026-10-15T06:30:00Z"}],
"units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},"models":[],"lineups":[],"resets":[],"windows":[]}}`
	d, err := Parse("client", []byte(raw))
	if err != nil {
		t.Fatal(err)
	}
	ts := d.SpeedTiers("astra", "codex")
	if len(ts) != 1 || ts[0].Rate("subscription").Ratio != 2.5 || ts[0].Rate("api") != nil || ts[0].Model.Speed.Ratio != nil {
		t.Fatalf("tiers = %+v", ts)
	}
	if len(d.SpeedTiers("astra", "claude-code")) != 0 || len(d.SpeedTiers("sol", "")) != 0 {
		t.Fatal("tier leaked to another harness or model")
	}
}

func TestEndpointMatchAndPlanMeteringV13(t *testing.T) {
	for raw, want := range map[string]string{
		"https://api.z.ai/api/anthropic/":          "https://api.z.ai/api/anthropic",
		"https://user:pw@API.Z.AI/api/anthropic?x": "https://api.z.ai/api/anthropic",
		"api.z.ai/api/anthropic":                   "",
		"file:///etc/passwd":                       "",
	} {
		if got := Endpoint(raw); got != want {
			t.Errorf("Endpoint(%q) = %q, want %q", raw, got, want)
		}
	}
	b := []byte(`{"schemaVersion":1,"kind":"client","data":{"projectionVersion":"client-v1.3","multipliers":[],"multiplierHorizon":{"from":"2026-10-16T00:00:00Z","to":"2026-10-18T00:00:00Z","selection":"highest-priority-no-stacking"},"speedTiers":[],
		"planMetering":{"revision":"r1","tokenMix":{"input":0.025},"plans":[
		  {"planId":"zhipu-global-pro","generation":"credits-2026","basis":"token-tariff","basisAssumed":false,"unit":"credits","timeRules":["glm-credits-base"],"pool":null,"rows":[{"modelId":"glm","unitsPerUsd":627.911}]},
		  {"planId":"zhipu-global-pro","generation":"legacy-v2","basis":"per-request","basisAssumed":false,"unit":"requests","timeRules":[],"pool":null,"rows":[{"modelId":"glm","multiplier":1}]},
		  {"planId":"claude-pro","generation":null,"basis":"api-proportional","basisAssumed":true,"unit":null,"timeRules":[],"pool":null,"rows":[],"futureField":1}]},
		"units":{"ability":"websiteAbility","cost":"usdPerReferenceTask","time":"taskTimeCrossModel"},
		"models":[{"id":"glm","name":"GLM-5.3","developerId":"zhipuai","recommended":"max","harnessIds":{"api":["glm-5.3"],"claude-code":["glm-5.3[1m]"],"codex":[]},"harnessEvidence":{"requiredEndpoints":{"claude-code":"https://api.z.ai/api/anthropic"}},"efforts":[{"effort":"max","label":"Max","ability":49.4,"cost":4.2,"time":null}]}],
		"lineups":[],"resets":[],"windows":[]}}`)
	d, err := Parse("client", b)
	if err != nil {
		t.Fatal(err)
	}
	if d.Match("claude-code", "glm-5.3[1m]") != nil || d.MatchAt("claude-code", "https://proxy.example", "glm-5.3[1m]") != nil {
		t.Fatal("GLM matched without its endpoint")
	}
	if m := d.MatchAt("claude-code", "https://api.z.ai/api/anthropic/", "glm-5.3[1m]"); m == nil || !m.ViaEndpoint("claude-code") {
		t.Fatal("GLM through Z.ai not matched")
	}
	if d.Metering("zhipu-global-pro", "") != nil {
		t.Fatal("two generations and none declared: must not pick one")
	}
	if p := d.Metering("zhipu-global-pro", "legacy-v2"); p == nil || p.Basis != BasisRequest || *p.Row("glm").Multiplier != 1 {
		t.Fatalf("legacy-v2 = %+v", p)
	}
	if p := d.Metering("claude-pro", ""); p == nil || !p.BasisAssumed || p.Generation != "" || p.Row("opus") != nil {
		t.Fatalf("claude-pro = %+v", p)
	}
	// A malformed planMetering is dropped, not the publication.
	bad := []byte(strings.Replace(string(b), `"planId":"claude-pro"`, `"planId":""`, 1))
	if d, err := Parse("client", bad); err != nil || d.PlanMetering != nil {
		t.Fatalf("bad metering: %v %+v", err, d.PlanMetering)
	}
}

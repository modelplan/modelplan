package digest

import (
	"encoding/json"
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

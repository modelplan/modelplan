// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appcontract"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestCockpitPublicationSourceRequiresVerifiedLocalCache(t *testing.T) {
	t.Setenv("MODELPLAN_CACHE", t.TempDir())
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	if d, err := loadCockpitPublication(context.Background(), st); err != nil || d != nil {
		t.Fatalf("empty cache: %+v %v", d, err)
	}
	f := newPublicationFixture(t, nil)
	if err := st.PutObject(f.objectHash, f.object); err != nil {
		t.Fatal(err)
	}
	if err := st.PutManifest(f.id, f.manifest); err != nil {
		t.Fatal(err)
	}
	if err := st.SaveState(store.State{PublicationID: f.id, ManifestHash: publicationHash(f.manifest), Component: "client", ComponentHash: f.objectHash}); err != nil {
		t.Fatal(err)
	}
	d, err := loadCockpitPublication(context.Background(), st)
	if err != nil || d == nil || d.PublicationID != f.id || d.PublishedAt != "2026-10-24T12:00:00Z" || len(d.Models) != 2 {
		t.Fatalf("verified source: %+v %v", d, err)
	}
	if err := os.WriteFile(st.ObjectPath(f.objectHash), []byte(`{"invalid":"tampered"}`), 0600); err != nil {
		t.Fatal(err)
	}
	if d, err := loadCockpitPublication(context.Background(), st); err != nil || d != nil {
		t.Fatalf("tampered cache: %+v %v", d, err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := loadCockpitPublication(ctx, st); !errors.Is(err, context.Canceled) {
		t.Fatalf("cancellation: %v", err)
	}
}

func TestPublishedCockpitModelCopiesStarAndDoesNotInventMultiplier(t *testing.T) {
	ability, cost, elapsed := 42.0, 2.0, 1.5
	model := digest.Model{ID: "model", Name: "Synthetic model", DeveloperID: "openai", Recommended: "medium", Efforts: []digest.Effort{{Effort: "low", Label: "Low", Ability: &ability, Cost: &cost, Time: &elapsed}, {Effort: "medium", Label: "Med"}}}
	got, ok := publishedCockpitModel(model)
	if !ok || len(got.Efforts) != 2 {
		t.Fatalf("projection: %+v", got)
	}
	if got.Efforts[0].Star || !got.Efforts[1].Star || got.Efforts[0].Ability != &ability || got.Efforts[0].Cost != &cost || got.Efforts[0].Time != &elapsed || got.Efforts[0].Multiplier != nil || got.Efforts[1].Multiplier != nil {
		t.Fatalf("published effort facts changed: %+v", got)
	}
	raw, err := json.Marshal(got)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(raw, []byte(`"multiplier"`)) {
		t.Fatalf("invented multiplier: %s", raw)
	}
}

func TestEligibleCockpitVendorsRequireCurrentReading(t *testing.T) {
	projection := rows.Projection{Rows: []rows.Row{
		{ID: "codex", Kind: rows.KindTool, Consent: rows.ConsentAllowed, Accounts: []rows.Account{{ValueState: rows.ValueStateCurrent}}},
		{ID: "claude", Kind: rows.KindTool, Consent: rows.ConsentAllowed, Accounts: []rows.Account{{ValueState: rows.ValueStateRetained}}},
		{ID: "gemini", Kind: rows.KindTool, Consent: rows.ConsentAllowed, Accounts: []rows.Account{{ValueState: rows.ValueStateCurrent}}},
		{ID: "cursor", Kind: rows.KindTool, Consent: rows.ConsentAllowed, Accounts: []rows.Account{{ValueState: rows.ValueStateCurrent}}},
	}}
	got := eligibleCockpitVendors(projection)
	if len(got) != 2 || !got["openai"] || !got["google"] || got["anthropic"] {
		t.Fatalf("vendors: %v", got)
	}
}

func TestMaterializeCockpitPublicationPreservesVerifiedFacts(t *testing.T) {
	model := digest.Model{ID: "model", Name: "Synthetic model", DeveloperID: "openai", Recommended: "high", Efforts: []digest.Effort{{Effort: "low", Label: "Low"}, {Effort: "high", Label: "High"}}}
	d := &digest.Digest{Source: digest.ComponentClient, PublicationID: "0123456789abcdef01234567", PublishedAt: "2026-10-24T12:00:00Z"}
	got := materializeCockpitPublication(d, []*digest.Model{&model}, true)
	if got == nil || !got.Truncated || got.Source != "client" || got.PublicationID != d.PublicationID || len(got.Models) != 1 || got.Models[0].Efforts[0].Star || !got.Models[0].Efforts[1].Star {
		t.Fatalf("published facts: %+v", got)
	}
	empty := materializeCockpitPublication(d, nil, false)
	if empty == nil || empty.Models == nil || len(empty.Models) != 0 || empty.Truncated {
		t.Fatalf("empty lineup: %+v", empty)
	}
	d.PublishedAt = "invalid"
	if materializeCockpitPublication(d, nil, false) != nil {
		t.Fatal("invalid publication time admitted")
	}
}

func TestSelectCockpitPublicationUsesCurrentReadingsAndPublicationOrder(t *testing.T) {
	model := func(id, vendor string) digest.Model {
		return digest.Model{ID: id, Name: "Synthetic " + id, DeveloperID: vendor, Recommended: "medium", Efforts: []digest.Effort{{Effort: "low", Label: "Low"}, {Effort: "medium", Label: "Med"}}}
	}
	d := &digest.Digest{Source: digest.ComponentClient, PublicationID: "0123456789abcdef01234567", PublishedAt: "2026-10-24T12:00:00Z", Models: []digest.Model{model("o1", "openai"), model("a1", "anthropic"), model("o2", "openai"), model("o3", "openai"), model("o4", "openai")}}
	p := rows.Projection{Rows: []rows.Row{{ID: "codex", Kind: rows.KindTool, Consent: rows.ConsentAllowed, Accounts: []rows.Account{{ValueState: rows.ValueStateCurrent}}}, {ID: "claude", Kind: rows.KindTool, Consent: rows.ConsentAllowed, Accounts: []rows.Account{{ValueState: rows.ValueStateRetained}}}}}
	got := selectCockpitPublication(d, p, nil)
	if got == nil || !got.Truncated || len(got.Models) != 3 || got.Models[0].ID != "o1" || got.Models[1].ID != "o2" || got.Models[2].ID != "o3" {
		t.Fatalf("filtered lineup: %+v", got)
	}
	for _, m := range got.Models {
		if len(m.Efforts) != 2 || m.Efforts[0].Star || !m.Efforts[1].Star || m.Efforts[1].Multiplier != nil {
			t.Fatalf("efforts: %+v", m.Efforts)
		}
	}
	// CKP-FAD-02: a model in use leads, even one the three-model limit would have cut.
	if used := selectCockpitPublication(d, p, map[string]bool{"o4": true}); used == nil || len(used.Models) != 3 || used.Models[0].ID != "o4" || used.Models[1].ID != "o1" || !used.Truncated {
		t.Fatalf("in-use lineup: %+v", used)
	}
	p.Rows[0].Consent = rows.ConsentDenied
	empty := selectCockpitPublication(d, p, nil)
	if empty == nil || empty.Models == nil || len(empty.Models) != 0 || empty.Truncated {
		t.Fatalf("empty current lineup: %+v", empty)
	}
}

func TestCockpitPublicationRealBinaryIncludesCurrentVendorModels(t *testing.T) {
	for _, explicit := range []bool{true, false} {
		name := "implicit"
		if explicit {
			name = "explicit"
		}
		t.Run(name, func(t *testing.T) { testCockpitPublicationCurrentVendorModels(t, explicit) })
	}
}

func testCockpitPublicationCurrentVendorModels(t *testing.T, explicit bool) {
	t.Helper()
	home := setupQueryHome(t)
	if err := os.MkdirAll(filepath.Join(home, ".codex"), 0700); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC().Truncate(time.Second)
	if explicit {
		if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "codex", true, "native:codex", "native", now) }); err != nil {
			t.Fatal(err)
		}
	}
	state, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	f := newPublicationFixture(t, func(doc map[string]json.RawMessage) {
		var data map[string]json.RawMessage
		if err := json.Unmarshal(doc["data"], &data); err != nil {
			t.Fatal(err)
		}
		model := func(id, dev string) map[string]any {
			return map[string]any{"id": id, "name": "Synthetic " + id, "developerId": dev, "recommended": "medium", "harnessIds": map[string]any{}, "efforts": []any{map[string]any{"effort": "low", "label": "Low", "ability": 40, "cost": 1, "time": nil}, map[string]any{"effort": "medium", "label": "Med", "ability": 50, "cost": 2, "time": nil}}}
		}
		data["models"] = publicationJSON(t, []any{model("openai-1", "openai"), model("anthropic-1", "anthropic"), model("openai-2", "openai"), model("openai-3", "openai"), model("openai-4", "openai")})
		data["lineups"] = json.RawMessage(`[]`)
		doc["data"] = publicationJSON(t, data)
	})
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	if err := st.PutObject(f.objectHash, f.object); err != nil {
		t.Fatal(err)
	}
	if err := st.PutManifest(f.id, f.manifest); err != nil {
		t.Fatal(err)
	}
	if err := st.SaveState(store.State{PublicationID: f.id, ManifestHash: publicationHash(f.manifest), Component: "client", ComponentHash: f.objectHash}); err != nil {
		t.Fatal(err)
	}
	snapshot := map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": now, "admission": state.CaptureStamp(consent.ScopeCodexRuntimeUsage), "windows": []any{map[string]any{"kind": "weekly", "usedPercent": 25, "remainingPercent": 75, "windowMinutes": 10080, "resetsAt": now.Add(time.Hour), "observedAt": now}}}
	path := filepath.Join(home, "cache", "observed", "codex-account.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, publicationJSON(t, snapshot), 0600); err != nil {
		t.Fatal(err)
	}
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	client := startQueryBinaryCaps(t, binary, []string{"rows", "cockpit", "cockpitDetailsV1"})
	response := client.call("cockpit/query", map[string]any{})
	var envelope wire.Envelope[wire.CockpitData]
	if err := json.Unmarshal(response["result"], &envelope); err != nil || envelope.Data.Details == nil || envelope.Data.Details.Publication == nil {
		t.Fatalf("missing publication: %s %s %v", response["result"], response["error"], err)
	}
	wantConsent := rows.ConsentImplicit
	if explicit {
		wantConsent = rows.ConsentAllowed
	}
	foundCodex := false
	for _, row := range envelope.Data.Projection.Rows {
		if row.ID == "codex" {
			foundCodex = true
			if row.Consent != wantConsent || len(row.Accounts) == 0 || row.Accounts[0].ValueState != rows.ValueStateCurrent {
				t.Fatalf("Codex row does not have the expected consent and current reading: %+v", row)
			}
		}
	}
	if !foundCodex {
		t.Fatal("Codex row missing")
	}
	pub := envelope.Data.Details.Publication
	if len(pub.Models) != 3 || !pub.Truncated || pub.Models[0].ID != "openai-1" || pub.Models[1].ID != "openai-2" || pub.Models[2].ID != "openai-3" {
		t.Fatalf("vendor selection: %+v; rows=%+v", pub, envelope.Data.Projection.Rows)
	}
	if pub.Models[0].Efforts[0].Star || !pub.Models[0].Efforts[1].Star || pub.Models[0].Efforts[1].Multiplier != nil {
		t.Fatalf("effort facts: %+v", pub.Models[0].Efforts)
	}
	validator, err := appcontract.NewValidator("../../..")
	if err != nil {
		t.Fatal(err)
	}
	encoded, err := json.Marshal(response)
	if err != nil {
		t.Fatal(err)
	}
	if err := validator.Validate("app-server", encoded); err != nil {
		t.Fatalf("publication response violates schema: %v", err)
	}
}

func TestEligibleCockpitVendorsConsentStates(t *testing.T) {
	for _, provider := range []struct{ tool, vendor string }{{"codex", "openai"}, {"claude", "anthropic"}} {
		for _, tc := range []struct {
			consent rows.Consent
			current bool
			want    bool
		}{
			{rows.ConsentImplicit, true, true}, {rows.ConsentAllowed, true, true},
			{rows.ConsentDenied, true, false}, {rows.ConsentUnset, true, false},
			{rows.ConsentImplicit, false, false}, {rows.ConsentAllowed, false, false},
		} {
			t.Run(provider.tool+"/"+string(tc.consent)+fmt.Sprint("/current=", tc.current), func(t *testing.T) {
				value := rows.ValueStateRetained
				if tc.current {
					value = rows.ValueStateCurrent
				}
				p := rows.Projection{Rows: []rows.Row{{ID: provider.tool, Kind: rows.KindTool, Consent: tc.consent, Accounts: []rows.Account{{ValueState: value}}}}}
				if got := eligibleCockpitVendors(p)[provider.vendor]; got != tc.want {
					t.Fatalf("eligible=%v, want %v", got, tc.want)
				}
			})
		}
	}
}

func TestCockpitPublicationCarriesPublishedSpeedTiers(t *testing.T) {
	const speed = `[{"id":"codex-fast","harness":"codex","tier":"fast","label":"Fast","toggle":"/fast","eligibility":{"plans":["chatgpt-sign-in"],"note":"n"},"models":[{"vendorModelId":"v1","modelId":"m1","speed":{"ratio":1.5,"qualifier":"up-to"}},{"vendorModelId":"v2","modelId":null,"speed":{"ratio":null,"qualifier":"unstated"}}],"billing":[{"account":"subscription","billsTo":"plan-quota","basis":"included-usage","ratio":2}],"caveats":["not-task-time"],"sources":["https://example.test/fast"]}]`
	d := &digest.Digest{Source: digest.ComponentClient, PublicationID: "0123456789abcdef01234567", PublishedAt: "2026-10-24T12:00:00Z"}
	if err := json.Unmarshal([]byte(speed), &d.Speed); err != nil {
		t.Fatal(err)
	}
	got := materializeCockpitPublication(d, nil, false)
	if got == nil || len(got.SpeedTiers) != 1 {
		t.Fatalf("speed tiers dropped: %+v", got)
	}
	out, err := json.Marshal(got.SpeedTiers)
	if err != nil {
		t.Fatal(err)
	}
	var want, have any
	_ = json.Unmarshal([]byte(speed), &want)
	_ = json.Unmarshal(out, &have)
	if !reflect.DeepEqual(want, have) {
		t.Fatalf("shape changed:\n%s\n%s", speed, out)
	}
	for _, none := range [][]digest.SpeedTier{nil, {}} {
		d.Speed = none
		got = materializeCockpitPublication(d, nil, false)
		raw, _ := json.Marshal(got)
		if got == nil || len(got.SpeedTiers) != 0 || bytes.Contains(raw, []byte("speedTiers")) {
			t.Fatalf("empty speed tiers must be absent: %s", raw)
		}
	}
	bad := math.Inf(1)
	d.Speed = []digest.SpeedTier{{ID: "x", Billing: []digest.SpeedBilling{{Ratio: bad}}}}
	if got = materializeCockpitPublication(d, nil, false); got == nil || len(got.SpeedTiers) != 0 {
		t.Fatalf("non-finite tier admitted: %+v", got)
	}
}

func TestCockpitPlanModelsCopyOnlyPublishedPlanLists(t *testing.T) {
	d := &digest.Digest{Source: digest.ComponentClient, PlanModels: &digest.PlanModels{Plans: []digest.PlanModelList{
		{PlanID: "openai-plus", Generation: "current", Basis: "access", ModelIDs: []string{"astra", "gone", "sol"}},
		{PlanID: "claude-pro", Basis: "listing", ModelIDs: []string{"gone"}},
		{PlanID: "cursor-pro", Basis: "invented", ModelIDs: []string{"astra"}},
	}}}
	published := []wire.CockpitPublicationModel{{ID: "astra"}, {ID: "sol"}}
	got := cockpitPlanModels(d, published)
	want := []wire.CockpitPlanModels{{PlanID: "openai-plus", Generation: "current", Basis: "access", ModelIDs: []string{"astra", "sol"}}}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("got %+v, want %+v", got, want)
	}
	// An older publication has no planModels: nothing is invented.
	if cockpitPlanModels(&digest.Digest{Source: digest.ComponentClient}, published) != nil || cockpitPlanModels(nil, published) != nil {
		t.Fatal("a publication without planModels must yield none")
	}
}

func TestReportedModelsMapThroughPublishedHarnessAliases(t *testing.T) {
	d := &digest.Digest{Source: digest.ComponentClient, Models: []digest.Model{
		{ID: "astra", HarnessIDs: map[string][]string{"codex": {"native-astra", "native-astra-old"}}},
		{ID: "sol", HarnessIDs: map[string][]string{"codex": {"native-sol"}}},
		{ID: "opus", HarnessIDs: map[string][]string{"claude-code": {"native-astra"}}},
		{ID: "unpublished", HarnessIDs: map[string][]string{"codex": {"native-x"}}},
	}}
	published := []wire.CockpitPublicationModel{{ID: "astra"}, {ID: "sol"}, {ID: "opus"}}
	got := reportedPublishedModels(d, "codex", []string{"native-astra-old", "native-x", "native-unknown"}, published)
	if !reflect.DeepEqual(got, []string{"astra"}) {
		t.Fatalf("got %v: only a codex alias of a published model maps; unknown ids are dropped, not guessed", got)
	}
	if reportedPublishedModels(d, "codex", []string{"native-unknown"}, published) != nil || reportedPublishedModels(nil, "codex", []string{"native-sol"}, published) != nil {
		t.Fatal("nothing maps: nothing reported")
	}
}

func TestReportedModelsMapUnderEachToolKey(t *testing.T) {
	if reportedHarnessKey("native:gemini") != "gemini" || reportedHarnessKey("claude-code") != "claude-code" || reportedHarnessKey("codex") != "codex" {
		t.Fatal("tool key")
	}
	d := &digest.Digest{Source: digest.ComponentClient, Models: []digest.Model{
		{ID: "flash", HarnessIDs: map[string][]string{"gemini": {"gemini-2.5-flash"}, "copilot": {}}},
		{ID: "gpt", HarnessIDs: map[string][]string{"copilot": {"gpt-5.1"}}},
	}}
	published := []wire.CockpitPublicationModel{{ID: "flash"}, {ID: "gpt"}}
	if got := reportedPublishedModels(d, reportedHarnessKey("native:gemini"), []string{"gemini-2.5-flash", "gpt-5.1"}, published); !reflect.DeepEqual(got, []string{"flash"}) {
		t.Fatalf("got %v: an id maps only under its own tool key", got)
	}
	// No harnessIds published for the tool yet: nothing maps, the plan list stays.
	if reportedPublishedModels(d, reportedHarnessKey("native:grok"), []string{"grok-build-1"}, published) != nil {
		t.Fatal("unmapped ids must be dropped")
	}
}

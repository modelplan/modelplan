// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"testing"

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

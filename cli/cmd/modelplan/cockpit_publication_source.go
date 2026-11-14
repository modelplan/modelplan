// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"math"
	"time"
	"unicode"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// loadCockpitPublication reads only the verified, local publication cache.
// Unavailable and unverifiable data have the same absent result; cancellation
// remains observable to the caller. It does not fetch or write publication data.
func loadCockpitPublication(ctx context.Context, st *store.Store) (*digest.Digest, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if st == nil {
		return nil, nil
	}
	d, _, err := publication.Load(st)
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if err != nil {
		return nil, nil
	}
	return d, nil
}

// publishedCockpitModel copies public verdicts without calculating a rank,
// multiplier or recommendation. Missing published values stay unknown.
func publishedCockpitModel(m digest.Model) (wire.CockpitPublicationModel, bool) {
	validText := func(s string, limit int, required bool) bool {
		if len(s) > limit || (required && s == "") {
			return false
		}
		for _, r := range s {
			if unicode.IsControl(r) {
				return false
			}
		}
		return true
	}
	if !validText(m.ID, 128, true) || !validText(m.Name, 200, true) || !validText(m.DeveloperID, 128, true) || !validText(m.Recommended, 64, false) || len(m.Efforts) > 32 {
		return wire.CockpitPublicationModel{}, false
	}
	out := wire.CockpitPublicationModel{ID: m.ID, Name: m.Name, DeveloperID: m.DeveloperID, Recommended: m.Recommended, Efforts: []wire.CockpitPublicationEffort{}}
	for _, e := range m.Efforts {
		if !validText(e.Effort, 64, true) || !validText(e.Label, 64, false) {
			return wire.CockpitPublicationModel{}, false
		}
		for _, value := range []*float64{e.Ability, e.Cost, e.Time} {
			if value != nil && (math.IsNaN(*value) || math.IsInf(*value, 0)) {
				return wire.CockpitPublicationModel{}, false
			}
		}
		out.Efforts = append(out.Efforts, wire.CockpitPublicationEffort{Effort: e.Effort, Label: e.Label, Star: m.Recommended != "" && e.Effort == m.Recommended, Ability: e.Ability, Cost: e.Cost, Time: e.Time, Provisional: e.Provisional})
	}
	return out, true
}

// eligibleCockpitVendors uses only current consent-fenced row readings. Multi-
// vendor aggregators are intentionally absent: their own account is not proof
// of a particular model vendor's entitlement or current reading.
func eligibleCockpitVendors(projection rows.Projection) map[string]bool {
	vendors := map[string]string{"codex": "openai", "claude": "anthropic", "gemini": "google", "grok": "xai", "kimi": "kimi", "zai": "zhipuai", "minimax": "minimax", "qwen": "alibaba"}
	out := map[string]bool{}
	for _, row := range projection.Rows {
		vendor := vendors[row.ID]
		if row.Kind != rows.KindTool || (row.Consent != rows.ConsentAllowed && row.Consent != rows.ConsentImplicit) || vendor == "" {
			continue
		}
		for _, account := range row.Accounts {
			if account.ValueState == rows.ValueStateCurrent {
				out[vendor] = true
				break
			}
		}
	}
	return out
}

// materializeCockpitPublication encodes an already-selected publication lineup
// without ranking it or manufacturing values. Invalid source facts fail closed.
func materializeCockpitPublication(d *digest.Digest, selected []*digest.Model, truncated bool) *wire.CockpitPublication {
	if d == nil || d.Source != digest.ComponentClient || len(d.PublicationID) != 24 || len(selected) > 3 {
		return nil
	}
	for _, ch := range d.PublicationID {
		if !(ch >= '0' && ch <= '9' || ch >= 'a' && ch <= 'f') {
			return nil
		}
	}
	publishedAt, err := time.Parse(time.RFC3339Nano, d.PublishedAt)
	if err != nil || publishedAt.IsZero() {
		return nil
	}
	result := &wire.CockpitPublication{ContractVersion: 1, PublicationID: d.PublicationID, PublishedAt: publishedAt.UTC(), Source: d.Source, Models: []wire.CockpitPublicationModel{}, Truncated: truncated}
	seen := map[string]bool{}
	for _, model := range selected {
		if model == nil || seen[model.ID] {
			return nil
		}
		converted, ok := publishedCockpitModel(*model)
		if !ok {
			return nil
		}
		result.Models = append(result.Models, converted)
		seen[model.ID] = true
	}
	result.SpeedTiers = publishedSpeedTiers(d.Speed)
	return result
}

// publishedSpeedTiers copies the published speedTiers verbatim (shape of client data.speedTiers). Tiers with
// non-finite numbers are skipped; more than 32 tiers are cut. Nil when nothing is published.
func publishedSpeedTiers(in []digest.SpeedTier) []wire.CockpitSpeedTier {
	var out []wire.CockpitSpeedTier
	finite := func(v float64) bool { return !math.IsNaN(v) && !math.IsInf(v, 0) }
	strs := func(v []string) []string { return append([]string{}, v...) }
tiers:
	for _, t := range in {
		if len(out) == 32 {
			break
		}
		c := wire.CockpitSpeedTier{ID: t.ID, Harness: t.Harness, Tier: t.Tier, Label: t.Label, Toggle: t.Toggle,
			Eligibility: wire.CockpitSpeedEligibility{Plans: strs(t.Eligibility.Plans), Note: t.Eligibility.Note},
			Models:      []wire.CockpitSpeedTierModel{}, Billing: []wire.CockpitSpeedBilling{}, Caveats: strs(t.Caveats), Sources: strs(t.Sources)}
		for _, m := range t.Models {
			if m.Speed.Ratio != nil && !finite(*m.Speed.Ratio) {
				continue tiers
			}
			c.Models = append(c.Models, wire.CockpitSpeedTierModel{VendorModelID: m.VendorModelID, ModelID: m.ModelID, Speed: wire.CockpitSpeedRatio{Ratio: m.Speed.Ratio, Qualifier: m.Speed.Qualifier}})
		}
		for _, b := range t.Billing {
			if !finite(b.Ratio) {
				continue tiers
			}
			c.Billing = append(c.Billing, wire.CockpitSpeedBilling{Account: b.Account, BillsTo: b.BillsTo, Basis: b.Basis, Ratio: b.Ratio})
		}
		if len(c.Models) > 256 || len(c.Billing) > 8 || len(c.Caveats) > 16 || len(c.Sources) > 16 || len(c.Eligibility.Plans) > 32 {
			continue
		}
		out = append(out, c)
	}
	return out
}

// allCockpitModels lists every published model that passes the same checks as the lineup, in
// publication order. An invalid model is left out rather than failing the whole list.
func allCockpitModels(d *digest.Digest) []wire.CockpitPublicationModel {
	out := []wire.CockpitPublicationModel{}
	if d == nil || d.Source != digest.ComponentClient {
		return out
	}
	seen := map[string]bool{}
	for i := range d.Models {
		if len(out) == 256 {
			break
		}
		if converted, ok := publishedCockpitModel(d.Models[i]); ok && !seen[converted.ID] {
			seen[converted.ID] = true
			out = append(out, converted)
		}
	}
	return out
}

// cockpitPlanModels copies the published plan model lists, keeping only models in the published list
// above and plans that still have one. Nothing is inferred; an older publication yields none.
func cockpitPlanModels(d *digest.Digest, published []wire.CockpitPublicationModel) []wire.CockpitPlanModels {
	if d == nil || d.Source != digest.ComponentClient || d.PlanModels == nil {
		return nil
	}
	known := map[string]bool{}
	for _, m := range published {
		known[m.ID] = true
	}
	var out []wire.CockpitPlanModels
	for _, p := range d.PlanModels.Plans {
		if len(out) == 128 || p.PlanID == "" || len(p.PlanID) > 128 || len(p.Generation) > 128 || (p.Basis != "access" && p.Basis != "listing") {
			continue
		}
		ids := []string{}
		for _, id := range p.ModelIDs {
			if known[id] && len(ids) < 256 {
				ids = append(ids, id)
			}
		}
		if len(ids) > 0 {
			out = append(out, wire.CockpitPlanModels{PlanID: p.PlanID, Generation: p.Generation, Basis: p.Basis, ModelIDs: ids})
		}
	}
	return out
}

// selectCockpitPublication puts the models in use first, then keeps the verified models array's
// publication order; it does not calculate a cross-vendor score or a synthetic ranking.
func selectCockpitPublication(d *digest.Digest, projection rows.Projection, inUse map[string]bool) *wire.CockpitPublication {
	if d == nil {
		return nil
	}
	vendors := eligibleCockpitVendors(projection)
	eligible := make([]*digest.Model, 0, len(d.Models))
	for _, used := range []bool{true, false} {
		for i := range d.Models {
			model := &d.Models[i]
			if vendors[model.DeveloperID] && inUse[model.ID] == used {
				eligible = append(eligible, model)
			}
		}
	}
	return materializeCockpitPublication(d, eligible[:min(3, len(eligible))], len(eligible) > 3)
}

package advise

import (
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Plan is the plan behind a harness session on another vendor's endpoint (Claude Code on Z.ai
// runs GLM on the user's Zhipu plan, not on Claude's), as the user declared it in local.json,
// with how the publication says that plan counts use (client-v1.3 planMetering).
type Plan struct {
	ID           string `json:"planId"`
	Generation   string `json:"generation,omitempty"`
	Basis        string `json:"basis"`
	BasisAssumed bool   `json:"basisAssumed,omitempty"`
	Unit         string `json:"unit,omitempty"`

	m     *digest.MeteredPlan
	d     *digest.Digest
	rules map[string]bool
}

// vendorReading: the CodexBar provider that reads a developer's plan, for a declared plan
// without windows of its own.
var vendorReading = map[string]string{"zhipuai": "codexbar:zai"}

// Link resolves the plan behind a harness account whose model needs a custom endpoint: the one
// declared plan (local.json) that meters that model. The returned account is the session with
// that plan's windows when the session reports none (Z.ai's endpoint passes no usage to Claude
// Code): the declared plan's own windows, else the vendor's reading through CodexBar. Without
// exactly one such plan the account comes back unchanged and the plan is nil: never a guess.
func Link(a *quota.Account, r quota.Report, d *digest.Digest) (quota.Account, *Plan) {
	cfg := current(a, d)
	hn := harnessOf(a.Source)
	if cfg.model == nil || !cfg.model.ViaEndpoint(hn) {
		return *a, nil
	}
	var p *Plan
	var from *quota.Account
	for i := range r.Accounts {
		u := &r.Accounts[i]
		if u.Source != "user" || u.Plan == "" {
			continue
		}
		m := d.Metering(u.Plan, u.Generation)
		if m.Row(cfg.model.ID) == nil {
			continue
		}
		if p != nil {
			return *a, nil // two declared plans meter this model: which one pays is not known
		}
		p, from = newPlan(u.Plan, m, d), u
	}
	if p == nil {
		return *a, nil
	}
	eff := *a
	eff.Plan = p.ID
	if len(a.Windows) == 0 {
		src := from
		if len(from.Windows) == 0 {
			src = nil
			for i := range r.Accounts {
				if r.Accounts[i].Source == vendorReading[cfg.model.DeveloperID] {
					src = &r.Accounts[i]
				}
			}
		}
		if src != nil {
			eff.Windows, eff.Headroom, eff.Deciding, eff.Stale = src.Windows, src.Headroom, src.Deciding, src.Stale
		}
	}
	return eff, p
}

func newPlan(id string, m *digest.MeteredPlan, d *digest.Digest) *Plan {
	p := &Plan{ID: id, Generation: m.Generation, Basis: m.Basis, BasisAssumed: m.BasisAssumed, Unit: m.Unit, m: m, d: d, rules: map[string]bool{}}
	for _, r := range m.TimeRules {
		p.rules[r] = true
	}
	return p
}

// applies: a published multiplier window for this plan and model. The plan's own time rules
// name their windows by ruleId; a plan without metering falls back to the windows' planIds.
// Client-only windows (ZCode) never apply to a Claude Code or Codex session.
func (p *Plan) applies(w *digest.MultiplierWindow, m *digest.Model) bool {
	return p.appliesTo(w) && (len(w.Models) == 0 || contains(w.Models, m.Name) || contains(w.Models, m.ID))
}

// appliesTo: the window is this plan's (and generation's), for any model.
func (p *Plan) appliesTo(w *digest.MultiplierWindow) bool {
	if len(w.Clients) > 0 {
		return false
	}
	if len(p.rules) > 0 && !p.rules[w.RuleID] || len(p.rules) == 0 && !contains(w.PlanIDs, p.ID) {
		return false
	}
	return p.Generation == "" || len(w.Generations) == 0 || contains(w.Generations, p.Generation)
}

// rate: the time-of-day multiplier for the model at t; 1 for a plan without time rules, nil
// when the plan has rules but none is published for t, or they conflict.
func (p *Plan) rate(m *digest.Model, t time.Time) *float64 {
	if len(p.rules) == 0 {
		one := 1.0
		return &one
	}
	r, _ := rateAt(p.d.Multipliers, func(w *digest.MultiplierWindow) bool { return p.applies(w, m) }, t)
	return r
}

// cost: one reference task at (m, e) in the plan's units at t, comparable only within this
// plan; nil when the plan gives no number. cross: m is not the session's model.
func (p *Plan) cost(m *digest.Model, e *digest.Effort, t time.Time, cross bool) *float64 {
	row := p.m.Row(m.ID)
	rate := p.rate(m, t)
	if row == nil || rate == nil {
		return nil
	}
	var v float64
	switch p.Basis {
	case digest.BasisRequest:
		if row.Multiplier == nil {
			return nil
		}
		v = *row.Multiplier
	case digest.BasisAPI, digest.BasisTariff, digest.BasisRelative, digest.BasisPool:
		if e == nil || e.Cost == nil || (p.Basis == digest.BasisPool && cross) {
			return nil
		}
		v = *e.Cost
		switch {
		case p.Basis == digest.BasisTariff && row.UnitsPerUSD != nil:
			v *= *row.UnitsPerUSD
		case p.Basis == digest.BasisTariff || p.Basis == digest.BasisRelative:
			if row.Multiplier == nil {
				return nil
			}
			v *= *row.Multiplier
		}
	default:
		return nil
	}
	v *= *rate
	return &v
}

// cheaperLater: the first published time before `until` when the model's rate drops below the
// current one (an off-peak start), within the multiplier horizon.
func (p *Plan) cheaperLater(m *digest.Model, now, until time.Time) (*time.Time, *float64, *float64) {
	cur := p.rate(m, now)
	if cur == nil || len(p.rules) == 0 {
		return nil, nil, nil
	}
	var bounds []time.Time
	for i := range p.d.Multipliers {
		w := &p.d.Multipliers[i]
		if !p.applies(w, m) {
			continue
		}
		for _, s := range []string{w.StartsAt, w.EndsAt} {
			if t, err := time.Parse(time.RFC3339, s); err == nil && t.After(now) && t.Before(until) {
				bounds = append(bounds, t)
			}
		}
	}
	sort.Slice(bounds, func(i, j int) bool { return bounds[i].Before(bounds[j]) })
	for _, t := range bounds {
		if r := p.rate(m, t); r != nil && *r < *cur {
			t := t.UTC()
			return &t, cur, r
		}
	}
	return nil, nil, nil
}

// offpeakWait: how far ahead an off-peak start is worth waiting for on a tight window.
const offpeakWait = 3 * time.Hour

// Rates is what the plan charges for each model it meters that this harness can run, now.
type PlanRate struct {
	Model       string   `json:"model"`
	UnitsPerUSD *float64 `json:"unitsPerUsd,omitempty"`
	Multiplier  *float64 `json:"multiplier,omitempty"`
	Amount      *float64 `json:"amount,omitempty"`
	Now         *float64 `json:"now"` // time-of-day multiplier now; nil when not published
}

func (p *Plan) Rates(harness string, now time.Time) []PlanRate {
	var out []PlanRate
	for _, r := range p.m.Rows {
		m := p.d.Model(r.ModelID)
		if m == nil || len(m.HarnessIDs[harness]) == 0 {
			continue
		}
		out = append(out, PlanRate{Model: m.Name, UnitsPerUSD: r.UnitsPerUSD, Multiplier: r.Multiplier, Amount: r.Amount, Now: p.rate(m, now)})
	}
	return out
}

// planOf: the declared plan's metering, for a user account's own rate hints.
func planOf(a *quota.Account, d *digest.Digest) *Plan {
	if a.Source != "user" || a.Plan == "" {
		return nil
	}
	if m := d.Metering(a.Plan, a.Generation); m != nil {
		return newPlan(a.Plan, m, d)
	}
	return nil
}

// linkedPlans: the plan accounts a harness session stands for, so their windows are not
// advised twice.
func linkedPlans(r quota.Report, d *digest.Digest) map[string]bool {
	out := map[string]bool{}
	for i := range r.Accounts {
		if _, p := Link(&r.Accounts[i], r, d); p != nil {
			out[strings.ToLower(p.ID)] = true
		}
	}
	return out
}

// Undeclared: a harness session on a model reached through another vendor's endpoint, with no
// declared plan it can be linked to. Returns the model and the published plans that meter it
// (with their generations), so the user can be asked which one they have; nil otherwise.
func Undeclared(a *quota.Account, r quota.Report, d *digest.Digest) (*digest.Model, []digest.MeteredPlan) {
	cfg := current(a, d)
	if cfg.model == nil || !cfg.model.ViaEndpoint(harnessOf(a.Source)) || d.PlanMetering == nil {
		return nil, nil
	}
	if _, p := Link(a, r, d); p != nil {
		return nil, nil
	}
	var out []digest.MeteredPlan
	for _, p := range d.PlanMetering.Plans {
		if p.Row(cfg.model.ID) != nil {
			out = append(out, p)
		}
	}
	if len(out) == 0 {
		return nil, nil
	}
	return cfg.model, out
}

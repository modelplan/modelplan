package advise

import (
	"encoding/json"
	"sort"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// RatePoint is a selected published rate, never a product of overlapping rules.
// A nil multiplier is unknown. At is always UTC; presentation uses the user's zone.
type RatePoint struct {
	At         time.Time `json:"at"`
	Multiplier *float64  `json:"multiplier"`
	Status     string    `json:"status"`
}

type WindowSeries struct {
	Model   string      `json:"model,omitempty"`
	Now     RatePoint   `json:"now"`
	Changes []RatePoint `json:"changes"`
}

type WindowGroup struct {
	Provider       string         `json:"provider"`
	PlanIDs        []string       `json:"planIds"`
	Generations    []string       `json:"generations,omitempty"`
	Region         string         `json:"region,omitempty"`
	Clients        []string       `json:"clients,omitempty"`
	Timezones      []string       `json:"timezones,omitempty"`
	Qualifications []string       `json:"qualifications,omitempty"`
	Series         []WindowSeries `json:"series"`
}

type WindowFilter struct{ Provider, Plan, Model, Region string }

func inHorizon(d *digest.Digest, at time.Time) bool {
	if d == nil || d.MultiplierHorizon == nil {
		return false
	}
	h := d.MultiplierHorizon
	from, e1 := time.Parse(time.RFC3339, h.From)
	to, e2 := time.Parse(time.RFC3339, h.To)
	return e1 == nil && e2 == nil && !at.Before(from) && at.Before(to) && h.Selection == "highest-priority-no-stacking"
}

func publishedRate(d *digest.Digest, match func(*digest.MultiplierWindow) bool, at time.Time) (*float64, string) {
	if !inHorizon(d, at) {
		return nil, "unknown"
	}
	r, status := rateAt(d.Multipliers, match, at)
	if r == nil {
		return nil, "unknown"
	}
	return r, status
}

func rateTimeline(d *digest.Digest, match func(*digest.MultiplierWindow) bool, now time.Time) WindowSeries {
	r, s := publishedRate(d, match, now)
	out := WindowSeries{Now: RatePoint{now.UTC(), r, s}, Changes: []RatePoint{}}
	if !inHorizon(d, now) {
		return out
	}
	var bounds []time.Time
	for i := range d.Multipliers {
		w := &d.Multipliers[i]
		if !match(w) {
			continue
		}
		for _, raw := range []string{w.StartsAt, w.EndsAt} {
			if t, err := time.Parse(time.RFC3339, raw); err == nil && t.After(now) && inHorizon(d, t) {
				bounds = append(bounds, t.UTC())
			}
		}
	}
	sort.Slice(bounds, func(i, j int) bool { return bounds[i].Before(bounds[j]) })
	prev := out.Now
	for i, t := range bounds {
		if i > 0 && t.Equal(bounds[i-1]) {
			continue
		}
		r, s := publishedRate(d, match, t)
		if sameRate(prev.Multiplier, r) && prev.Status == s {
			continue
		}
		prev = RatePoint{t, r, s}
		out.Changes = append(out.Changes, prev)
	}
	return out
}

func sameRate(a, b *float64) bool { return a == nil && b == nil || a != nil && b != nil && *a == *b }
func sortedStrings(xs []string) []string {
	ys := append([]string{}, xs...)
	sort.Strings(ys)
	return ys
}

// Windows keeps separate regional, generation and client scopes, grouping plan families
// with a shared schedule. Model overrides inherit the family's model-independent rules.
func Windows(d *digest.Digest, f WindowFilter, now time.Time) []WindowGroup {
	out := []WindowGroup{}
	if d == nil {
		return out
	}
	// Enumerate concrete scopes, then resolve over every compatible rule. A base
	// covering several plans must participate in an override naming only one plan.
	scopes := map[string]WindowGroup{}
	for _, w := range d.Multipliers {
		if f.Provider != "" && !strings.EqualFold(f.Provider, w.Provider) {
			continue
		}
		plans := w.PlanIDs
		if len(plans) == 0 {
			plans = []string{f.Plan}
		}
		gens := w.Generations
		if len(gens) == 0 {
			gens = []string{""}
		}
		for _, plan := range plans {
			for _, gen := range gens {
				if f.Plan != "" && plan != "" && f.Plan != plan {
					continue
				}
				if f.Region != "" && w.Region != "" && w.Region != f.Region {
					continue
				}
				region := w.Region
				if f.Region != "" {
					region = f.Region
				}
				g := WindowGroup{Provider: w.Provider, PlanIDs: []string{}, Region: region, Clients: sortedStrings(w.Clients)}
				if plan != "" {
					g.PlanIDs = []string{plan}
				}
				if gen != "" {
					g.Generations = []string{gen}
				}
				key, _ := json.Marshal(g)
				scopes[string(key)] = g
			}
		}
	}
	keys := make([]string, 0, len(scopes))
	for k := range scopes {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	merged := map[string]int{}
	for _, key := range keys {
		g := scopes[key]
		scopeMatch := func(w *digest.MultiplierWindow) bool {
			return w.Provider == g.Provider && (len(w.PlanIDs) == 0 || len(g.PlanIDs) > 0 && contains(w.PlanIDs, g.PlanIDs[0])) &&
				(len(w.Generations) == 0 || len(g.Generations) > 0 && contains(w.Generations, g.Generations[0])) &&
				(w.Region == "" || w.Region == g.Region) &&
				(len(w.Clients) == 0 || strings.Join(sortedStrings(w.Clients), "|") == strings.Join(g.Clients, "|"))
		}
		models, zones := map[string]bool{}, map[string]bool{}
		qualifications := map[string]bool{}
		for i := range d.Multipliers {
			w := &d.Multipliers[i]
			if !scopeMatch(w) {
				continue
			}
			for _, c := range w.Conditions {
				qualifications[c] = true
			}
			if w.RequiresQuotaAvailable {
				qualifications["requiresQuotaAvailable"] = true
			}
			for client, version := range w.MinClientVersions {
				qualifications[client+" >= "+version] = true
			}
			for _, m := range w.Models {
				models[m] = true
			}
			if len(w.Models) == 0 {
				models[""] = true
			}
			if w.Timezone != "" {
				zones[w.Timezone] = true
			}
		}
		for q := range qualifications {
			g.Qualifications = append(g.Qualifications, q)
		}
		sort.Strings(g.Qualifications)
		for z := range zones {
			g.Timezones = append(g.Timezones, z)
		}
		sort.Strings(g.Timezones)
		aliases := func(model string) []string {
			ids := []string{model}
			for _, m := range d.Models {
				if strings.EqualFold(m.ID, model) || strings.EqualFold(m.Name, model) {
					ids = append(ids, m.ID, m.Name)
				}
			}
			return ids
		}
		if f.Model != "" {
			has := models[""]
			for _, n := range aliases(f.Model) {
				has = has || models[n]
			}
			if !has {
				continue
			}
			models = map[string]bool{f.Model: true}
		}
		names := make([]string, 0, len(models))
		for m := range models {
			names = append(names, m)
		}
		sort.Strings(names)
		g.Series = []WindowSeries{}
		for _, model := range names {
			ids := aliases(model)
			series := rateTimeline(d, func(w *digest.MultiplierWindow) bool {
				if !scopeMatch(w) {
					return false
				}
				if len(w.Models) == 0 {
					return true
				}
				for _, id := range ids {
					if contains(w.Models, id) {
						return true
					}
				}
				return false
			}, now)
			series.Model = model
			g.Series = append(g.Series, series)
		}
		family := g
		family.PlanIDs = nil
		signature, _ := json.Marshal(family)
		if index, ok := merged[string(signature)]; ok {
			out[index].PlanIDs = append(out[index].PlanIDs, g.PlanIDs...)
		} else {
			merged[string(signature)] = len(out)
			out = append(out, g)
		}
	}
	return out
}

// BillingContext is optional context for a declared plan. Reference costs remain API
// reference-task costs; multiplying them by a time rate is not a promise of plan quota.
type BillingContext struct {
	PlanID         string     `json:"planId"`
	Generation     string     `json:"generation,omitempty"`
	Region         string     `json:"region,omitempty"`
	Model          string     `json:"model"`
	BaseCost       *float64   `json:"baseCost"`
	MultiplierNow  *float64   `json:"multiplierNow"`
	EffectiveCost  *float64   `json:"effectiveCost"`
	Status         string     `json:"status"`
	NextCheaperAt  *time.Time `json:"nextCheaperAt,omitempty"`
	NextMultiplier *float64   `json:"nextMultiplier,omitempty"`
	NextStatus     string     `json:"nextStatus,omitempty"`
}

func planForAccount(a *quota.Account, d *digest.Digest) *Plan {
	if a.Plan == "" || a.Source != "user" {
		return nil
	}
	if m := d.Metering(a.Plan, a.Generation); m != nil {
		p := newPlan(a.Plan, m, d)
		p.Region = a.Region
		return p
	}
	return &Plan{ID: a.Plan, Generation: a.Generation, Region: a.Region, d: d, rules: map[string]bool{}}
}

// timeDigest preserves uncertainty when a required scope or eligibility context
// is missing. A top-priority unknown still blocks a lower-priority coefficient.
func (p *Plan) timeDigest() *digest.Digest {
	d := *p.d
	d.Multipliers = append([]digest.MultiplierWindow(nil), p.d.Multipliers...)
	for i := range d.Multipliers {
		w := &d.Multipliers[i]
		if w.Region != "" && p.Region == "" || len(w.Generations) > 0 && p.Generation == "" || len(w.MinClientVersions) > 0 || w.RequiresQuotaAvailable || len(w.Conditions) > 0 {
			w.Multiplier = nil
		}
	}
	return &d
}

// Billing uses only explicitly declared plans, never a vendor account's plan-name guess.
func Billing(d *digest.Digest, report quota.Report, models []*digest.Model, now time.Time) []BillingContext {
	out := []BillingContext{}
	seen := map[string]bool{}
	if d == nil {
		return out
	}
	for i := range report.Accounts {
		p := planForAccount(&report.Accounts[i], d)
		if p == nil {
			continue
		}
		for _, m := range models {
			match := func(w *digest.MultiplierWindow) bool { return p.applies(w, m) }
			applicable := false
			for j := range d.Multipliers {
				if match(&d.Multipliers[j]) {
					applicable = true
					break
				}
			}
			if !applicable {
				continue
			}
			key := strings.Join([]string{p.ID, p.Generation, p.Region, m.ID}, "|")
			if seen[key] {
				continue
			}
			seen[key] = true
			t := rateTimeline(p.timeDigest(), match, now)
			c := BillingContext{PlanID: p.ID, Generation: p.Generation, Region: p.Region, Model: m.ID, MultiplierNow: t.Now.Multiplier, Status: t.Now.Status}
			if e := m.Rec(); e != nil {
				c.BaseCost = e.Cost
			}
			if c.BaseCost != nil && c.MultiplierNow != nil {
				v := *c.BaseCost * *c.MultiplierNow
				c.EffectiveCost = &v
			}
			if c.MultiplierNow != nil {
				for _, change := range t.Changes {
					if change.At.After(now.Add(6 * time.Hour)) {
						break
					}
					if change.Multiplier != nil && *change.Multiplier < *c.MultiplierNow {
						at := change.At
						c.NextCheaperAt = &at
						c.NextMultiplier = change.Multiplier
						c.NextStatus = change.Status
						break
					}
				}
			}
			out = append(out, c)
		}
	}
	return out
}

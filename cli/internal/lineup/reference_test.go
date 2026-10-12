package lineup

import (
	"math"
	"sort"
)

func ok(p *float64) bool { return p != nil && !math.IsNaN(*p) && !math.IsInf(*p, 0) }

// Compute returns nil when fewer than two members have both ability and cost.
func Compute(members []Member, tie float64) *Lineup {
	var rows, incomplete []*Row
	for _, m := range members {
		if ok(m.Ability) && ok(m.Cost) && *m.Cost > 0 {
			rows = append(rows, &Row{ID: m.ID, Ability: *m.Ability, Cost: *m.Cost, Tags: []string{}})
		} else {
			incomplete = append(incomplete, &Row{ID: m.ID, Status: "incomplete", Tags: []string{}})
		}
	}
	if len(rows) < 2 {
		return nil
	}

	byCost := func(s []*Row) {
		sort.SliceStable(s, func(i, j int) bool {
			if s[i].Cost != s[j].Cost {
				return s[i].Cost < s[j].Cost
			}
			if s[i].Ability != s[j].Ability {
				return s[i].Ability > s[j].Ability
			}
			return s[i].ID < s[j].ID
		})
	}
	sorted := append([]*Row(nil), rows...)
	byCost(sorted)
	base := sorted[0] // cheapest; on equal cost the more able one
	for _, r := range rows {
		r.CostRelative = r.Cost / base.Cost
		for _, o := range sorted { // first hit is the cheapest dominator
			if o != r && ((o.Cost < r.Cost && o.Ability >= r.Ability-tie) || (o.Cost == r.Cost && o.Ability > r.Ability)) {
				kind := "weaker"
				if math.Abs(o.Ability-r.Ability) <= tie {
					kind = "equivalent"
				}
				r.DominatedBy = &Dominance{ID: o.ID, Kind: kind}
				break
			}
		}
	}
	var frontier []*Row
	for _, r := range sorted {
		if r.DominatedBy == nil {
			frontier = append(frontier, r)
		}
	}

	aMax := math.Inf(-1)
	for _, r := range rows {
		aMax = math.Max(aMax, r.Ability)
	}
	var strongest, best *Row
	bestV := math.Inf(-1)
	for _, r := range sorted {
		if strongest == nil && r.Ability >= aMax-tie {
			strongest = r
		}
	}
	for _, r := range frontier {
		if r == base || r.Cost == base.Cost {
			continue
		}
		if v := (r.Ability - base.Ability) / math.Log2(r.Cost/base.Cost); v > bestV {
			best, bestV = r, v
		}
	}
	base.Tags = append(base.Tags, "cheapest")
	strongest.Tags = append(strongest.Tags, "strongest")
	if best != nil {
		best.Tags = append(best.Tags, "best_value")
	}
	for _, r := range rows {
		if r.DominatedBy != nil {
			if r.DominatedBy.Kind == "equivalent" {
				r.Tags = append(r.Tags, "equivalent_costlier")
			} else {
				r.Tags = append(r.Tags, "dominated")
			}
		}
	}

	l := &Lineup{Method: "lineup-v1", Tie: tie, Baseline: base.ID, Members: append(rows, incomplete...)}
	for i, r := range frontier {
		l.Frontier = append(l.Frontier, r.ID)
		if i > 0 {
			p := frontier[i-1]
			l.Steps = append(l.Steps, Step{From: p.ID, To: r.ID, AbilityDelta: r.Ability - p.Ability, CostRatio: r.Cost / p.Cost})
		}
	}
	return l
}

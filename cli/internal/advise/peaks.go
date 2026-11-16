// SPDX-License-Identifier: MIT
package advise

import (
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Peak is a declared plan's current or next time-of-day window in which a model's published rate is higher than
// outside it, within the multiplier horizon. EndsAt is nil when the window does not end within the horizon.
type Peak struct {
	Plan     string
	Model    string
	StartsAt time.Time
	EndsAt   *time.Time
	Status   string // CONFIRMED | TENTATIVE
}

// Peaks reads the same published multiplier windows the advice does, for explicitly declared plans only, and
// reports one peak per plan: the first model whose rate rises within `horizon`, or is raised now. A rate that is
// unknown at any step ends the search for that model; nothing is inferred.
func Peaks(d *digest.Digest, report quota.Report, now time.Time, horizon time.Duration) []Peak {
	out := []Peak{}
	if d == nil {
		return out
	}
	seen := map[string]bool{}
	for i := range report.Accounts {
		a := &report.Accounts[i]
		p := planForAccount(a, d)
		if p == nil || seen[p.ID] {
			continue
		}
		seen[p.ID] = true
		var models []string
		named := map[string]bool{}
		planWide := false
		for j := range d.Multipliers {
			w := &d.Multipliers[j]
			if !p.appliesTo(w) {
				continue
			}
			if len(w.Models) == 0 {
				planWide = true
			}
			for _, m := range w.Models {
				if !named[m] {
					named[m] = true
					models = append(models, m)
				}
			}
		}
		if planWide {
			models = append([]string{""}, models...)
		}
		for _, model := range models {
			match := func(w *digest.MultiplierWindow) bool {
				return p.appliesTo(w) && (len(w.Models) == 0 || model != "" && contains(w.Models, model))
			}
			if peak, ok := peakIn(rateTimeline(p.timeDigest(), match, now), now, horizon); ok {
				peak.Plan, peak.Model = p.ID, model
				out = append(out, peak)
				break
			}
		}
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].StartsAt.Before(out[j].StartsAt) })
	return out
}

func peakIn(t WindowSeries, now time.Time, horizon time.Duration) (Peak, bool) {
	if t.Now.Multiplier == nil {
		return Peak{}, false
	}
	until := now.Add(horizon)
	points := []RatePoint{t.Now}
	for _, c := range t.Changes {
		if c.At.After(until) {
			break
		}
		if c.Multiplier == nil {
			break // unknown from here on
		}
		points = append(points, c)
	}
	base := *t.Now.Multiplier
	for _, pt := range points {
		if *pt.Multiplier < base {
			base = *pt.Multiplier
		}
	}
	status := func(list []RatePoint) string {
		for _, pt := range list {
			if pt.Status != "CONFIRMED" {
				return "TENTATIVE"
			}
		}
		return "CONFIRMED"
	}
	start := -1
	for i, pt := range points {
		if *pt.Multiplier > base {
			start = i
			break
		}
	}
	if start < 0 {
		return Peak{}, false
	}
	peak := Peak{StartsAt: points[start].At.UTC()}
	if start == 0 {
		peak.StartsAt = now.UTC()
	}
	end := len(points)
	for i := start + 1; i < len(points); i++ {
		if *points[i].Multiplier <= base {
			at := points[i].At.UTC()
			peak.EndsAt, end = &at, i+1
			break
		}
	}
	peak.Status = status(points[start:end])
	return peak, true
}

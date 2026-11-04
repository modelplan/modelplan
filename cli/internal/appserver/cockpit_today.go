// SPDX-License-Identifier: MIT
package appserver

import (
	"regexp"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// cockpitToday is a local intermediate, not a wire contract. Nil rates are
// unknown (including fewer than five eligible observations), not zero.
type CockpitToday struct {
	SubscriptionRef string
	Source          string
	OutputTokens    int64
	GenerationTPS   *float64
	BindingBasis    string
}

var cockpitSubscriptionRef = regexp.MustCompile(`^[a-f0-9]{16}$`)

// CockpitTodayTotals consumes only an already-admitted, complete set of source
// accounts. The caller must not invoke it on a filtered account subset: doing
// so could hide an ambiguous binding. Totals describe today's locally observed
// harness traffic, not proof of historic subscription ownership.
func CockpitTodayTotals(accounts []quota.Account, view speed.PerfView) []CockpitToday {
	out := []CockpitToday{}
	if !view.OK || !view.Recording {
		return out
	}
	type candidate struct {
		ref       string
		ambiguous bool
	}
	bySource := map[string]candidate{}
	for _, account := range accounts {
		if account.Source == "" {
			continue
		}
		c := bySource[account.Source]
		b := account.Subscription
		if account.Stale || b == nil || b.Status != "verified" || !cockpitSubscriptionRef.MatchString(b.Ref) || b.ObservedAt.IsZero() || b.ObservedAt.After(view.Now) || view.Now.Sub(b.ObservedAt) > time.Hour {
			c.ambiguous = true
		} else if c.ref != "" && c.ref != b.Ref {
			c.ambiguous = true
		} else {
			c.ref = b.Ref
		}
		bySource[account.Source] = c
	}
	for _, total := range view.TodayTotals() {
		c := bySource[total.Source]
		if c.ambiguous || c.ref == "" || total.Sums.ObservedOutputTokens < 0 {
			continue
		}
		item := CockpitToday{SubscriptionRef: c.ref, Source: total.Source, OutputTokens: total.Sums.ObservedOutputTokens, BindingBasis: "source-wide-current-binding"}
		if total.Sums.EligibleRequests >= speed.MinSamples && total.Sums.GenMs > 0 && total.Sums.EligibleOutputTokens >= 0 {
			rate := float64(total.Sums.EligibleOutputTokens) * 1000 / float64(total.Sums.GenMs)
			item.GenerationTPS = &rate
		}
		out = append(out, item)
	}
	return out
}

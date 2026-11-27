// SPDX-License-Identifier: MIT
package main

import (
	"math"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// cockpitUsage ranks every session and project by total tokens over today, 7 and 30 days (owner decision D470).
// Only admitted sources count. Labels and titles cross only while project labels are on; the bucket kinds
// (independent chats, home, none) never carry a label.
func cockpitUsage(perf speed.PerfView, allowed map[string]bool, labels bool, models []digest.Model, tiers []digest.SpeedTier) *wire.CockpitUsage {
	var pricer speed.Pricer
	if publishesPrices(models) {
		pricer = newPublicationPricer(models, tiers)
	}
	view := perf
	view.Ledger.Sessions = nil
	for _, s := range perf.Ledger.Sessions {
		if allowed[s.Source] {
			view.Ledger.Sessions = append(view.Ledger.Sessions, s)
		}
	}
	view.Ledger.UsageSessions = map[string][]speed.SessionResponse{}
	for key, rs := range perf.Ledger.UsageSessions {
		for _, r := range rs {
			if allowed[r.Source] {
				view.Ledger.UsageSessions[key] = append(view.Ledger.UsageSessions[key], r)
			}
		}
	}
	u := view.Usage(pricer)
	conv := func(w speed.UsageWindow) wire.CockpitUsageWindow {
		out := wire.CockpitUsageWindow{Tokens: usageTokens(w.Total), SessionCount: w.Sessions, ProjectCount: w.Projects,
			Projects: []wire.CockpitUsageProject{}, Sessions: []wire.CockpitUsageSession{},
			OtherProjects: usageOther(w.OtherProjects), OtherSessions: usageOther(w.OtherSessions)}
		out.CostUsd, out.CostState = usageCost(w.Cost)
		for _, r := range w.ProjectRows {
			out.Projects = append(out.Projects, usageProject(r, labels, models))
		}
		for _, r := range w.SessionRows {
			out.Sessions = append(out.Sessions, usageSession(r, labels, models))
		}
		if w.Review.Runs > 0 {
			b := &wire.CockpitBackgroundReview{Runs: w.Review.Runs, Tokens: usageTokens(w.Review.Tokens), Share: usageShare(w.Review.Share),
				ModelApprox: w.Review.ModelApprox, LastObservedAt: w.Review.LastAt.UTC()}
			b.CostUsd, b.CostState = usageCost(w.Review.Cost)
			b.Model = usageModel(w.Review.Model, "codex", models)
			out.BackgroundReview = b
		}
		return out
	}
	return &wire.CockpitUsage{Measure: u.Measure, Today: conv(u.Today), Recent7d: conv(u.Recent7d), Recent30d: conv(u.Recent30d)}
}

func usageTokens(t speed.TokenSums) wire.CockpitUsageTokens {
	return wire.CockpitUsageTokens{Total: t.Total, Input: t.Input, Output: t.Output, CacheRead: t.CacheRead, CacheWrite: t.CacheWrite, Complete: t.Complete}
}

func usageOther(o speed.UsageOther) wire.CockpitUsageOther {
	out := wire.CockpitUsageOther{Count: o.Count, Tokens: usageTokens(o.Tokens), Share: usageShare(o.Share)}
	out.CostUsd, out.CostState = usageCost(o.Cost)
	return out
}

// usageShare: four decimals, so a page can show a percentage and the rows still add up to 1 within rounding.
func usageShare(s float64) float64 { return math.Round(s*10000) / 10000 }

func usageCost(c speed.Cost) (*float64, wire.CockpitCostState) {
	state := wire.CostStateUnpriced
	switch c.State {
	case speed.CostPriced:
		state = wire.CostStatePriced
	case speed.CostPartial:
		state = wire.CostStatePartial
	}
	if c.USD == nil {
		return nil, state
	}
	v := math.Round(*c.USD*100) / 100
	return &v, state
}

// usageModel: a published model ID, or nil. A model the publication does not list is never sent as a raw ID.
func usageModel(raw, source string, models []digest.Model) *string {
	if raw == "" {
		return nil
	}
	if id := cockpitModelID(raw, source, models); id != "unknown" {
		return &id
	}
	return nil
}

func usageEffort(configs []speed.SessionConfig) *string {
	if len(configs) == 0 {
		return nil
	}
	switch e := configs[0].Effort; e {
	case "low", "medium", "high", "xhigh", "max", "ultra":
		if configs[0].EffortStatus == "reported" {
			return &e
		}
	}
	return nil
}

func usageKind(k string) wire.CockpitProjectKind {
	switch k {
	case speed.KindRepo, speed.KindWorkspace, speed.KindIndependent, speed.KindHome, speed.KindNone:
		return wire.CockpitProjectKind(k)
	}
	return ""
}

// cockpitProjectState: bucket kinds are "no project" whatever their reference; otherwise a name is shown,
// withheld (labels off) or unreadable.
func cockpitProjectState(ref *string, label *string, kind wire.CockpitProjectKind, labels bool) (wire.CockpitProjectState, *string) {
	switch {
	case ref == nil, kind == wire.ProjectKindIndependent, kind == wire.ProjectKindHome, kind == wire.ProjectKindNone:
		return wire.ProjectNone, nil
	case !labels:
		return wire.ProjectHidden, nil
	case label != nil && safeCockpitLabel(*label):
		return wire.ProjectNamed, label
	}
	return wire.ProjectUnnamed, unnamedProjectLabel(*ref)
}

func usageProject(r speed.UsageRow, labels bool, models []digest.Model) wire.CockpitUsageProject {
	kind := usageKind(r.ProjectKind)
	p := wire.CockpitUsageProject{Ref: r.Ref, Kind: kind, Sessions: r.Sessions, Sources: r.Sources, SubscriptionRefs: r.SubscriptionRefs,
		LastObservedAt: r.LastAt.UTC(), Running: r.Running, Tokens: usageTokens(r.Tokens), Share: usageShare(r.Share),
		ModelApprox: r.ModelApprox, Effort: usageEffort(r.Configs)}
	if p.Sources == nil {
		p.Sources = []string{}
	}
	if p.SubscriptionRefs == nil {
		p.SubscriptionRefs = []string{}
	}
	if labels && r.Label != nil && safeCockpitLabel(*r.Label) && kind != wire.ProjectKindIndependent && kind != wire.ProjectKindHome && kind != wire.ProjectKindNone {
		p.Label = r.Label
	}
	p.CostUsd, p.CostState = usageCost(r.Cost)
	p.Model = usageModel(r.Model, r.Source, models)
	return p
}

func usageSession(r speed.UsageRow, labels bool, models []digest.Model) wire.CockpitUsageSession {
	kind := usageKind(r.ProjectKind)
	state, label := cockpitProjectState(r.ProjectRef, r.Label, kind, labels)
	s := wire.CockpitUsageSession{SessionRef: r.Ref, Source: r.Source, SubscriptionRef: r.SubscriptionRef, ProjectRef: r.ProjectRef, ProjectKind: kind,
		ProjectLabel: label, ProjectState: state, FirstObservedAt: r.FirstAt.UTC(), LastObservedAt: r.LastAt.UTC(), Running: r.Running,
		Tokens: usageTokens(r.Tokens), Share: usageShare(r.Share), ModelApprox: r.ModelApprox, Effort: usageEffort(r.Configs)}
	if labels && r.Title != nil && safeCockpitTitle(*r.Title) {
		s.Title = r.Title
	}
	s.CostUsd, s.CostState = usageCost(r.Cost)
	s.Model = usageModel(r.Model, r.Source, models)
	return s
}

// safeCockpitTitle: a session title is shown as is, one line, bounded.
func safeCockpitTitle(s string) bool {
	if s == "" {
		return false
	}
	for _, r := range s {
		if r < 0x20 || r == 0x7f {
			return false
		}
	}
	return len([]rune(s)) <= 96
}

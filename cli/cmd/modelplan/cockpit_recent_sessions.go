// SPDX-License-Identifier: MIT
package main

import (
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

const (
	cockpitRecentSessionDays  = 7
	cockpitRecentSessionLimit = 200
)

// cockpitRecentSessions exports the recorded sessions last seen within the past seven days, newest first and
// capped. The sessions are already admitted against the current grant epochs; a source whose consent scope is
// not admitted is skipped. A session keeps only what the 7-day time view shows: when it was last seen, its
// model and effort on its last recorded day, its project label while labels are on, and a subscription only
// under a binding the cockpit already verified. It has no end time. Its title (the tool's own, while labels are on), total tokens and
// ≈cost are added by enrichRecentSessions when known (D470).
func cockpitRecentSessions(sessions []speed.PerfSession, allowed map[string]bool, sourceScope map[string]string, verified map[string]*wire.CockpitSubscriptionDetails, labels bool, models []digest.Model, now time.Time) []wire.CockpitRecentSession {
	from := now.Add(-cockpitRecentSessionDays * 24 * time.Hour)
	recent := make([]speed.PerfSession, 0, len(sessions))
	for _, session := range sessions {
		if !allowed[sourceScope[session.Source]] || !cockpitSubscriptionRef.MatchString(session.Ref) || session.LastAt.Before(from) || session.LastAt.After(now) {
			continue
		}
		recent = append(recent, session)
	}
	sort.SliceStable(recent, func(i, j int) bool {
		if !recent[i].LastAt.Equal(recent[j].LastAt) {
			return recent[i].LastAt.After(recent[j].LastAt)
		}
		return recent[i].Ref < recent[j].Ref
	})
	if len(recent) > cockpitRecentSessionLimit {
		recent = recent[:cockpitRecentSessionLimit]
	}
	out := make([]wire.CockpitRecentSession, 0, len(recent))
	for _, session := range recent {
		entry := wire.CockpitRecentSession{SessionRef: session.Ref, Source: session.Source, Model: "unknown", LastObservedAt: session.LastAt.UTC()}
		raw, lastDay := "", session.LastAt.Local().Format("2006-01-02")
		if len(session.Days) > 0 {
			// The newest recorded day by date, not the last one read: a log read out of order must not reverse it.
			last := session.Days[0]
			for _, d := range session.Days[1:] {
				if d.Day >= last.Day {
					last = d
				}
			}
			raw, lastDay = last.Model, last.Day
			switch last.Effort {
			case "low", "medium", "high", "xhigh", "max", "ultra":
				if last.EffortStatus == "reported" {
					v := last.Effort
					entry.Effort = &v
				}
			}
		}
		// macrevb-1299-9: a Codex session under no named model is shown as the dated fallback model, marked as an
		// approximation (the same rule as the usage rows); an observed model never is.
		if model, approx := speed.SessionModel(session.Source, raw, lastDay); approx {
			if id := cockpitModelID(model, session.Source, models); id != "unknown" {
				entry.Model, entry.ModelApprox = id, true
			}
		} else if raw != "" {
			entry.Model = cockpitModelID(raw, session.Source, models)
		}
		entry.ProjectKind = usageKind(session.Kind())
		var ref, label *string
		if session.ProjectRef != "" {
			ref = &session.ProjectRef
		}
		if safeCockpitLabel(session.ProjectLabel) {
			label = &session.ProjectLabel
		}
		entry.ProjectState, entry.ProjectLabel = cockpitProjectState(ref, label, entry.ProjectKind, labels)
		if labels && session.Title != "" && safeCockpitTitle(session.Title) {
			v := session.Title
			entry.Title = &v
		}
		if session.SubscriptionRef != "" && verified[session.SubscriptionRef] != nil {
			v := session.SubscriptionRef
			entry.SubscriptionRef = &v
		}
		out = append(out, entry)
	}
	return out
}

// enrichRecentSessions adds each session's total tokens and ≈cost so far (the tape's tokens slot, D470). Absent
// while unknown, never zero.
func enrichRecentSessions(sessions []wire.CockpitRecentSession, perf speed.PerfView, pricer speed.Pricer) {
	totals := perf.SessionTotals(pricer)
	for i := range sessions {
		t, ok := totals[sessions[i].SessionRef]
		if !ok {
			continue
		}
		sessions[i].TotalTokens = t.Tokens
		sessions[i].CostUsd, _ = usageCost(t.Cost)
	}
}

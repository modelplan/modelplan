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
// under a binding the cockpit already verified. It has no end time, title or token count.
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
		if n := len(session.Days); n > 0 {
			last := session.Days[n-1]
			entry.Model = cockpitModelID(last.Model, session.Source, models)
			switch last.Effort {
			case "low", "medium", "high", "xhigh", "max", "ultra":
				if last.EffortStatus == "reported" {
					v := last.Effort
					entry.Effort = &v
				}
			}
		}
		if labels && session.ProjectRef != "" && safeCockpitLabel(session.ProjectLabel) {
			v := session.ProjectLabel
			entry.ProjectLabel = &v
		}
		if session.SubscriptionRef != "" && verified[session.SubscriptionRef] != nil {
			v := session.SubscriptionRef
			entry.SubscriptionRef = &v
		}
		out = append(out, entry)
	}
	return out
}

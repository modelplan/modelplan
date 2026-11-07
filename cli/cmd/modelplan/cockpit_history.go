// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"sort"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// cockpitHistoryNow is the producer's clock, replaced by tests.
var cockpitHistoryNow = time.Now

// cockpitSourceScopes maps the ledger's sources to the consent scopes that admit their history.
var cockpitSourceScopes = map[string]string{"codex": "codex.local_history", "claude-code": "claude.local_history", "opencode": "opencodego.local_history", "zcode": "zai.local_history"}

// historyConsentTools maps the same sources to the consent tool names the desktop snapshot's
// admission checks; admittedHistorySources is the --history view of that admission.
var historyConsentTools = map[string]string{"codex": "codex", "claude-code": "claude", "opencode": "opencodego", "zcode": "zai"}

func admittedHistorySources(admission consent.Admission) map[string]bool {
	allowed := map[string]bool{}
	for source, tool := range historyConsentTools {
		if admission.Allows(tool, consent.Local) {
			allowed[source] = true
		}
	}
	return allowed
}

// cockpitHistory assembles the negotiated 7/30-day history section. It never widens consent: a
// source contributes only when its scope is admitted and its ledger rows are stamped with the
// current grant epoch, and a subscription row appears only under the one unambiguous current
// binding (as the today totals); everything else stays in the unattributed rankings.
func (s sharedCockpit) cockpitHistory(ctx context.Context, view appserver.View, admission queries.CockpitAdmission, groups map[string][]wire.CockpitAccount) (wire.CockpitHistory, error) {
	empty := wire.CockpitHistory{Version: 1, Sources: []string{}, Coverage: "unavailable", Subscriptions: []wire.CockpitSubscriptionHistory{},
		Models: emptyCockpitEntityRanking(), Tools: emptyCockpitEntityRanking(), Daily: []wire.CockpitSourceBucket{}, Hourly: []wire.CockpitSourceBucket{}, Projects: emptyCockpitProjects()}
	current := consent.Capture()
	fence := current.Fence()
	if fence.StoreEpoch != admission.Stamp.Epoch || fence.Generation != admission.Stamp.Generation {
		return empty, appserver.ProtocolError{Code: wire.CodeConsentChanged}
	}
	allowed := map[string]bool{}
	for _, scope := range admission.Scopes {
		for source, admitted := range cockpitSourceScopes {
			if scope == admitted {
				allowed[source] = true
			}
		}
	}
	now := cockpitHistoryNow()
	var perf *speed.PerfView
	if s.cache != "" && len(allowed) != 0 {
		ledger, ok := speed.LoadPerf(s.cache)
		if ok && !ledger.Since.IsZero() {
			// Long rows carry no grant epoch; the snapshot's scope and cleanup rule is what admits them.
			long, longOK := speed.LoadLong(s.cache)
			_, _, long = speed.LegacyAdmitted(speed.Ledger{}, speed.PerfLedger{}, long, current)
			v := speed.PerfView{Ledger: ledger, Long: long, LongOK: longOK, OK: ok, Recording: !speed.Off(), Now: now}.Admitted(current)
			perf = &v
		}
	}
	section := snapshot.BuildPerfHistory(perf, view.QuotaReport.Accounts, allowed, now)
	out := wire.CockpitHistory{Version: 1, Sources: []string{}, Coverage: section.Coverage, RecordingSince: section.RecordingSince,
		Subscriptions: []wire.CockpitSubscriptionHistory{}, Models: emptyCockpitEntityRanking(), Tools: emptyCockpitEntityRanking(), Daily: []wire.CockpitSourceBucket{}, Hourly: []wire.CockpitSourceBucket{}, Projects: emptyCockpitProjects()}
	if section.Coverage == "local-history" {
		out.Sources = append(out.Sources, "local-history")
		if perf != nil {
			out.DailyFrom, out.Daily, out.Hourly = cockpitBuckets(*perf, allowed, now)
			out.Projects = cockpitProjects(perf.Projects(), projectLabels(), view.PublicModels)
		}
		out.Models, out.Tools = cockpitEntityRanking(section.Models), cockpitEntityRanking(section.Tools)
		for _, sub := range section.Subscriptions {
			if _, ok := groups[sub.SubscriptionRef]; !ok {
				continue // only references the grouped cockpit rows already verified
			}
			if len(out.Subscriptions) == 128 {
				break
			}
			entry := wire.CockpitSubscriptionHistory{SubscriptionRef: sub.SubscriptionRef, Sources: []wire.CockpitSourceHistory{}}
			for _, src := range sub.Sources {
				entry.Sources = append(entry.Sources, wire.CockpitSourceHistory{Source: src.Source, BindingBasis: src.BindingBasis,
					Recent7d: cockpitHistorySums(src.Recent7d), Recent30d: cockpitHistorySums(src.Recent30d)})
			}
			out.Subscriptions = append(out.Subscriptions, entry)
		}
	}
	return out, ctx.Err()
}

const cockpitHistoryDays = 182

// cockpitBuckets sums the ledgers across models. Only admitted sources count, and the days are
// the ledgers' own local days.
func cockpitBuckets(perf speed.PerfView, allowed map[string]bool, now time.Time) (*string, []wire.CockpitSourceBucket, []wire.CockpitSourceBucket) {
	first := now.Local().AddDate(0, 0, -(cockpitHistoryDays - 1)).Format("2006-01-02")
	days, hours := map[[2]string]int64{}, map[[2]string]int64{}
	for _, d := range perf.DailyLong() {
		if allowed[d.Source] && d.Day >= first {
			days[[2]string{d.Day, d.Source}] += d.ObservedOutputTokens
		}
	}
	for _, h := range perf.Hourly() {
		if allowed[h.Source] {
			hours[[2]string{h.Hour, h.Source}] += h.ObservedOutputTokens
		}
	}
	bucket := func(values map[[2]string]int64, limit int) []wire.CockpitSourceBucket {
		out := make([]wire.CockpitSourceBucket, 0, len(values))
		for k, v := range values {
			out = append(out, wire.CockpitSourceBucket{At: k[0], Source: k[1], ObservedOutputTokens: v})
		}
		sort.Slice(out, func(i, j int) bool {
			if out[i].At != out[j].At {
				return out[i].At < out[j].At
			}
			return out[i].Source < out[j].Source
		})
		if len(out) > limit {
			out = out[len(out)-limit:] // the newest survive
		}
		return out
	}
	from := perf.LongCoverage().From
	if from != nil && *from < first {
		from = &first
	}
	return from, bucket(days, 728), bucket(hours, 192)
}

func emptyCockpitProjects() wire.CockpitProjectRanking {
	return wire.CockpitProjectRanking{Recent7d: []wire.CockpitRankedProject{}, Recent30d: []wire.CockpitRankedProject{}}
}

// Labels cross only while the preference is on; otherwise the page names a project by its rank.
func cockpitProjects(r speed.ProjectRanking, labels bool, models []digest.Model) wire.CockpitProjectRanking {
	window := func(w speed.ProjectWindow) []wire.CockpitRankedProject {
		out := []wire.CockpitRankedProject{}
		for _, p := range w.Top {
			var label *string
			if labels && p.Label != nil && safeCockpitLabel(*p.Label) {
				label = p.Label
			}
			entry := wire.CockpitRankedProject{Ref: p.Ref, Label: label, ObservedOutputTokens: p.ObservedOutputTokens, Share: p.Share}
			if len(p.Configs) > 0 {
				c := p.Configs[0]
				if id := cockpitModelID(c.Model, "", models); id != "unknown" {
					entry.Model = &id
				}
				switch c.Effort {
				case "low", "medium", "high", "xhigh", "max", "ultra":
					effort := c.Effort
					entry.Effort = &effort
				}
			}
			out = append(out, entry)
		}
		return out
	}
	return wire.CockpitProjectRanking{Recent7d: window(r.Recent7d), Recent30d: window(r.Recent30d)}
}

func emptyCockpitEntityRanking() wire.CockpitEntityRanking {
	return wire.CockpitEntityRanking{Measure: "observed-output-tokens", Attribution: "unattributed",
		Recent7d:  wire.CockpitEntityWindow{Top: []wire.CockpitRankedEntity{}},
		Recent30d: wire.CockpitEntityWindow{Top: []wire.CockpitRankedEntity{}}}
}

func cockpitEntityRanking(r speed.EntityRanking) wire.CockpitEntityRanking {
	out := wire.CockpitEntityRanking{Measure: r.Measure, Attribution: r.Attribution,
		Recent7d:  cockpitEntityWindow(r.Recent7d),
		Recent30d: cockpitEntityWindow(r.Recent30d)}
	return out
}

func cockpitEntityWindow(w speed.EntityWindow) wire.CockpitEntityWindow {
	out := wire.CockpitEntityWindow{Entities: w.Entities, TotalObservedOutputTokens: w.TotalObservedOutputTokens, Top: []wire.CockpitRankedEntity{}}
	for i := range w.Top {
		e := w.Top[i]
		out.Top = append(out.Top, wire.CockpitRankedEntity{Name: e.Name, ObservedRequests: e.ObservedRequests, ObservedOutputTokens: e.ObservedOutputTokens, Share: e.Share})
	}
	return out
}

func cockpitHistorySums(s snapshot.PerfWindowSums) wire.CockpitHistorySums {
	return wire.CockpitHistorySums{InputTokens: s.InputTokens, OutputTokens: s.OutputTokens, CacheReadTokens: s.CacheReadTokens, CacheWriteTokens: s.CacheWriteTokens,
		CacheHitRatio: s.CacheHitRatio, GenerationTps: s.GenerationTps, ObservedRequests: s.ObservedRequests, EligibleRequests: s.EligibleRequests}
}

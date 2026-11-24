// SPDX-License-Identifier: MIT
package appserver

import (
	"github.com/modelplan/modelplan/cli/internal/localday"
	"math"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// nextAccountTodayDeadline returns the earliest time a cached today value can
// change without a cache write. It observes only consent-admitted local data.
func nextAccountTodayDeadline(accounts []quota.Account, view speed.PerfView, now time.Time) time.Time {
	var next time.Time
	add := func(at time.Time) {
		if at.After(now) && (next.IsZero() || at.Before(next)) {
			next = at
		}
	}
	for _, live := range view.Ledger.Live {
		if live.Running && !live.LastAt.After(now) {
			add(live.LastAt.Add(speed.LiveWithin))
		}
	}
	if len(view.TodayTotals()) > 0 {
		local := now.In(time.Local)
		add(localday.Next(local))
		// The source-wide association requires a binding observed no more
		// than an hour ago. Its expiry is another time-only invalidation.
		for _, account := range accounts {
			if account.Subscription != nil && account.Subscription.Status == "verified" && !account.Subscription.ObservedAt.IsZero() {
				add(account.Subscription.ObservedAt.Add(quota.ObservationFreshness + time.Nanosecond))
			}
		}
	}
	return next
}

// attachAccountToday accepts only the complete current report and a perf view
// already filtered through the same consent admission. The source-wide binding
// is not proof of historical account ownership and is labeled accordingly.
func attachAccountToday(projection *rows.Projection, accounts []quota.Account, perf speed.PerfView) {
	if !perf.OK || !perf.Recording {
		return
	}
	tools := map[string]string{"codex": "codex", "claude-code": "claude", "zcode": "zai", "opencode": "opencodego"}
	targetFor := func(tool, ref string) *rows.Account {
		var target *rows.Account
		matches := 0
		for i := range projection.Rows {
			row := &projection.Rows[i]
			if row.ID != tool {
				continue
			}
			for j := range row.Accounts {
				a := &row.Accounts[j]
				if a.ValueState == rows.ValueStateCurrent && a.SubscriptionRef != nil && *a.SubscriptionRef == ref {
					matches++
					target = a
				}
			}
		}
		if matches != 1 {
			return nil
		}
		return target
	}
	for _, total := range CockpitTodayTotals(accounts, perf) {
		tool := tools[total.Source]
		if tool == "" {
			continue
		}
		target := targetFor(tool, total.SubscriptionRef)
		if target == nil || target.Today != nil {
			continue
		}
		stats := &rows.AccountToday{BindingBasis: rows.TodaySourceWideCurrentBinding, ObservedTotalTokens: total.TotalTokens}
		if total.OutputTokens > 0 {
			value := total.OutputTokens
			stats.ObservedOutputTokens = &value
		}
		if total.GenerationTPS != nil && *total.GenerationTPS > 0 && !math.IsNaN(*total.GenerationTPS) && !math.IsInf(*total.GenerationTPS, 0) {
			value := *total.GenerationTPS
			stats.GenerationTps = &value
		}
		if stats.ObservedTotalTokens != nil || stats.ObservedOutputTokens != nil || stats.GenerationTps != nil || stats.RunningSessions != nil {
			target.Today = stats
		}
	}
	// Do not turn a partial set of unbound live sessions into an exact count.
	unknown := map[string]bool{}
	counts := map[string]map[string]int{}
	for _, session := range perf.LiveSessions() {
		if tools[session.Source] == "" || session.Status != "running" {
			continue
		}
		if session.SubscriptionRef == nil || !cockpitSubscriptionRef.MatchString(*session.SubscriptionRef) {
			unknown[session.Source] = true
			continue
		}
		if counts[session.Source] == nil {
			counts[session.Source] = map[string]int{}
		}
		counts[session.Source][*session.SubscriptionRef]++
	}
	for source, byRef := range counts {
		if unknown[source] {
			continue
		}
		for ref, count := range byRef {
			target := targetFor(tools[source], ref)
			if target == nil {
				continue
			}
			if target.Today == nil {
				target.Today = &rows.AccountToday{BindingBasis: rows.TodaySessionBinding}
			}
			target.Today.RunningSessions = &count
		}
	}
}

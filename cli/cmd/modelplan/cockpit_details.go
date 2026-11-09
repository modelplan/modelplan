// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"math"
	"regexp"
	"sort"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

var cockpitSubscriptionRef = regexp.MustCompile(`^[a-f0-9]{16}$`)

func (s sharedCockpit) cockpitDetails(ctx context.Context, view appserver.View, admission queries.CockpitAdmission, groups map[string][]wire.CockpitAccount) (wire.CockpitDetails, error) {
	result := wire.CockpitDetails{Version: 1, Sources: []string{"quota-reserve", "quota-thresholds"}, Subscriptions: []wire.CockpitSubscriptionDetails{}, Sessions: []wire.CockpitSession{}, SessionCoverage: "unavailable", ResetEvents: []rows.ResetEvent{}, Alerts: []wire.CockpitAlert{}}
	current := consent.Capture()
	f := current.Fence()
	if f.StoreEpoch != admission.Stamp.Epoch || f.Generation != admission.Stamp.Generation {
		return result, appserver.ProtocolError{Code: wire.CodeConsentChanged}
	}
	// Publication is public but still comes from the verified local cache. The
	// enclosing cockpit query rechecks the consent fence before delivery.
	published, err := loadCockpitPublication(ctx, s.publicationStore)
	if err != nil {
		return result, err
	}
	result.Publication = selectCockpitPublication(published, view.Projection, nil)
	if appserver.CockpitModelsEnabled(ctx) {
		result.PublishedModels = allCockpitModels(published)
		result.PlanModels = cockpitPlanModels(published, result.PublishedModels)
	}
	now := time.Now()
	redBelow := admission.RedBelow
	if redBelow == 0 {
		redBelow = 25
	}
	byRef := map[string]*wire.CockpitSubscriptionDetails{}
	refs := make([]string, 0, len(groups))
	for ref := range groups {
		if cockpitSubscriptionRef.MatchString(ref) {
			refs = append(refs, ref)
		}
	}
	sort.Strings(refs)
	if len(refs) > 128 {
		refs = refs[:128]
	}
	for _, ref := range refs {
		result.Subscriptions = append(result.Subscriptions, wire.CockpitSubscriptionDetails{SubscriptionRef: ref, ResetCounts: []wire.CockpitResetCount{}, Today: []wire.CockpitToday{}})
		byRef[ref] = &result.Subscriptions[len(result.Subscriptions)-1]
	}
	// Pointers into a growing slice can be invalidated; rebuild after allocation.
	for i := range result.Subscriptions {
		byRef[result.Subscriptions[i].SubscriptionRef] = &result.Subscriptions[i]
	}
	// Reuse the exact consent-fenced row facts; do not re-aggregate raw cache
	// entries or infer availability from the legacy resetCounts array.
	for _, row := range view.Projection.Rows {
		for _, account := range row.Accounts {
			if account.SubscriptionRef != nil && byRef[*account.SubscriptionRef] != nil {
				byRef[*account.SubscriptionRef].ResetCards = account.ResetCards
			}
		}
	}
	for _, account := range view.QuotaReport.Accounts {
		if account.Stale || account.Subscription == nil || account.Subscription.Status != "verified" {
			continue
		}
		out := byRef[account.Subscription.Ref]
		if out == nil {
			continue
		}
		for _, card := range account.Cards {
			if card.ExpiresAt != nil && !now.Before(*card.ExpiresAt) {
				continue
			}
			if card.Kind != "full" && card.Kind != "five_hour" && card.Kind != "weekly" {
				continue
			}
			if card.Count != nil && (*card.Count < 0 || *card.Count > 100000) {
				continue
			}
			out.ResetCounts = append(out.ResetCounts, wire.CockpitResetCount{Kind: card.Kind, Count: card.Count, ExpiresAt: card.ExpiresAt})
		}
		if c := account.Credits; c != nil && !c.ObservedAt.IsZero() && !c.ObservedAt.After(now) && (c.Balance == nil || !math.IsNaN(*c.Balance) && !math.IsInf(*c.Balance, 0) && *c.Balance >= 0) {
			if out.Credits == nil || c.ObservedAt.After(out.Credits.ObservedAt) {
				out.Credits = &wire.CockpitCredits{Balance: c.Balance, ObservedAt: c.ObservedAt}
			}
		}
	}
	for i := range result.Subscriptions {
		sort.Slice(result.Subscriptions[i].ResetCounts, func(a, b int) bool {
			x, y := result.Subscriptions[i].ResetCounts[a], result.Subscriptions[i].ResetCounts[b]
			if x.Kind != y.Kind {
				return x.Kind < y.Kind
			}
			if x.ExpiresAt == nil && y.ExpiresAt != nil {
				return true
			}
			if x.ExpiresAt != nil && y.ExpiresAt == nil {
				return false
			}
			if x.ExpiresAt != nil && !x.ExpiresAt.Equal(*y.ExpiresAt) {
				return x.ExpiresAt.Before(*y.ExpiresAt)
			}
			if x.Count == nil {
				return y.Count != nil
			}
			if y.Count == nil {
				return false
			}
			return *x.Count < *y.Count
		})
		if len(result.Subscriptions[i].ResetCounts) > 64 {
			out := &result.Subscriptions[i]
			out.ResetCounts = out.ResetCounts[:64]
			out.ResetCountsTruncated = true
			facts := rows.ResetCards{State: rows.ResetCardPartial, Sources: []rows.ResetCardSource{}}
			if out.ResetCards != nil {
				facts = *out.ResetCards
			}
			facts.State, facts.Truncated = rows.ResetCardPartial, true
			out.ResetCards = &facts
		}
	}
	if view.ResetEvents != nil {
		result.Sources = append(result.Sources, "reset-events")
		result.ResetEvents = append(result.ResetEvents, wire.ProjectResetEventLinks(*view.ResetEvents, appserver.ResetEventLinksEnabled(ctx))...)
		sort.Slice(result.ResetEvents, func(i, j int) bool { return result.ResetEvents[i].ID < result.ResetEvents[j].ID })
		if len(result.ResetEvents) > 64 {
			result.ResetEvents = result.ResetEvents[:64]
		}
	}
	for _, row := range view.Projection.Rows {
		for _, account := range row.Accounts {
			if account.SubscriptionRef == nil || byRef[*account.SubscriptionRef] == nil || account.ValueState != rows.ValueStateCurrent {
				continue
			}
			for _, window := range account.Windows {
				if !window.Current || window.ValidUntil == nil || !now.Before(*window.ValidUntil) || window.RemainingPercent == nil {
					continue
				}
				v := *window.RemainingPercent
				if v < 0 || v > 50 || math.IsNaN(v) {
					continue
				}
				severity := "warning"
				if v <= float64(redBelow) {
					severity = "critical"
				}
				result.Alerts = append(result.Alerts, wire.CockpitAlert{Source: row.ID, SubscriptionRef: *account.SubscriptionRef, WindowID: window.ID, Severity: severity, RemainingPercent: v})
			}
		}
	}
	if appserver.CockpitForecastEnabled(ctx) {
		result.Forecasts = wire.ProjectForecasts(view.Projection, func(ref string) bool { return byRef[ref] != nil }, now)
	}
	sort.Slice(result.Alerts, func(i, j int) bool {
		a, b := result.Alerts[i], result.Alerts[j]
		if a.Source != b.Source {
			return a.Source < b.Source
		}
		if a.SubscriptionRef != b.SubscriptionRef {
			return a.SubscriptionRef < b.SubscriptionRef
		}
		return a.WindowID < b.WindowID
	})
	if len(result.Alerts) > 128 {
		result.Alerts = result.Alerts[:128]
	}
	if s.cache == "" || speed.Off() {
		if speed.Off() {
			result.SessionCoverage = "recording-off"
		}
		return result, ctx.Err()
	}
	allowed := map[string]bool{}
	for _, scope := range admission.Scopes {
		allowed[scope] = true
	}
	sourceScope := map[string]string{"codex": "codex.local_history", "claude-code": "claude.local_history", "opencode": "opencodego.local_history", "zcode": "zai.local_history"}
	any := false
	for _, scope := range sourceScope {
		any = any || allowed[scope]
	}
	if !any {
		return result, ctx.Err()
	}
	ledger, ok := speed.LoadPerf(s.cache)
	perf := (speed.PerfView{Ledger: ledger, OK: ok, Recording: true, Now: now}).Admitted(current)
	if !ok || ledger.Since.IsZero() {
		return result, ctx.Err()
	}
	result.SessionCoverage = "local-last-seen"
	result.Sources = append(result.Sources, "local-history")
	sort.Strings(result.Sources)
	for _, today := range appserver.CockpitTodayTotals(view.QuotaReport.Accounts, perf) {
		out := byRef[today.SubscriptionRef]
		if out != nil && allowed[sourceScope[today.Source]] && len(out.Today) < 4 {
			out.Today = append(out.Today, wire.CockpitToday{Source: today.Source, ObservedOutputTokens: today.OutputTokens, GenerationTps: today.GenerationTPS, BindingBasis: today.BindingBasis})
		}
	}
	labels := projectLabels()
	for _, session := range perf.LiveSessions() {
		if len(result.Sessions) == 64 {
			break
		}
		if !allowed[sourceScope[session.Source]] || !cockpitSubscriptionRef.MatchString(session.Ref) {
			continue
		}
		model := cockpitModelID(session.Model, session.Source, view.PublicModels)
		var effort, label *string
		switch session.Effort {
		case "low", "medium", "high", "xhigh", "max", "ultra":
			v := session.Effort
			effort = &v
		}
		if labels && session.ProjectRef != nil && safeCockpitLabel(session.ProjectLabel) {
			v := session.ProjectLabel
			label = &v
		} else if labels && session.ProjectRef != nil {
			for _, saved := range perf.Ledger.Sessions {
				if saved.Ref == session.Ref && saved.Source == session.Source && saved.ProjectRef == *session.ProjectRef && safeCockpitLabel(saved.ProjectLabel) {
					v := saved.ProjectLabel
					label = &v
					break
				}
			}
		}
		// The live record's account is the same evidence the working signal binds on. A reference
		// outside this cockpit's subscriptions stays unbound; never substitute a source-wide one.
		var subscription *string
		if session.SubscriptionRef != nil && byRef[*session.SubscriptionRef] != nil {
			subscription = session.SubscriptionRef
		}
		result.Sessions = append(result.Sessions, wire.CockpitSession{SessionRef: session.Ref, Source: session.Source, SubscriptionRef: subscription, Model: model, Effort: effort, ProjectLabel: label, LastObservedAt: session.LastAt, State: session.Status, Rate: session.Rate.Value})
	}
	inUse := map[string]bool{}
	for _, session := range result.Sessions {
		inUse[session.Model] = true
	}
	if len(inUse) > 0 {
		result.Publication = selectCockpitPublication(published, view.Projection, inUse)
	}
	return result, ctx.Err()
}

func safeCockpitLabel(s string) bool {
	if s == "" || utf8.RuneCountInString(s) > 64 || strings.ContainsAny(s, "/\\") {
		return false
	}
	for _, r := range s {
		if unicode.IsControl(r) {
			return false
		}
	}
	return true
}

// Only model IDs from the verified publication cross the cache boundary.
func cockpitModelID(raw, source string, models []digest.Model) string {
	for _, model := range models {
		if raw == model.ID {
			return model.ID
		}
		for _, alias := range model.HarnessIDs[source] {
			if raw == alias {
				return model.ID
			}
		}
	}
	return "unknown"
}

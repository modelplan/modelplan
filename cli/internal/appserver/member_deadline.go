// SPDX-License-Identifier: MIT
package appserver

import (
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// A stable past deadline represents already due, avoiding a new rows snapshot
// on every read. The scheduler always rechecks the current persisted budget.
var alreadyDue = time.Unix(0, 0).UTC()

type memberDeadline struct {
	route rows.Route
	at *time.Time
}

func (b *SharedBackend) populateRefreshDeadlines(projection *rows.Projection, p quota.Paths, admission consent.Admission, allowed []string, now time.Time) {
	state, mode := admission.State(), admission.Mode()
	byTool := map[string][]memberDeadline{}
	for _, scope := range liveRefreshScopes(state, mode) {
		definition, ok := consent.Definition(scope)
		if !ok { continue }
		candidate := memberDeadline{route: rows.Route(definition.Route)}
		permitted := false
		for _, value := range allowed { if value == scope { permitted = true } }
		if permitted && !admission.CleanupPending(definition.Tool) && !b.config.Offline && !b.config.ReadOnly {
			plan, err := quota.PlanScopeRefresh(p, scope, alreadyDue)
			if err == nil && plan.BudgetKnown && plan.Admitted && !plan.PolicyPending {
				at := plan.At.UTC()
				candidate.at = &at
				if b.RefreshDeadline != nil {
					if bound, exists, known := b.RefreshDeadline(scope); exists {
						if !known { candidate.at = nil } else if bound.After(at) { bound = bound.UTC(); candidate.at = &bound }
					}
				}
			}
		}
		byTool[definition.Tool] = append(byTool[definition.Tool], candidate)
	}
	for i := range projection.Rows {
		row := &projection.Rows[i]
		candidates := byTool[row.ID]
		if len(candidates) == 0 { continue }
		row.RefreshNotBefore = combineMemberDeadlines(candidates, "")
		for j := range row.Accounts {
			account := &row.Accounts[j]
			account.RefreshNotBefore = combineMemberDeadlines(candidates, account.Route)
			locator, subscription := "", ""
			if account.AccountLocator != nil { locator = *account.AccountLocator }
			if account.SubscriptionRef != nil { subscription = *account.SubscriptionRef }
			if locator == "" && subscription == "" { var unknown *time.Time; account.RefreshNotBefore = &unknown; continue }
			if quota.MemberProfilesAreScoped(row.ID) {
				if _, ok := quota.NarrowMemberPaths(p, row.ID, locator, subscription); !ok { var unknown *time.Time; account.RefreshNotBefore = &unknown }
			}
		}
	}
}

// The outer pointer distinguishes an ungranted row from a granted but unknown
// deadline. A route with no matching live reader is present but unknown.
func combineMemberDeadlines(candidates []memberDeadline, route rows.Route) **time.Time {
	var earliest *time.Time
	matched := false
	for _, item := range candidates {
		if route != "" && item.route != route { continue }
		matched = true
		if item.at == nil { var unknown *time.Time; return &unknown }
		if earliest == nil || item.at.Before(*earliest) { value := *item.at; earliest = &value }
	}
	if !matched { var unknown *time.Time; return &unknown }
	return &earliest
}

// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"regexp"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

var memberReference = regexp.MustCompile(`^[a-f0-9]{16}$`)

func liveMemberScope(tool string, route rows.Route, state consent.State, mode string, allowed []string) string {
	for _, scope := range liveRefreshScopes(state, mode) {
		definition, ok := consent.Definition(scope)
		if !ok || definition.Tool != tool || rows.Route(definition.Route) != route {
			continue
		}
		for _, active := range allowed {
			if active == scope {
				return scope
			}
		}
	}
	return ""
}

func deferredMember(reason wire.MemberRefreshReason, at *time.Time) wire.MemberRefreshResult {
	return wire.MemberRefreshResult{Outcome: wire.MemberRefreshDeferred, Reason: &reason, NotBefore: at}
}

// RequestMember admits exactly one account and resolves its reviewed live route
// under the same epoch, provider lock and budget as ordinary refresh requests.
func (s *RefreshScheduler) RequestMember(ctx context.Context, member wire.RefreshMember) (wire.MemberRefreshResult, Stamp, error) {
	if ctx.Err() != nil {
		return wire.MemberRefreshResult{}, Stamp{}, ctx.Err()
	}
	if member.RowID == "" || member.Route == "" ||
		(member.SubscriptionRef != "" && !memberReference.MatchString(member.SubscriptionRef)) ||
		(member.AccountLocator != "" && !memberReference.MatchString(member.AccountLocator)) {
		return wire.MemberRefreshResult{}, Stamp{}, ProtocolError{wire.CodeInvalidParams}
	}
	if s.config.Backend == nil || s.config.Paths == nil {
		return wire.MemberRefreshResult{}, Stamp{}, ProtocolError{wire.CodeInternal}
	}
	view, err := s.config.Backend.Get(ctx)
	if err != nil {
		return wire.MemberRefreshResult{}, Stamp{}, err
	}
	admission := consent.Capture()
	stamp := stampOfFence(admission.Fence())
	if stamp != view.Stamp {
		return wire.MemberRefreshResult{}, Stamp{}, ProtocolError{wire.CodeConsentChanged}
	}
	refused := deferredMember(wire.MemberRefreshNotGranted, nil)
	if member.AccountLocator == "" && member.SubscriptionRef == "" {
		return refused, stamp, nil
	}
	matches, routeMembers := matchingMemberCount(view, member)
	if matches != 1 {
		return refused, stamp, nil
	}
	scope := liveMemberScope(member.RowID, member.Route, admission.State(), admission.Mode(), view.Scopes)
	if scope == "" {
		return refused, stamp, nil
	}
	if s.config.Offline {
		return deferredMember(wire.MemberRefreshOffline, nil), stamp, nil
	}
	if s.config.ReadOnly || s.config.Run == nil {
		return deferredMember(wire.MemberRefreshBudget, nil), stamp, nil
	}
	definition, _ := consent.Definition(scope)
	if !quota.MemberProfilesAreScoped(definition.Tool) && routeMembers != 1 {
		return refused, stamp, nil
	}
	paths, ok := quota.NarrowMemberPaths(s.paths(admission), definition.Tool, member.AccountLocator, member.SubscriptionRef)
	if !ok {
		return refused, stamp, nil
	}
	now := s.now()
	plan, err := s.plan(paths, scope, now)
	if err != nil || !plan.BudgetKnown {
		return deferredMember(wire.MemberRefreshBudget, nil), stamp, nil
	}
	if !plan.Admitted || plan.PolicyPending {
		return refused, stamp, nil
	}
	if plan.At.After(now) {
		at := plan.At
		reason := wire.MemberRefreshReason(quota.MemberBudgetReason(paths, scope, at))
		return deferredMember(reason, &at), stamp, nil
	}
	key := definition.Tool
	s.mu.Lock()
	started := false
	defer func() {
		s.mu.Unlock()
		if started && s.config.Changed != nil {
			s.config.Changed()
		}
	}()
	if until, busy := s.pending[key]; busy {
		if until.After(now) {
			at := until.UTC()
			return deferredMember(wire.MemberRefreshBudget, &at), stamp, nil
		}
		return deferredMember(wire.MemberRefreshBudget, nil), stamp, nil
	}
	if until := s.autoNext[key]; until.After(now) {
		at := until.UTC()
		reason := s.autoReason[key]
		if reason == "" {
			reason = wire.MemberRefreshBudget
		}
		return deferredMember(reason, &at), stamp, nil
	}
	if len(s.pending) >= len(consent.Definitions()) || len(s.scheduled) >= len(consent.Definitions()) {
		return deferredMember(wire.MemberRefreshBudget, nil), stamp, nil
	}
	copy := member
	s.pending[key] = now.Add(5 * time.Minute)
	s.scheduled[key] = refreshJob{scope: scope, key: key, stamp: stamp, at: now, member: &copy}
	s.signal()
	started = true
	return wire.MemberRefreshResult{Outcome: wire.MemberRefreshStarted}, stamp, nil
}

// matchingMemberCount never treats a nil or positional identity as a member.
func matchingMemberCount(view View, member wire.RefreshMember) (matches, routeMembers int) {
	for _, row := range view.Projection.Rows {
		if row.ID != member.RowID {
			continue
		}
		for _, account := range row.Accounts {
			if account.Route != member.Route {
				continue
			}
			routeMembers++
			if member.AccountLocator != "" && (account.AccountLocator == nil || *account.AccountLocator != member.AccountLocator) {
				continue
			}
			if member.SubscriptionRef != "" && (account.SubscriptionRef == nil || *account.SubscriptionRef != member.SubscriptionRef) {
				continue
			}
			matches++
		}
	}
	return matches, routeMembers
}

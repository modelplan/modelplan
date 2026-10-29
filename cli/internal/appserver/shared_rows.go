// SPDX-License-Identifier: MIT
package appserver

import (
	"fmt"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func wireRoute(route string) rows.Route {
	switch rows.Route(route) {
	case rows.RouteSavedLoginAPI, rows.RouteRuntimeRPC, rows.RouteLocalLog, rows.RouteAPIKeyAPI, rows.RouteLocalSQLite, rows.RouteStatusLine, rows.RouteBrowserSession, rows.RouteManual:
		return rows.Route(route)
	default:
		return rows.RouteUnknown
	}
}
func routeForSource(source string) rows.Route {
	if strings.HasPrefix(source, "native:") {
		tool := rows.CanonicalTool(source)
		switch tool {
		case "claude", "grok", "gemini", "cursor":
			return rows.RouteSavedLoginAPI
		case "copilot", "kiro", "antigravity":
			return rows.RouteRuntimeRPC
		case "zai", "minimax", "opencodego":
			return rows.RouteAPIKeyAPI
		}
	}
	switch source {
	case "claude-code":
		return rows.RouteStatusLine
	case "codex":
		return rows.RouteLocalLog
	case "user":
		return rows.RouteManual
	}
	return rows.RouteUnknown
}
func timePointer(at time.Time) *time.Time {
	if at.IsZero() {
		return nil
	}
	return &at
}
func appendReportRows(in *rows.Input, report quota.Report, declaredOnly bool) {
	managed := map[string]bool{}
	for _, profile := range in.Profiles {
		managed[profile.ToolID] = true
	}
	for _, source := range report.Sources {
		tool := rows.CanonicalTool(source.Source)
		if tool == "codex-account" {
			tool = "codex"
		}
		if !declaredOnly && !managed[tool] {
			in.Sources = append(in.Sources, rows.SourceState{ToolID: tool, Source: source.Source, Status: source.Status, ErrorCode: source.ErrorCode})
		}
	}
	for index, account := range report.Accounts {
		tool := rows.CanonicalTool(account.Source)
		declared := ""
		route := routeForSource(account.Source)
		if account.Source == "user" {
			declared = account.Plan
			tool = ""
			if declared == "" {
				continue
			}
			in.DeclaredPlanIDs = append(in.DeclaredPlanIDs, declared)
		} else if declaredOnly || managed[tool] {
			continue
		}
		profileKey := fmt.Sprintf("report:%s:%d", account.Source, index)
		value := rows.AccountInput{ToolID: tool, DeclaredPlanID: declared, ProfileKey: profileKey, Source: account.Source, Route: route, PlanID: account.Plan, Beta: account.Beta}
		if account.Subscription != nil && account.Subscription.Status == "verified" {
			ref := account.Subscription.Ref
			value.SubscriptionRef = &ref
		}
		if account.Credits != nil {
			value.Credits = &rows.CreditsInput{Balance: account.Credits.Balance, Unit: account.Credits.Unit}
		}
		for _, window := range account.Windows {
			raw := rows.WindowInput{Kind: window.Kind, Limit: window.Limit, Pool: account.Pool, ResetMode: window.ResetMode, RemainingPercent: window.RemainingPercent, ResetsAt: window.ResetsAt, ObservedAt: timePointer(window.ObservedAt)}
			if window.WindowMinutes > 0 {
				duration := int64(window.WindowMinutes) * 60
				raw.DurationSeconds = &duration
			}
			value.Windows = append(value.Windows, raw)
		}
		profile := rows.ProfileState{ToolID: tool, DeclaredPlanID: declared, ProfileKey: profileKey, LatestAttempt: rows.AttemptResultSucceeded, ObservedAt: timePointer(account.ObservedAt), WithinFreshness: !account.Stale}
		if profile.ObservedAt != nil {
			until := profile.ObservedAt.Add(time.Hour)
			profile.FreshUntil = &until
		}
		for _, source := range report.Sources {
			if rows.CanonicalTool(source.Source) == tool && source.ErrorCode != "" {
				profile.LatestAttempt = rows.AttemptResultFailed
				profile.LastFailure = &rows.FailureInput{Code: source.ErrorCode}
			}
		}
		if account.Source == "codex" && account.Via == "codex-account" {
			value.Route = rows.RouteRuntimeRPC
		}
		in.Accounts = append(in.Accounts, value)
		in.Profiles = append(in.Profiles, profile)
	}
}

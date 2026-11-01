// SPDX-License-Identifier: MIT
package rows

import (
	"fmt"
	"math"
	"sort"
	"strconv"
	"strings"
	"time"
)

func finite(value *float64, min, max float64) *float64 {
	if value == nil || math.IsNaN(*value) || math.IsInf(*value, 0) || *value < min || *value > max {
		return nil
	}
	v := *value
	return &v
}
func observed(value *time.Time, now time.Time) *time.Time {
	if !validTime(value) || value.After(now) {
		return nil
	}
	v := value.UTC()
	return &v
}
func knownTime(value *time.Time) *time.Time {
	if !validTime(value) {
		return nil
	}
	v := value.UTC()
	return &v
}
func buildAccounts(in Input, c *candidate) []Account {
	profiles := append([]ProfileState(nil), c.profiles...)
	values := map[string][]AccountInput{}
	for _, a := range c.accounts {
		values[a.ProfileKey] = append(values[a.ProfileKey], a)
	}
	seen := map[string]bool{}
	for _, p := range profiles {
		seen[p.ProfileKey] = true
	}
	for key := range values {
		if !seen[key] {
			profiles = append(profiles, ProfileState{ProfileKey: key, LatestAttempt: AttemptResultNever})
		}
	}
	sort.SliceStable(profiles, func(i, j int) bool { return profiles[i].ProfileKey < profiles[j].ProfileKey })
	result := []Account{}
	for _, p := range profiles {
		list := values[p.ProfileKey]
		if len(list) == 0 {
			list = []AccountInput{{}}
		}
		for _, raw := range list {
			a := Account{Route: safeRoute(raw.Route), AccountLocator: safeRef(p.AccountLocator, in.IdentityOff), SubscriptionRef: safeRef(raw.SubscriptionRef, in.IdentityOff), Plan: planValue(raw.PlanID, c.declared), Beta: raw.Beta, ValueState: ValueStateNone, Windows: []Window{}}
			if c.declared != "" {
				a.Route = RouteManual
			}
			discard := p.LoginChanged || p.GenerationChanged
			if !discard {
				a.ObservedAt = observed(p.ObservedAt, in.Now)
				a.FreshUntil = knownTime(p.FreshUntil)
				if p.LatestAttempt == AttemptResultFailed && p.LastFailure != nil {
					if at := observed(p.LastFailure.At, in.Now); at != nil {
						a.LastFailure = &Failure{Code: profileFailure(p), At: *at}
					}
				}
				if raw.Credits != nil {
					if balance := finite(raw.Credits.Balance, 0, 1e15); balance != nil {
						unit := raw.Credits.Unit
						switch unit {
						case "money", "credits":
						default:
							unit = "other"
						}
						a.Credits = &Credits{Balance: balance, Unit: unit}
					}
				}
				a.Windows = buildWindows(raw.Windows, a, in.Now)
				has := a.Credits != nil
				for _, w := range a.Windows {
					has = has || w.RemainingPercent != nil
				}
				if has {
					a.ValueState = ValueStateRetained
					if p.LatestAttempt == AttemptResultSucceeded && a.ObservedAt != nil && p.WithinFreshness && a.FreshUntil != nil && in.Now.Before(*a.FreshUntil) {
						a.ValueState = ValueStateCurrent
					}
				}
				if !has {
					a.Windows = []Window{}
					a.FreshUntil = nil
				}
			} else {
				// Old subscription identity and values cannot follow a changed login/grant.
				a.SubscriptionRef = nil
				a.Plan = planValue("", c.declared)
			}
			for i := range a.Windows {
				a.Windows[i].Current = a.ValueState == ValueStateCurrent && a.Windows[i].RemainingPercent != nil && a.Windows[i].ValidUntil != nil && in.Now.Before(*a.Windows[i].ValidUntil)
			}
			if !discard && !in.ConsentChanged && !in.ReadersOff && !in.PrivacyBlocked && a.SubscriptionRef!=nil {
				for _,v:=range in.Activities {
					if CanonicalTool(v.ToolID)!=c.id || !v.BindingVerified || v.SubscriptionRef!=*a.SubscriptionRef || !refPattern.MatchString(v.SessionRef) || !validActivityWindow(v.Phase,v.RecordAt,v.ExpiresAt,in.Now) {continue}
					a.Activity=append(a.Activity,AccountActivity{v.SessionRef,v.SubscriptionRef,true,v.Phase,v.RecordAt,v.ExpiresAt})
					if len(a.Activity)>=64{break}
				}
				sort.Slice(a.Activity,func(i,j int)bool{return a.Activity[i].SessionRef<a.Activity[j].SessionRef})
			}
			result = append(result, a)
		}
	}
	sort.SliceStable(result, func(i, j int) bool {
		key := func(a Account) string {
			if a.SubscriptionRef != nil {
				return "a:" + *a.SubscriptionRef
			}
			if a.AccountLocator != nil {
				return "b:" + *a.AccountLocator
			}
			return "c:" + a.Plan.ID
		}
		return key(result[i]) < key(result[j])
	})
	return result
}

func role(kind string) (Role, Text) {
	switch kind {
	case "session", "five_hour":
		return RoleSession, Text{EN: "Session", ZH: "会话"}
	case "daily":
		return RoleDaily, Text{EN: "Daily", ZH: "每日"}
	case "weekly":
		return RoleWeekly, Text{EN: "Weekly", ZH: "每周"}
	case "monthly":
		return RoleMonthly, Text{EN: "Monthly", ZH: "每月"}
	default:
		return RoleOther, Text{EN: "Other limit", ZH: "其他限额"}
	}
}

// Only reviewed public IDs cross the rows trust boundary. An unrecognized
// explicit scope becomes a sanitized unknown-scoped marker.
var scopedModels = map[string]bool{"opus": true, "sonnet": true, "gemini-2.5-pro": true, "gemini-2.5-flash": true, "unknown": true}

func modelScope(ids []string) (*ModelScope, bool) {
	if ids == nil {
		return nil, true
	}
	if len(ids) == 0 || len(ids) > 32 {
		return &ModelScope{Models: []string{"unknown"}}, true
	}
	result := append([]string(nil), ids...)
	sort.Strings(result)
	for i, id := range result {
		if !scopedModels[id] || i > 0 && id == result[i-1] {
			return &ModelScope{Models: []string{"unknown"}}, true
		}
	}
	return &ModelScope{Models: result}, true
}

// SanitizeModelIDs applies the same reviewed vocabulary at every output
// boundary. A non-nil unknown scope remains explicitly model-scoped.
func SanitizeModelIDs(ids []string) []string {
	scope, _ := modelScope(ids)
	if scope == nil {
		return nil
	}
	return scope.Models
}
func buildWindows(raw []WindowInput, account Account, now time.Time) []Window {
	result := []Window{}
	for _, v := range raw {
		scope, ok := modelScope(v.ModelIDs)
		if !ok {
			continue
		}
		r, label := role(v.Kind)
		key := limitKey(v.Limit)
		// Unknown limits never acquire a provider-supplied label, even with a familiar role.
		if key == "other" {
			label = Text{EN: "Other limit", ZH: "其他限额"}
		}
		mode := ResetModeUnknown
		switch v.ResetMode {
		case "fixed":
			mode = ResetModeFixed
		case "rolling":
			mode = ResetModeRolling
		}
		var duration *int64
		if v.DurationSeconds != nil && *v.DurationSeconds > 0 && *v.DurationSeconds <= 366*86400 {
			value := *v.DurationSeconds
			duration = &value
		}
		durationKey := "unknown"
		if duration != nil {
			durationKey = strconv.FormatInt(*duration, 10)
		}
		w := Window{ModelScope: scope, ID: string(r) + ":" + durationKey + ":" + key + ":" + poolKey(v.Pool), Role: r, DurationSeconds: duration, Label: label, LimitKey: key, PoolKey: poolKey(v.Pool), ResetMode: mode, RemainingPercent: finite(v.RemainingPercent, 0, 100), ResetsAt: knownTime(v.ResetsAt), ObservedAt: observed(v.ObservedAt, now)}
		if account.FreshUntil != nil {
			w.ValidUntil = earlier(knownTime(account.FreshUntil), w.ResetsAt)
		}
		result = append(result, w)
	}
	sort.SliceStable(result, func(i, j int) bool {
		a, b := result[i], result[j]
		if a.ID != b.ID {
			return a.ID < b.ID
		}
		scopeKey := func(s *ModelScope) string {
			if s == nil {
				return ""
			}
			return strings.Join(s.Models, "\x00")
		}
		if scopeKey(a.ModelScope) != scopeKey(b.ModelScope) {
			return scopeKey(a.ModelScope) < scopeKey(b.ModelScope)
		}
		if a.ResetsAt == nil && b.ResetsAt != nil {
			return false
		}
		if a.ResetsAt != nil && b.ResetsAt == nil {
			return true
		}
		if a.ResetsAt != nil && !a.ResetsAt.Equal(*b.ResetsAt) {
			return a.ResetsAt.Before(*b.ResetsAt)
		}
		if a.ObservedAt == nil && b.ObservedAt != nil {
			return false
		}
		if a.ObservedAt != nil && b.ObservedAt == nil {
			return true
		}
		if a.ObservedAt != nil && !a.ObservedAt.Equal(*b.ObservedAt) {
			return a.ObservedAt.Before(*b.ObservedAt)
		}
		if a.RemainingPercent == nil {
			return false
		}
		if b.RemainingPercent == nil {
			return true
		}
		return *a.RemainingPercent < *b.RemainingPercent
	})
	for first := 0; first < len(result); {
		end := first + 1
		for end < len(result) && result[end].ID == result[first].ID {
			end++
		}
		if end-first > 1 {
			for i := first; i < end; i++ {
				result[i].ID = fmt.Sprintf("%s:%d", result[i].ID, i-first+1)
			}
		}
		first = end
	}
	return result
}

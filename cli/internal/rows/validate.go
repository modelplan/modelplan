// SPDX-License-Identifier: MIT
package rows

import (
	"fmt"
	"reflect"
	"strconv"
	"strings"
	"time"
)

// Validate checks wire fields against their own provenance/vocabulary, not a
// general charset scan. Existing random refs were verified by the cache adapter;
// the pure projector can check membership in those supplied references only.
func Validate(in Input, out Projection) error {
	fail := func(field string) error { return fmt.Errorf("invalid rows field: %s", field) }
	if out.RowsVersion != Version || out.ConsentGeneration != in.ConsentGeneration {
		return fail("version/generation")
	}
	tools := map[string]bool{}
	declared := map[string]bool{}
	refs := map[string]bool{}
	for _, c := range in.Catalogue {
		id := CanonicalTool(c.ToolID)
		if toolPattern.MatchString(id) {
			tools[id] = true
		}
	}
	for _, c := range in.Consents {
		id := CanonicalTool(c.ToolID)
		if toolPattern.MatchString(id) {
			tools[id] = true
		}
	}
	for _, p := range in.DeclaredPlanIDs {
		declared[p] = true
	}
	for _, a := range in.Accounts {
		if a.DeclaredPlanID != "" {
			declared[a.DeclaredPlanID] = true
		}
		if a.SubscriptionRef != nil && refPattern.MatchString(*a.SubscriptionRef) {
			refs[*a.SubscriptionRef] = true
		}
	}
	for _, p := range in.Profiles {
		if p.AccountLocator != nil && refPattern.MatchString(*p.AccountLocator) {
			refs[*p.AccountLocator] = true
		}
	}
	seen := map[string]bool{}
	for _, row := range out.Rows {
		if seen[row.ID] {
			return fail("duplicate row id")
		}
		seen[row.ID] = true
		var declaredPlan string
		switch row.Kind {
		case KindTool:
			if !tools[row.ID] {
				return fail("tool id provenance")
			}
			name, vendor, _ := rowTitle(row.ID)
			if row.Name != name || !reflect.DeepEqual(row.VendorKey, vendor) {
				return fail("compiled title/vendor")
			}
		case KindDeclared:
			plan, ok := declaredKey(row.ID)
			if !ok || !declared[plan] {
				return fail("declared id provenance")
			}
			declaredPlan = plan
			if row.Name != (Name{EN: plan, ZH: plan, UserAuthored: true}) || row.VendorKey != nil || row.Consent != ConsentNotRequired {
				return fail("declared name/consent")
			}
		default:
			return fail("row kind")
		}
		if row.Order < 0 {
			return fail("order")
		}
		surfaces := map[Surface]bool{}
		for _, surface := range row.Surfaces {
			if surface != SurfaceDock && surface != SurfaceMenu && surface != SurfaceSettings || surfaces[surface] {
				return fail("surfaces")
			}
			surfaces[surface] = true
		}
		switch row.Consent {
		case ConsentAllowed, ConsentImplicit, ConsentDenied, ConsentUnset, ConsentNotRequired, ConsentRetired:
		default:
			return fail("consent")
		}
		if row.Consent == ConsentDenied || row.Consent == ConsentUnset || row.Reason.Code == CodeCleanupPending {
			if len(row.Accounts) > 0 {
				return fail("unpermitted values")
			}
		}
		if err := validateOutcome(row.State, row.Reason, row.NextStep, in.Now); err != nil {
			return err
		}
		var expiry *time.Time
		for _, a := range row.Accounts {
			if err := validateAccount(in, a, declaredPlan, refs); err != nil {
				return err
			}
			if a.ValueState == ValueStateCurrent {
				expiry = earlier(expiry, a.FreshUntil)
			}
			for _, w := range a.Windows {
				if w.Current {
					expiry = earlier(expiry, w.ValidUntil)
				}
			}
		}
		if !reflect.DeepEqual(expiry, row.ExpiresAt) {
			return fail("row expiry")
		}
		if row.ExpiresAt == nil {
			if row.StateAfterExpiry != nil {
				return fail("latch without deadline")
			}
		} else {
			if row.StateAfterExpiry == nil || row.StateAfterExpiry.State == StateFresh {
				return fail("missing/conservative latch")
			}
			if err := validateOutcome(row.StateAfterExpiry.State, row.StateAfterExpiry.Reason, row.StateAfterExpiry.NextStep, in.Now); err != nil {
				return err
			}
		}
	}
	summaries := map[SummaryState]Code{SummaryStateOK: CodeOK, SummaryStateReadersOff: CodeReadersOff, SummaryStateNoConsent: CodeNoConsent, SummaryStateEmpty: CodeNoDockRows, SummaryStatePending: CodeConsentChanged}
	code, ok := summaries[out.RowsSummary.State]
	if !ok || code != out.RowsSummary.Reason.Code || out.RowsSummary.Text != out.RowsSummary.Reason.Text {
		return fail("summary state/reason")
	}
	if out.RowsSummary.Text != summaryTexts[code] {
		return fail("summary message table")
	}
	var next *NextStep
	if out.RowsSummary.State != SummaryStateOK && out.RowsSummary.State != SummaryStatePending {
		next = &NextStep{Action: ActionOpenSettingsConsent, Text: actionTexts[ActionOpenSettingsConsent]}
	}
	if !reflect.DeepEqual(next, out.RowsSummary.NextStep) {
		return fail("summary next step")
	}
	if in.ConsentChanged {
		for _, row := range out.Rows {
			if row.Kind != KindDeclared {
				return fail("fail-closed tool row")
			}
		}
	}
	if in.ReadersOff {
		for _, row := range out.Rows {
			if row.Kind != KindDeclared {
				return fail("readers-off tool row")
			}
		}
	}
	return nil
}

func validateOutcome(state State, reason Reason, step *NextStep, now time.Time) error {
	expected, ok := outcomes[reason.Code]
	if !ok || expected.State != state || expected.Text != reason.Text {
		return fmt.Errorf("invalid rows field: state/reason message table")
	}
	if step == nil {
		if state != StateFresh {
			return fmt.Errorf("invalid rows field: missing next step")
		}
		return nil
	}
	if step.Action != expected.Action {
		return fmt.Errorf("invalid rows field: action")
	}
	text := actionTexts[step.Action]
	if reason.Code == CodeNoReader {
		text = Text{EN: "Reader support is not available yet", ZH: "暂不支持此读取器"}
	}
	if reason.Code == CodeNoManualReading {
		text = Text{EN: "Add a manual reading in Settings", ZH: "在设置中填写手动读数"}
	}
	if step.Text != text {
		return fmt.Errorf("invalid rows field: action message table")
	}
	if step.DisabledReason != nil {
		if step.Action != ActionRefresh {
			return fmt.Errorf("invalid rows field: disabled non-refresh")
		}
		switch *step.DisabledReason {
		case DisabledReasonCooldown, DisabledReasonReadOnly, DisabledReasonOffline:
		default:
			return fmt.Errorf("invalid rows field: disabled reason")
		}
	}
	if step.AvailableAt != nil && (!validTime(step.AvailableAt) || !step.AvailableAt.After(now)) {
		return fmt.Errorf("invalid rows field: action clock")
	}
	return nil
}

func validateAccount(in Input, a Account, declared string, refs map[string]bool) error {
	fail := func(field string) error { return fmt.Errorf("invalid rows account field: %s", field) }
	if a.Route == "" || safeRoute(a.Route) != a.Route {
		return fail("account route")
	}
	if declared != "" && a.Route != RouteManual {
		return fail("declared route")
	}
	for _, ref := range []*string{a.SubscriptionRef, a.AccountLocator} {
		if ref != nil && (in.IdentityOff || !refPattern.MatchString(*ref) || !refs[*ref]) {
			return fail("existing reference")
		}
	}
	if declared != "" {
		if !reflect.DeepEqual(a.Plan, planValue("", declared)) {
			return fail("declared plan")
		}
	} else if a.Plan.ID == "unknown" {
		if a.Plan.Name != nil {
			return fail("unknown plan name")
		}
	} else {
		raw := a.Plan.ID
		if strings.HasPrefix(raw, "cursor-") {
			raw = "cursor " + strings.TrimPrefix(raw, "cursor-")
		}
		expected := planValue(raw, "")
		if expected.ID == "unknown" || !reflect.DeepEqual(a.Plan, expected) {
			return fail("plan allow-list")
		}
	}
	if a.Credits != nil {
		if finite(a.Credits.Balance, 0, 1e15) == nil {
			return fail("credits balance")
		}
		switch a.Credits.Unit {
		case "money", "credits", "other":
		default:
			return fail("credits unit")
		}
	}
	if a.ObservedAt != nil && (!validTime(a.ObservedAt) || a.ObservedAt.After(in.Now)) {
		return fail("observation clock")
	}
	if a.FreshUntil != nil && !validTime(a.FreshUntil) {
		return fail("freshness clock")
	}
	if a.LastFailure != nil {
		if _, ok := outcomes[a.LastFailure.Code]; !ok || !validTime(&a.LastFailure.At) || a.LastFailure.At.After(in.Now) {
			return fail("failure code/time")
		}
	}
	switch a.ValueState {
	case ValueStateCurrent:
		if a.ObservedAt == nil || a.FreshUntil == nil || !a.FreshUntil.After(in.Now) || a.LastFailure != nil {
			return fail("current evidence")
		}
	case ValueStateRetained:
	case ValueStateNone:
		if len(a.Windows) > 0 || a.Credits != nil {
			return fail("none contains numbers")
		}
	default:
		return fail("valueState")
	}
	seen := map[string]bool{}
	for _, w := range a.Windows {
		if !limitKeys[w.LimitKey] || !poolKeys[w.PoolKey] {
			return fail("window key allow-lists")
		}
		_, expectedLabel := role(string(w.Role))
		if w.LimitKey == "other" {
			expectedLabel = Text{EN: "Other limit", ZH: "其他限额"}
		}
		switch w.Role {
		case RoleSession, RoleDaily, RoleWeekly, RoleMonthly, RoleOther:
		default:
			return fail("window role")
		}
		if expectedLabel != w.Label {
			return fail("window label")
		}
		duration := "unknown"
		if w.DurationSeconds != nil {
			if *w.DurationSeconds <= 0 || *w.DurationSeconds > 366*86400 {
				return fail("duration")
			}
			duration = strconv.FormatInt(*w.DurationSeconds, 10)
		}
		base := string(w.Role) + ":" + duration + ":" + w.LimitKey + ":" + w.PoolKey
		if w.ID != base {
			suffix := strings.TrimPrefix(w.ID, base+":")
			ordinal, err := strconv.Atoi(suffix)
			if err != nil || ordinal < 1 || suffix != strconv.Itoa(ordinal) {
				return fail("window id")
			}
		}
		if seen[w.ID] {
			return fail("duplicate window id")
		}
		seen[w.ID] = true
		switch w.ResetMode {
		case ResetModeFixed, ResetModeRolling, ResetModeUnknown:
		default:
			return fail("reset mode")
		}
		if w.RemainingPercent != nil && finite(w.RemainingPercent, 0, 100) == nil {
			return fail("percentage")
		}
		for _, at := range []*time.Time{w.ResetsAt, w.ObservedAt, w.ValidUntil} {
			if at != nil && !validTime(at) {
				return fail("window time")
			}
		}
		if w.ObservedAt != nil && w.ObservedAt.After(in.Now) {
			return fail("future window observation")
		}
		var until *time.Time
		if a.FreshUntil != nil {
			until = earlier(a.FreshUntil, w.ResetsAt)
		}
		if !reflect.DeepEqual(until, w.ValidUntil) {
			return fail("window validity")
		}
		current := a.ValueState == ValueStateCurrent && w.RemainingPercent != nil && w.ValidUntil != nil && in.Now.Before(*w.ValidUntil)
		if w.Current != current {
			return fail("window current")
		}
	}
	return nil
}
func validTime(value *time.Time) bool {
	return value != nil && !value.IsZero() && value.Year() > 1 && value.Year() <= 9999
}

// ValidateCapture additionally prevents a deterministic capture from silently
// blessing unknown input as a deliberate generic failure. Runtime lookup still
// degrades unknown values to other; only reader_errors' canonical errorCode
// "other" (canceled/untyped) is an intentional generic input.
func ValidateCapture(in Input, out Projection) error {
	if err := Validate(in, out); err != nil {
		return err
	}
	for _, row := range out.Rows {
		generic := row.Reason.Code == CodeOther
		for _, a := range row.Accounts {
			generic = generic || a.LastFailure != nil && a.LastFailure.Code == CodeOther
		}
		if !generic {
			continue
		}
		intentional := false
		for _, p := range in.Profiles {
			if CanonicalTool(p.ToolID) != row.ID || p.LatestAttempt != AttemptResultFailed || p.LastFailure == nil {
				continue
			}
			if IntentionalOther(SignalError, p.LastFailure.Code) {
				intentional = true
				continue
			}
			code := profileFailure(p)
			if code == CodeOther {
				return fmt.Errorf("capture contains unknown profile failure for %s", row.ID)
			}
		}
		for _, s := range in.Sources {
			if CanonicalTool(s.ToolID) != row.ID {
				continue
			}
			if IntentionalOther(SignalError, s.ErrorCode) {
				intentional = true
				continue
			}
			outcome, known := sourceOutcome(s)
			if outcome.Code == CodeOther && !known {
				_, registered := signalCodes[signalKey{SignalStatus, s.Status}]
				if s.ErrorCode != "" || !registered {
					return fmt.Errorf("capture contains unknown source failure for %s", row.ID)
				}
			}
		}
		if !intentional {
			return fmt.Errorf("capture contains non-intentional other for %s", row.ID)
		}
	}
	return nil
}

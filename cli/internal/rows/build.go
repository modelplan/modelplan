// SPDX-License-Identifier: MIT
package rows

import (
	"sort"
	"time"
)

type candidate struct {
	id, declared string
	catalogue    CatalogueEntry
	hasCatalogue bool
	consent      ConsentRecord
	profiles     []ProfileState
	accounts     []AccountInput
	sources      []SourceState
	veto         Code
	keychain     Code
}

// Build projects one immutable set of facts. It performs no I/O, identity
// allocation or mutation of Input. The publishing adapter owns the retry fence.
func Build(in Input) Projection {
	// Mixed consent views are not a usable snapshot. The command fence owns
	// retries; the pure builder can still fail closed instead of exporting data.
	if !in.ConsentChanged {
		for _, record := range in.Consents {
			if record.Generation != in.ConsentGeneration {
				in.ConsentChanged = true
				break
			}
		}
	}
	out := Projection{RowsVersion: Version, ConsentGeneration: in.ConsentGeneration, Rows: []Row{}}
	tools := map[string]*candidate{}
	declared := map[string]*candidate{}
	tool := func(id string) *candidate {
		id = CanonicalTool(id)
		if !toolPattern.MatchString(id) {
			return nil
		}
		if c := tools[id]; c != nil {
			return c
		}
		c := &candidate{id: id, consent: ConsentRecord{State: ConsentUnset}}
		tools[id] = c
		return c
	}
	plan := func(id string) *candidate {
		if id == "" {
			return nil
		}
		if c := declared[id]; c != nil {
			return c
		}
		c := &candidate{id: declaredID(id), declared: id, consent: ConsentRecord{State: ConsentNotRequired}}
		declared[id] = c
		return c
	}
	for _, v := range in.Catalogue {
		if c := tool(v.ToolID); c != nil {
			c.catalogue = v
			c.hasCatalogue = true
		}
	}
	for _, v := range in.Consents {
		switch v.State {
		case ConsentAllowed, ConsentImplicit, ConsentDenied, ConsentUnset, ConsentNotRequired, ConsentRetired:
		default:
			v.State = ConsentUnset
		}
		if c := tool(v.ToolID); c != nil {
			c.consent = v
		}
	}
	for _, v := range in.DeclaredPlanIDs {
		plan(v)
	}
	// Only trusted catalogue/consent keys can turn an account into a tool row.
	// A provider string in a reading cannot create a new canonical tool identity.
	for _, a := range in.Accounts {
		var c *candidate
		if a.DeclaredPlanID != "" {
			c = plan(a.DeclaredPlanID)
		} else {
			c = tools[CanonicalTool(a.ToolID)]
		}
		if c != nil && permitted(c.consent.State) {
			c.accounts = append(c.accounts, a)
		}
	}
	for _, p := range in.Profiles {
		var c *candidate
		if p.DeclaredPlanID != "" {
			c = declared[p.DeclaredPlanID]
		} else {
			c = tools[CanonicalTool(p.ToolID)]
		}
		if c != nil {
			c.profiles = append(c.profiles, p)
		}
	}
	for _, s := range in.Sources {
		if c := tools[CanonicalTool(s.ToolID)]; c != nil {
			c.sources = append(c.sources, s)
		}
	}
	for _, a := range in.Admissions {
		if c := tools[CanonicalTool(a.ToolID)]; c != nil && a.Veto != "" {
			mapped, _ := MapSignal(SignalBlocked, a.Veto)
			if mapped.Code == CodeNoReader {
				c.catalogue.ReaderExists = false
			} else {
				c.veto = mapped.Code
			}
		}
	}
	for _, k := range in.KeychainBlocks {
		// Only Claude's native reader uses ModelPlan-managed Keychain access.
		if CanonicalTool(k.ToolID) != "claude" {
			continue
		}
		if c := tools[CanonicalTool(k.ToolID)]; c != nil && k.Blocked {
			mapped, _ := MapSignal(SignalKeychain, k.Status)
			c.keychain = mapped.Code
		}
	}
	allowed, declaredCount := 0, len(declared)
	for _, c := range tools {
		if in.ReadersOff || in.ConsentChanged {
			continue
		}
		allow := permitted(c.consent.State)
		if allow {
			allowed++
		}
		// Persisted denials/cleanup remain inspectable even after detection vanishes.
		if !allow && c.consent.State != ConsentDenied && !c.consent.CleanupPending && !c.catalogue.Detected {
			continue
		}
		out.Rows = append(out.Rows, buildCandidate(in, c))
	}
	for _, c := range declared {
		out.Rows = append(out.Rows, buildCandidate(in, c))
	}
	sort.Slice(out.Rows, func(i, j int) bool {
		if out.Rows[i].Order != out.Rows[j].Order {
			return out.Rows[i].Order < out.Rows[j].Order
		}
		return out.Rows[i].ID < out.Rows[j].ID
	})
	for i := range out.Rows {
		if out.Rows[i].Kind == KindDeclared {
			out.Rows[i].Order = 1000 + i
		}
	}
	out.RowsSummary = summary(in, out.Rows, allowed, declaredCount)
	return out
}

func permitted(c Consent) bool {
	return c == ConsentAllowed || c == ConsentImplicit || c == ConsentNotRequired || c == ConsentRetired
}

func buildCandidate(in Input, c *candidate) Row {
	name, vendor, order := rowTitle(c.id)
	row := Row{ID: c.id, Kind: KindTool, Order: order, Name: name, VendorKey: vendor, Consent: c.consent.State, Surfaces: []Surface{SurfaceSettings}, Accounts: []Account{}}
	f := classification{Consent: c.consent.State, Outdated: c.consent.Outdated, Cleanup: c.consent.CleanupPending, Detected: c.catalogue.Detected, Retired: !c.hasCatalogue || c.catalogue.Retired, ReaderExists: c.catalogue.ReaderExists, Veto: c.veto, Latest: AttemptResultNever, Keychain: c.keychain}
	f.Retired = f.Retired || c.consent.State == ConsentRetired
	if c.declared != "" {
		row.Kind = KindDeclared
		row.Name = Name{EN: c.declared, ZH: c.declared, UserAuthored: true}
		row.VendorKey = nil
		row.Order = 1000
		f.Declared = true
	}
	// Contextual source/catalogue facts can supply real admission vetoes,
	// but reader status strings never establish reader consent.
	for _, source := range c.sources {
		out, known := sourceOutcome(source)
		if known && admissionCode(out.Code) && source.Status != "consent_required" {
			f.Veto = out.Code
		}
		if known && out.Code == CodeNoReader {
			f.ReaderExists = false
		}
	}
	if detected, known := MapSignal(SignalDetection, c.catalogue.Status); known && admissionCode(detected.Code) {
		f.Veto = detected.Code
	}
	if in.PrivacyBlocked {
		f.Veto = CodePrivacyBlocked
	}
	allow := permitted(c.consent.State) && !c.consent.CleanupPending
	if allow {
		row.Surfaces = []Surface{SurfaceDock, SurfaceMenu, SurfaceSettings}
	}
	if !f.Declared && f.Retired && allow {
		row.Consent = ConsentRetired
	}
	// Revoked/outdated/vetoed facts can never republish cached numbers.
	exportValues := allow && !f.Outdated && f.Veto == ""
	if f.Declared {
		exportValues = f.Veto != CodePrivacyBlocked
	}
	if exportValues {
		row.Accounts = buildAccounts(in, c)
		for _, a := range row.Accounts {
			switch a.ValueState {
			case ValueStateCurrent:
				f.Current++
			case ValueStateRetained:
				f.Retained++
				if a.ObservedAt == nil {
					f.UnknownTime = true
				}
			default:
				f.None++
			}
		}
	}
	var latest *time.Time
	for _, p := range c.profiles {
		if p.LoginChanged || p.GenerationChanged {
			continue
		}
		if p.AttemptedAt != nil && (latest == nil || p.AttemptedAt.After(*latest)) {
			latest = p.AttemptedAt
			f.Latest = p.LatestAttempt
			f.Failure = profileFailure(p)
		} else if latest == nil && p.LatestAttempt != "" && p.LatestAttempt != AttemptResultNever {
			f.Latest = p.LatestAttempt
			f.Failure = profileFailure(p)
		}
		f.Busy = f.Busy || p.Busy || p.CoolingDown
	}
	if f.Latest == AttemptResultNever && len(c.profiles) == 0 {
		for _, s := range c.sources {
			if s.ErrorCode != "" {
				f.Latest = AttemptResultFailed
				out, _ := MapSignal(SignalError, s.ErrorCode)
				f.Failure = out.Code
				break
			}
			if out, known := sourceOutcome(s); known {
				switch out.State {
				case StateFailed, StateNeedsAction:
					f.Latest = AttemptResultFailed
					f.Failure = out.Code
				case StateEmpty:
					f.Latest = AttemptResultSucceeded
				case StatePending:
					if out.Code == CodeReaderBusy {
						f.Busy = true
					}
				}
			} else if s.Status != "" || s.Reason != "" {
				f.Latest = AttemptResultFailed
				f.Failure = CodeOther
			}
		}
	}
	for _, a := range c.accounts {
		if !a.Estimated {
			continue
		}
		for _, p := range c.profiles {
			if p.ProfileKey == a.ProfileKey && !p.LoginChanged && !p.GenerationChanged && p.LatestAttempt == AttemptResultSucceeded && observed(p.ObservedAt, in.Now) != nil && p.WithinFreshness && knownTime(p.FreshUntil) != nil && in.Now.Before(*p.FreshUntil) {
				f.Estimated = true
			}
		}
	}
	// Keychain busy is explicitly not a credential-store denial or read failure.
	if f.Keychain == CodeReaderBusy {
		f.Keychain = ""
		f.Busy = true
		f.Latest = AttemptResultNever
	}
	outcome := classify(f)
	applyOutcome(&row, in, c, outcome)
	for _, a := range row.Accounts {
		if a.ValueState == ValueStateCurrent {
			row.ExpiresAt = earlier(row.ExpiresAt, a.FreshUntil)
		}
		for _, w := range a.Windows {
			if w.Current {
				row.ExpiresAt = earlier(row.ExpiresAt, w.ValidUntil)
			}
		}
	}
	if row.ExpiresAt != nil {
		expired := f
		expired.Retained += expired.Current
		expired.Current = 0
		latch := classify(expired)
		if latch.State == StateFresh {
			latch = Describe(CodeStaleReading)
		}
		latchInput := in
		latchInput.Now = *row.ExpiresAt
		row.StateAfterExpiry = &ExpiryState{State: latch.State, Reason: Reason{Code: latch.Code, Text: latch.Text}, NextStep: nextStep(latchInput, c, latch)}
	}
	return row
}

func profileFailure(p ProfileState) Code {
	if p.LastFailure != nil {
		if out, ok := MapSignal(SignalError, p.LastFailure.Code); ok {
			return out.Code
		}
		if out, ok := MapSignal(SignalStatus, p.LastFailure.Code); ok {
			return out.Code
		}
	}
	return CodeOther
}
func admissionCode(code Code) bool {
	switch code {
	case CodePrivacyBlocked, CodeCatalogueOff, CodeUpdateRequired, CodeKeyMissing, CodeCodexBarNotAudited, CodeCodexBarNotRead, CodeCodexBarAccessUnknown, CodeBrowserSessionConsentRequired, CodeNotAdmitted:
		return true
	}
	return false
}
func sourceOutcome(s SourceState) (Outcome, bool) {
	if s.ErrorCode != "" {
		return MapSignal(SignalError, s.ErrorCode)
	}
	if s.Blocked != "" {
		return MapSignal(SignalBlocked, s.Blocked)
	}
	// A bounded reason code is more specific than the generic status channel.
	if out, ok := MapSignal(SignalError, s.Reason); ok {
		return out, true
	}
	return MapSignal(SignalStatus, s.Status)
}
func earlier(a, b *time.Time) *time.Time {
	if b == nil {
		return a
	}
	if a == nil || b.Before(*a) {
		v := b.UTC()
		return &v
	}
	return a
}
func applyOutcome(row *Row, in Input, c *candidate, outcome Outcome) {
	row.State = outcome.State
	row.Reason = Reason{Code: outcome.Code, Text: outcome.Text}
	row.NextStep = nextStep(in, c, outcome)
}

var actionTexts = map[Action]Text{
	ActionOpenSettingsConsent:  {EN: "Review reader consent in Settings", ZH: "在设置中检查读取授权"},
	ActionOpenSettingsKeychain: {EN: "Allow Keychain for Claude Code in Settings", ZH: "在设置中允许 Claude Code 访问钥匙串"},
	ActionOpenTool:             {EN: "Open the tool to renew its sign-in", ZH: "打开工具以更新登录"},
	ActionInstallRuntime:       {EN: "Install the tool runtime", ZH: "安装工具运行时"},
	ActionRefresh:              {EN: "Refresh when permitted", ZH: "在允许时刷新"},
	ActionUpdateCLI:            {EN: "Update ModelPlan CLI", ZH: "更新 ModelPlan CLI"},
	ActionNone:                 {EN: "Wait for the next available reading", ZH: "等待下一次可用读数"},
}

func nextStep(in Input, c *candidate, outcome Outcome) *NextStep {
	if outcome.State == StateFresh {
		return nil
	}
	step := &NextStep{Action: outcome.Action, Text: actionTexts[outcome.Action]}
	if outcome.Code == CodeNoReader {
		step.Text = Text{EN: "Reader support is not available yet", ZH: "暂不支持此读取器"}
	}
	if outcome.Code == CodeNoManualReading {
		step.Text = Text{EN: "Add a manual reading in Settings", ZH: "在设置中填写手动读数"}
	}
	if outcome.Action == ActionRefresh {
		cooling := false
		for _, p := range c.profiles {
			at := knownTime(p.NextAttemptAt)
			cooling = cooling || p.Busy || p.CoolingDown && (at == nil || at.After(in.Now))
			if at := knownTime(p.NextAttemptAt); at != nil && at.After(in.Now) {
				if step.AvailableAt == nil || at.After(*step.AvailableAt) {
					step.AvailableAt = at
				}
			}
		}
		var disabled DisabledReason
		switch {
		case in.ReadOnly:
			disabled = DisabledReasonReadOnly
		case in.Offline:
			disabled = DisabledReasonOffline
		case cooling || step.AvailableAt != nil:
			disabled = DisabledReasonCooldown
		}
		if disabled != "" {
			step.DisabledReason = &disabled
		}
	}
	return step
}

var summaryTexts = map[Code]Text{
	CodeOK:             {EN: "Readings and actions are available", ZH: "读数或操作可用"},
	CodeConsentChanged: {EN: "Consent changed; waiting for a stable snapshot", ZH: "授权已更改，等待稳定快照"},
	CodeReadersOff:     {EN: "Tool readers are disabled", ZH: "工具读取器已停用"},
	CodeNoConsent:      {EN: "Choose tools to allow in Settings", ZH: "在设置中选择允许读取的工具"},
	CodeNoDockRows:     {EN: "No Dock reading or available action yet", ZH: "尚无 Dock 读数或可用操作"},
}

func summary(in Input, rows []Row, allowed, declared int) RowsSummary {
	state, code := SummaryStateOK, CodeOK
	switch {
	case in.ConsentChanged:
		state, code = SummaryStatePending, CodeConsentChanged
	case in.ReadersOff:
		state, code = SummaryStateReadersOff, CodeReadersOff
	case allowed == 0 && declared == 0:
		state, code = SummaryStateNoConsent, CodeNoConsent
	default:
		usable := false
		for _, row := range rows {
			for _, surface := range row.Surfaces {
				if surface == SurfaceDock && (hasValue(row.Accounts) || row.NextStep != nil && row.NextStep.Action != ActionNone) {
					usable = true
				}
			}
		}
		if !usable {
			state, code = SummaryStateEmpty, CodeNoDockRows
		}
	}
	text := summaryTexts[code]
	result := RowsSummary{State: state, Reason: Reason{Code: code, Text: text}, Text: text}
	if state != SummaryStateOK && state != SummaryStatePending {
		result.NextStep = &NextStep{Action: ActionOpenSettingsConsent, Text: actionTexts[ActionOpenSettingsConsent]}
	}
	return result
}

func hasValue(accounts []Account) bool {
	for _, a := range accounts {
		if a.ValueState != ValueStateNone {
			return true
		}
	}
	return false
}

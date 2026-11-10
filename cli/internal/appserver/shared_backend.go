// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"sync"
	"sync/atomic"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/resetevents"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// SharedConfig adapts the existing production constructors. It owns no parallel
// consent store, route catalogue, reader implementation or publication policy.
type SharedConfig struct {
	now func() time.Time
	// Reported receives the report the rows were just built from, at most once a minute, so
	// quota history is kept without a second read.
	Reported func(quota.Report, time.Time)
	// Activity is an admitted, cache-only observer, independent of quota refresh/rate.
	Activity          func(context.Context, consent.Admission, time.Time) []rows.ActivityInput
	ResetPublication  func() (*digest.Digest, error)
	Detect            func() detect.Report
	Paths             func(consent.Admission) quota.Paths
	Cleanup           func(string, bool) error
	Offline, ReadOnly bool
}

func (b *SharedBackend) now() time.Time {
	if b.config.now != nil {
		return b.config.now()
	}
	return time.Now()
}

type SharedBackend struct {
	activityMu    sync.Mutex
	activity      []rows.ActivityInput
	activityStamp Stamp
	activityBusy  atomic.Bool
	reportBusy    atomic.Bool
	reportedAt    time.Time
	config        SharedConfig
	changes       chan struct{}
	once          sync.Once
	// Bound by the constructor before Serve. Credentials remain in the
	// scheduler's one-use memory callback and are never persisted here.
	CredentialSink  CredentialReceiver
	RefreshDeadline func(string) (time.Time, bool, bool)
}

func NewSharedBackend(config SharedConfig) (*SharedBackend, error) {
	if config.Detect == nil || config.Paths == nil || config.Cleanup == nil {
		return nil, errors.New("backend_unavailable")
	}
	var state consent.State
	var err error
	if config.ReadOnly {
		state, err = consent.Load(consent.Path())
		if err == nil && state.StoreEpoch == "" {
			err = errors.New("consent_unavailable")
		}
	} else {
		state, err = consent.EnsureStore(consent.Path())
	}
	if err != nil {
		return nil, err
	}
	b := &SharedBackend{config: config, changes: make(chan struct{}, 1)}
	if !config.ReadOnly {
		_ = consent.RetryCleanup(consent.Path(), config.Cleanup)
	}
	return b, nil
}
func (b *SharedBackend) Capabilities() []string {
	caps := []string{"rows", "consent", "credentials", "diagnostics", "refreshDecisionsV1", CapabilityWindowSources, CapabilityCockpitDetailsV1, CapabilityAccountTodayV1, CapabilityCockpitForecastV1, CapabilityForecastProducerV1, CapabilityCockpitHistoryV1, CapabilityCockpitModelsV1, CapabilityCockpitSessionsV1, CapabilityCockpitPeaksV1}
	if b.config.ResetPublication != nil {
		caps = append(caps, CapabilityResetEvents, CapabilityResetEventLinksV1)
	}
	return caps
}
func (b *SharedBackend) notify() {
	select {
	case b.changes <- struct{}{}:
	default:
	}
}
func stampOf(f consent.Fence) Stamp { return Stamp{Epoch: f.StoreEpoch, Generation: f.Generation} }
func fenceOf(s Stamp) consent.Fence {
	return consent.Fence{StoreEpoch: s.Epoch, Generation: s.Generation}
}

func (b *SharedBackend) Publish(ctx context.Context, stamp Stamp, enqueue func() error) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	called := false
	err := consent.PublishContext(ctx, fenceOf(stamp), func() error {
		called = true
		if err := ctx.Err(); err != nil {
			return err
		}
		return enqueue()
	})
	if err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		if called {
			return err
		}
		switch {
		case errors.Is(err, consent.ErrBusy):
			return ProtocolError{wire.CodeBusy}
		case errors.Is(err, consent.ErrChanged):
			return ProtocolError{wire.CodeConsentChanged}
		default:
			return err
		}
	}
	return nil
}

func (b *SharedBackend) Get(ctx context.Context) (View, error) {
	if err := ctx.Err(); err != nil {
		return View{}, err
	}
	result := consent.BuildStable(func(admission consent.Admission) View { return b.buildView(admission, false) }, func(admission consent.Admission) View { return b.buildView(admission, true) })
	if ctx.Err() != nil {
		return View{}, ctx.Err()
	}
	if result.Stamp.Epoch == "" {
		return View{}, ProtocolError{wire.CodeInternal}
	}
	return result, nil
}
func (b *SharedBackend) buildView(admission consent.Admission, changed bool) View {
	p := b.paths(admission)
	detection := b.config.Detect()
	detected := map[string]bool{}
	in := admission.RowsInput(b.now())
	in.ReadOnly = b.config.ReadOnly
	in.Offline = b.config.Offline
	in.IdentityOff = quota.IdentityOff()
	if !changed {
		in.Activities = b.activityFor(stampOf(admission.Fence()))
	}
	for _, tool := range detection.Tools {
		id := rows.CanonicalTool(tool.ProviderID)
		detected[id] = tool.Detected
		_, _, native := quota.NativeReader(id)
		exists := native || id == "codex" || tool.Preferred == "codexbar" && tool.HelperStatus() == ""
		in.Catalogue = append(in.Catalogue, rows.CatalogueEntry{ToolID: id, ReaderID: tool.ReaderID, Backend: tool.Preferred, Detected: tool.Detected, ReaderExists: exists, Status: tool.Status})
	}
	// Implicit local permission becomes a candidate only when a real tool/source
	// establishes it. A blank home must not acquire phantom Claude/Codex cards.
	consents := in.Consents[:0]
	for _, record := range in.Consents {
		if record.State != rows.ConsentImplicit || detected[record.ToolID] {
			consents = append(consents, record)
		}
	}
	in.Consents = consents
	if changed {
		in = admission.ChangedRowsInput(in.Now)
		in.ReadOnly = b.config.ReadOnly
		in.Offline = b.config.Offline
		in.IdentityOff = quota.IdentityOff()
	}
	var report quota.Report
	if !changed && admission.Mode() != consent.Off {
		quota.AppendManagedRows(&in, p)
		report = quota.ReadPermitted(p, in.Now)
		b.reported(report, in.Now)
		projectionReport := report
		if admission.Allows("codex", consent.Local) {
			// The generic native adapter can report the ungranted runtime
			// route as off even when local history is independently allowed.
			// Do not turn that route-specific status into a tool-wide veto.
			sources := make([]quota.SourceStatus, 0, len(report.Sources))
			for _, source := range report.Sources {
				if source.Source == "native:codex" && source.Status == "off" && source.Reason == "reader-consent-or-privacy" {
					continue
				}
				sources = append(sources, source)
			}
			projectionReport.Sources = sources
		}
		appendReportRows(&in, projectionReport, false)
	} else {
		appendReportRows(&in, quota.ReadDeclared(p, in.Now), true)
	}
	// U2's managed adapter supplies measurements; the reviewed read path supplies
	// the route. Raw Source strings never become display route codes.
	for i := range in.Accounts {
		a := &in.Accounts[i]
		if a.DeclaredPlanID == "" && (a.Route == "" || a.Route == rows.RouteUnknown) {
			a.Route = routeForSource(a.Source)
		}
		if a.DeclaredPlanID == "" && a.ToolID == "kimi" && admission.State().Tools["kimi"].KeyEnv != "" {
			a.Route = rows.RouteAPIKeyAPI
		}
	}
	if !changed {
		if selections, err := quota.SelectionsWithAdmission(p, admission); err == nil {
			for _, selected := range selections {
				// Codex has a dedicated runtime reader outside the generic native
				// reader registry. Its absence from that registry is not a veto of
				// the separately admitted runtime or local-history routes.
				if selected.Provider == "codex" && selected.Backend == quota.BackendNative && selected.Blocked == "no-native-reader" {
					continue
				}
				// A denied generic runtime route must not veto the independently
				// admitted local-history route. ReadPermitted still checks each
				// scope and the row builder enforces tool denial and cleanup.
				if selected.Provider == "codex" && selected.Backend == quota.BackendNative && selected.Blocked == "reader-consent-or-privacy" && admission.Allows("codex", consent.Local) {
					continue
				}
				in.Admissions = append(in.Admissions, rows.Admission{ToolID: selected.Provider, Veto: selected.Blocked})
			}
		}
	}
	projection := rows.Build(in)
	var resetEvents *[]rows.ResetEvent
	var publicModels []digest.Model
	droppedResetConfirmations := 0
	if !changed && b.config.ResetPublication != nil {
		if d, err := b.config.ResetPublication(); err == nil && d != nil {
			publicModels = d.Models
			events, dropped := resetevents.Project(d, projection, in.Now)
			droppedResetConfirmations = dropped
			resetEvents = &events
		}
	}
	facts := wire.ConsentFacts{TextVersion: consent.TextVersion, Scopes: []wire.ConsentScope{}}
	scopes := []string{}
	diagnostics := []wire.ScopeDiag{}
	state := admission.State()
	for _, fact := range admission.ScopeFacts(detected) {
		if id, pending := quota.PolicyPending(fact.Tool); pending && id == fact.Scope {
			reason := "policy_pending"
			fact.Disabled = &reason
		}
		route := wireRoute(fact.Route)
		scope := wire.ConsentScope{Scope: fact.Scope, Tool: fact.Tool, Route: route, Detected: fact.Detected, Retired: fact.Retired, State: wire.ConsentState(fact.State), DefaultCheck: fact.DefaultCheck, CleanupPending: fact.CleanupPending}
		if fact.Keychain != nil {
			choice := wire.KeychainUnset
			switch *fact.Keychain {
			case "allowed":
				choice = wire.KeychainAllow
			case "denied":
				choice = wire.KeychainDeny
			}
			scope.Keychain = &choice
		}
		if fact.Disabled != nil {
			reason := wire.ScopeDisabledReason(*fact.Disabled)
			scope.Disabled = &reason
		}
		facts.Scopes = append(facts.Scopes, scope)
		if state.AllowsScope(fact.Scope, admission.Mode()) && scope.Disabled == nil && !scope.CleanupPending {
			scopes = append(scopes, fact.Scope)
		}
		diag := wire.ScopeDiag{Scope: fact.Scope, State: rows.StatePending, Code: rows.CodeNotReadYet}
		for _, row := range projection.Rows {
			if row.ID == fact.Tool {
				diag.State, diag.Code = row.State, row.Reason.Code
				for _, account := range row.Accounts {
					if account.Route == route && account.ObservedAt != nil && (diag.LastRead == nil || account.ObservedAt.After(*diag.LastRead)) {
						diag.LastRead = account.ObservedAt
					}
				}
			}
		}
		if fact.State == "denied" {
			diag.State, diag.Code = rows.StateNeedsConsent, rows.CodeConsentDenied
		}
		if scope.Disabled != nil {
			diag.State, diag.Code = rows.StateOff, rows.CodeNotAdmitted
		}
		for _, profile := range in.Profiles {
			if profile.ToolID == fact.Tool && profile.NextAttemptAt != nil && (diag.NextDueAt == nil || profile.NextAttemptAt.After(*diag.NextDueAt)) {
				diag.NextDueAt = profile.NextAttemptAt
			}
		}
		diagnostics = append(diagnostics, diag)
	}
	if !changed {
		b.populateRefreshDeadlines(&projection, p, admission, scopes, in.Now)
		if !speed.Off() {
			ledger, ok := speed.LoadPerf(p.Cache)
			if ok && !ledger.Since.IsZero() {
				perf := (speed.PerfView{Ledger: ledger, OK: true, Recording: true, Now: in.Now}).Admitted(admission)
				attachAccountToday(&projection, report.Accounts, perf)
			}
		}
	}
	health := wire.Health{State: wire.HealthReady, Code: "ok"}
	for _, fact := range facts.Scopes {
		if fact.CleanupPending {
			health = wire.Health{State: wire.HealthDegraded, Code: "cleanup_pending"}
			break
		}
	}
	if admission.Mode() == consent.Off {
		health.Code = "readers_off"
	}
	if changed {
		health = wire.Health{State: wire.HealthDegraded, Code: "consent_changed"}
	}
	// Evaluation time is not a displayed fact; keeping it would make every
	// otherwise identical backend view look changed to rows subscribers.
	report.EvaluatedAt = time.Time{}
	return View{QuotaReport: report, PublicModels: publicModels, Stamp: stampOf(admission.Fence()), Projection: projection, ResetEvents: resetEvents, DroppedResetConfirmations: droppedResetConfirmations, Consent: facts, Scopes: scopes, Diagnostics: diagnostics, Health: health}
}

func (b *SharedBackend) paths(admission consent.Admission) quota.Paths {
	p := b.config.Paths(admission)
	// The constructor binds the broker callback before Serve. Retain that
	// capability; an absent callback stays closed instead of opening a helper.
	if p.ReaderAccess != nil {
		grants := map[string]quota.ReaderGrant{}
		for provider, grant := range p.ReaderAccess.Grants {
			if provider == "claude" && grant.Credential == nil {
				grant.Credential = func(context.Context) ([]byte, string) { return nil, "confirmation-needed" }
			}
			grants[provider] = grant
		}
		p.ReaderAccess = &quota.ReaderAccess{Grants: grants}
	}
	return p
}

func (b *SharedBackend) Grant(ctx context.Context, p wire.ConsentGrantParams) (GrantResult, error) {
	if err := ctx.Err(); err != nil {
		return GrantResult{}, err
	}
	if b.config.ReadOnly {
		return GrantResult{}, ProtocolError{wire.CodeConsentRejected}
	}
	keychain := map[string]string{}
	for scope, choice := range p.Keychain {
		keychain[scope] = string(choice)
	}
	tools := map[string]detect.Tool{}
	for _, tool := range b.config.Detect().Tools {
		if tool.Detected {
			tools[tool.ProviderID] = tool
		}
	}
	grant := consent.Grant{RequestID: p.RequestID, ExpectStoreEpoch: p.ExpectStoreEpoch, ExpectGeneration: p.ExpectGeneration, ConsentTextVersion: p.TextVersion, Allow: p.Allow, Deny: p.Deny, Forget: p.Forget, Keychain: keychain}
	receipt, err := consent.ApplyGrant(consent.Path(), grant, consent.GrantHooks{Admit: func(definition consent.ScopeDefinition) (consent.Record, error) {
		tool, ok := tools[definition.Tool]
		if !ok {
			return consent.Record{}, errors.New("unknown_tool")
		}
		if scope, pending := quota.PolicyPending(definition.Tool); pending && scope == definition.ID {
			return consent.Record{}, errors.New("policy_pending")
		}
		if definition.Class != consent.Local && (tool.Preferred != "native" || tool.Status == "update-required") {
			return consent.Record{}, errors.New("reader_unavailable")
		}
		record := consent.Record{ReaderID: tool.ReaderID, Backend: tool.Preferred}
		if definition.Class == consent.ExplicitKey {
			_, record.KeyEnv, _ = quota.NativeReader(definition.Tool)
			if record.KeyEnv == "" {
				return consent.Record{}, errors.New("reader_unavailable")
			}
		}
		return record, nil
	}, Cleanup: b.config.Cleanup})
	if err != nil && !receipt.Committed {
		return GrantResult{}, grantError(err)
	}
	result := GrantResult{Stamp: Stamp{Epoch: receipt.StoreEpoch}, Receipt: wire.ConsentReceipt{RequestID: receipt.RequestID, Committed: receipt.Committed, CommittedGeneration: receipt.CommittedGeneration, CleanupPending: receipt.CleanupPending, Code: wire.ReceiptCode(receipt.Code)}}
	if receipt.CommittedGeneration != nil {
		result.Stamp.Generation = *receipt.CommittedGeneration
	}
	if !b.config.Offline && receipt.Committed && !receipt.Replayed && keychain[consent.ScopeClaudeAccountUsageSavedLogin] == "allow" {
		result.Credentials = []CredentialNeed{{Provider: "claude", Scope: consent.ScopeClaudeAccountUsageSavedLogin, Interactive: true}}
	}
	b.notify()
	return result, nil
}
func grantError(err error) error {
	switch err.Error() {
	case "consent_stale", "stale_generation":
		return ProtocolError{wire.CodeConsentStale}
	case "request_mismatch":
		return ProtocolError{wire.CodeRequestMismatch}
	case "invalid_request":
		return ProtocolError{wire.CodeInvalidParams}
	case "stale_consent_text", "readers_off", "unknown_tool", "unknown_scope", "reader_unavailable", "keychain_not_supported", "policy_pending":
		return ProtocolError{wire.CodeConsentRejected}
	default:
		return ProtocolError{wire.CodeInternal}
	}
}

type fileStamp struct {
	path           string
	size, modified int64
	exists         bool
}

type localFileStamp struct {
	path string
	fileStamp
}

// codexLocalStamps observes metadata only for the same permitted local source
// that buildView reads. It never opens rollout contents or exposes file paths.
func (b *SharedBackend) codexLocalStamps(admission consent.Admission) []localFileStamp {
	tool, decided := admission.State().Tools["codex"]
	if !admission.Allows("codex", consent.Local) || admission.CleanupPending("codex") || (decided && (!tool.Allowed || tool.ConsentTextVersion != consent.TextVersion)) {
		return nil
	}
	paths := b.paths(admission)
	if paths.CodexHome == "" {
		return nil
	}
	files := quota.CodexRollouts(paths.CodexHome, paths.CodexThread, 8)
	sort.Strings(files)
	stamps := make([]localFileStamp, 0, len(files))
	for _, file := range files {
		info, err := os.Stat(file)
		if err == nil {
			stamps = append(stamps, localFileStamp{file, fileStamp{size: info.Size(), modified: info.ModTime().UnixNano(), exists: true}})
		}
	}
	return stamps
}

func (b *SharedBackend) Changes(ctx context.Context) <-chan struct{} {
	b.once.Do(func() {
		if b.config.Activity != nil {
			go func() {
				ticker := time.NewTicker(2 * time.Second)
				defer ticker.Stop()
				launch := func(at time.Time) {
					if b.activityBusy.CompareAndSwap(false, true) {
						go func() { defer b.activityBusy.Store(false); b.observeActivity(ctx, at) }()
					}
				}
				launch(time.Now())
				for {
					select {
					case <-ctx.Done():
						return
					case at := <-ticker.C:
						launch(at)
					}
				}
			}()
		}
		go func() {
			ticker := time.NewTicker(200 * time.Millisecond)
			defer ticker.Stop()
			var last []fileStamp
			var codexStamps []localFileStamp
			var nextCodexCheck time.Time
			var todayDeadline time.Time
			for {
				select {
				case <-ctx.Done():
					return
				case <-ticker.C:
					admission := consent.Capture()
					paths := b.paths(admission)
					now := b.now()
					tool, decided := admission.State().Tools["codex"]
					localAllowed := admission.Allows("codex", consent.Local) && !admission.CleanupPending("codex") && (!decided || tool.Allowed && tool.ConsentTextVersion == consent.TextVersion)
					if !localAllowed || paths.CodexHome == "" {
						codexStamps = nil
						nextCodexCheck = time.Time{}
					} else if !now.Before(nextCodexCheck) {
						// Match the local reader's recent files and its active thread;
						// inspect metadata only, under the same admission fence.
						codexStamps = b.codexLocalStamps(admission)
						nextCodexCheck = now.Add(time.Second)
					}
					files := []string{consent.Path(), filepath.Join(paths.Cache, "state.json"), paths.LocalFile, filepath.Join(paths.Cache, "observed"), filepath.Join(paths.Cache, "observed", "readers")}
					current := make([]fileStamp, 0, len(files))
					for _, file := range files {
						info, err := os.Stat(file)
						stamp := fileStamp{}
						if err == nil {
							stamp = fileStamp{size: info.Size(), modified: info.ModTime().UnixNano(), exists: true}
						}
						current = append(current, stamp)
					}
					for _, stamp := range codexStamps {
						observed := stamp.fileStamp
						observed.path = stamp.path
						current = append(current, observed)
					}
					if !reflect.DeepEqual(last, current) || (!todayDeadline.IsZero() && !now.Before(todayDeadline)) {
						last = current
						todayDeadline = nextAccountTodayDeadline(paths, admission, now)
						b.notify()
					}
				}
			}
		}()
	})
	return b.changes
}

func (b *SharedBackend) observeActivity(ctx context.Context, now time.Time) {
	admission := consent.Capture()
	stamp := stampOf(admission.Fence())
	values := b.config.Activity(ctx, admission, now)
	if ctx.Err() != nil {
		return
	}
	current := consent.Capture()
	if current.Fence() != admission.Fence() {
		values = nil
		stamp = stampOf(current.Fence())
	}
	b.activityMu.Lock()
	changed := b.activityStamp != stamp || !reflect.DeepEqual(b.activity, values)
	b.activity = values
	b.activityStamp = stamp
	b.activityMu.Unlock()
	if changed {
		b.Notify()
	}
}
func (b *SharedBackend) reported(report quota.Report, now time.Time) {
	if b.config.Reported == nil || !b.reportBusy.CompareAndSwap(false, true) {
		return
	}
	if !now.After(b.reportedAt.Add(time.Minute)) {
		b.reportBusy.Store(false)
		return
	}
	b.reportedAt = now
	go func() { defer b.reportBusy.Store(false); b.config.Reported(report, now) }()
}

func (b *SharedBackend) activityFor(stamp Stamp) []rows.ActivityInput {
	b.activityMu.Lock()
	defer b.activityMu.Unlock()
	if stamp != b.activityStamp {
		return nil
	}
	return append([]rows.ActivityInput(nil), b.activity...)
}

// Notify coalesces a completed shared reader operation into a fresh snapshot.
func (b *SharedBackend) Notify() { b.notify() }
func (b *SharedBackend) AcceptCredential(ctx context.Context, stamp Stamp, need CredentialNeed, result wire.CredentialResult) error {
	if b.CredentialSink == nil {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	return b.CredentialSink.AcceptCredential(ctx, stamp, need, result)
}

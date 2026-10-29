// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// SharedConfig adapts the existing production constructors. It owns no parallel
// consent store, route catalogue, reader implementation or publication policy.
type SharedConfig struct {
	Detect            func() detect.Report
	Paths             func(consent.Admission) quota.Paths
	Cleanup           func(string, bool) error
	Offline, ReadOnly bool
}

type SharedBackend struct {
	config  SharedConfig
	changes chan struct{}
	once    sync.Once
	// Set by the command after Server construction; only background requests use
	// this seam. Interactive operations are returned by Grant's committed result.
	CredentialRequest func(CredentialNeed) (string, error)
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
	return []string{"rows", "consent", "credentials", "diagnostics"}
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
	err := consent.Publish(fenceOf(stamp), func() error {
		if err := ctx.Err(); err != nil {
			return err
		}
		return enqueue()
	})
	if err != nil {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		return ProtocolError{wire.CodeConsentChanged}
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
	in := admission.RowsInput(time.Now())
	in.ReadOnly = b.config.ReadOnly
	in.Offline = b.config.Offline
	in.IdentityOff = quota.IdentityOff()
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
	if !changed && admission.Mode() != consent.Off {
		quota.AppendManagedRows(&in, p)
		appendReportRows(&in, quota.ReadPermitted(p, in.Now), false)
	} else {
		appendReportRows(&in, quota.ReadDeclared(p, in.Now), true)
	}
	// U2's managed adapter supplies measurements; the reviewed read path supplies
	// the route. Raw Source strings never become display route codes.
	for i := range in.Accounts {
		a := &in.Accounts[i]
		if a.DeclaredPlanID == "" {
			a.Route = routeForSource(a.Source)
		}
	}
	projection := rows.Build(in)
	facts := wire.ConsentFacts{Scopes: []wire.ConsentScope{}}
	scopes := []string{}
	diagnostics := []wire.ScopeDiag{}
	state := admission.State()
	for _, fact := range admission.ScopeFacts(detected) {
		route := wireRoute(fact.Route)
		scope := wire.ConsentScope{Scope: fact.Scope, Tool: fact.Tool, Route: route, Detected: fact.Detected, Retired: fact.Retired, State: wire.ConsentState(fact.State), DefaultCheck: fact.DefaultCheck, CleanupPending: fact.CleanupPending}
		if fact.Keychain != nil {
			choice := wire.KeychainChoice(*fact.Keychain)
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
	health := wire.Health{State: wire.HealthReady, Code: "ok"}
	if admission.Mode() == consent.Off {
		health.Code = "readers_off"
	}
	if changed {
		health = wire.Health{State: wire.HealthDegraded, Code: "consent_changed"}
	}
	return View{Stamp: stampOf(admission.Fence()), Projection: projection, Consent: facts, Scopes: scopes, Diagnostics: diagnostics, Health: health}
}

func (b *SharedBackend) paths(admission consent.Admission) quota.Paths {
	p := b.config.Paths(admission)
	// An app-server never invokes the legacy credential helper. A real operation
	// supplies its one-use memory callback in AcceptCredential instead.
	if p.ReaderAccess != nil {
		grants := map[string]quota.ReaderGrant{}
		for provider, grant := range p.ReaderAccess.Grants {
			if provider == "claude" {
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
	if receipt.Committed && !receipt.Replayed && keychain[consent.ScopeClaudeAccountUsageSavedLogin] == "allow" {
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
	size, modified int64
	exists         bool
}

func (b *SharedBackend) Changes(ctx context.Context) <-chan struct{} {
	b.once.Do(func() {
		go func() {
			ticker := time.NewTicker(200 * time.Millisecond)
			defer ticker.Stop()
			var last []fileStamp
			for {
				select {
				case <-ctx.Done():
					return
				case <-ticker.C:
					paths := b.paths(consent.Capture())
					files := []string{consent.Path(), paths.LocalFile, filepath.Join(paths.Cache, "observed"), filepath.Join(paths.Cache, "observed", "readers")}
					current := make([]fileStamp, 0, len(files))
					for _, file := range files {
						info, err := os.Stat(file)
						stamp := fileStamp{}
						if err == nil {
							stamp = fileStamp{size: info.Size(), modified: info.ModTime().UnixNano(), exists: true}
						}
						current = append(current, stamp)
					}
					if !reflect.DeepEqual(last, current) {
						last = current
						b.notify()
					}
				}
			}
		}()
	})
	return b.changes
}

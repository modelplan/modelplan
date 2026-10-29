// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// RefreshConfig binds scheduling to the shared production reader dispatcher.
// Run must enforce its own provider lock, admission and persisted budget again;
// a projected deadline is never permission to bypass those gates.
type RefreshConfig struct {
	Backend           Backend
	Paths             func(consent.Admission) quota.Paths
	Run               func(context.Context, quota.Paths, string, time.Time) error
	Offline, ReadOnly bool
	Changed           func()
	CredentialRequest func(CredentialNeed) (string, error)
}
type refreshJob struct {
	scope, key string
	stamp      Stamp
}
type RefreshScheduler struct {
	credentialWait map[string]bool
	config         RefreshConfig
	ctx            context.Context
	cancel         context.CancelFunc
	done           chan struct{}
	jobs           chan refreshJob
	mu             sync.Mutex
	pending        map[string]time.Time
}

func NewRefreshScheduler(ctx context.Context, config RefreshConfig) *RefreshScheduler {
	ctx, cancel := context.WithCancel(ctx)
	s := &RefreshScheduler{config: config, ctx: ctx, cancel: cancel, done: make(chan struct{}), jobs: make(chan refreshJob, len(consent.Definitions())), pending: map[string]time.Time{}, credentialWait: map[string]bool{}}
	go s.work()
	return s
}
func (s *RefreshScheduler) Close() { s.cancel(); <-s.done }
func (s *RefreshScheduler) Handler() Handler {
	return Handler{Capability: "refresh", Handle: func(ctx context.Context, raw json.RawMessage, _ Stamp) (Reply, error) {
		p, err := params[wire.RefreshRequestParams](raw)
		if err != nil {
			return Reply{}, ProtocolError{wire.CodeInvalidParams}
		}
		result, stamp, err := s.Request(ctx, p)
		return Reply{Stamp: stamp, Data: result, Receipt: true}, err
	}}
}
func (s *RefreshScheduler) Request(ctx context.Context, p wire.RefreshRequestParams) ([]wire.RefreshScheduled, Stamp, error) {
	if ctx.Err() != nil {
		return nil, Stamp{}, ctx.Err()
	}
	if s.ctx.Err() != nil {
		return nil, Stamp{}, s.ctx.Err()
	}
	if s.config.Backend == nil || s.config.Paths == nil {
		return nil, Stamp{}, ProtocolError{wire.CodeInternal}
	}
	view, err := s.config.Backend.Get(ctx)
	if err != nil {
		return nil, Stamp{}, err
	}
	admission := consent.Capture()
	stamp := stampOfFence(admission.Fence())
	if stamp != view.Stamp {
		return nil, Stamp{}, ProtocolError{wire.CodeConsentChanged}
	}
	scopes := append([]string(nil), p.Scopes...)
	if len(scopes) == 0 {
		scopes = append(scopes, view.Scopes...)
		sort.Strings(scopes)
	}
	if len(scopes) > wire.MaxRefreshScopes {
		return nil, stamp, ProtocolError{wire.CodeInvalidParams}
	}
	seen := map[string]bool{}
	for _, scope := range scopes {
		if !consent.ValidScope(scope) || seen[scope] {
			return nil, stamp, ProtocolError{wire.CodeInvalidParams}
		}
		seen[scope] = true
	}
	allowed := map[string]bool{}
	for _, scope := range view.Scopes {
		allowed[scope] = true
	}
	paths := s.paths(admission)
	now := time.Now()
	result := []wire.RefreshScheduled{}
	for _, scope := range scopes {
		scheduled := wire.RefreshScheduled{Scope: scope, At: now.UTC()}
		disable := func(reason wire.RefreshDisabledReason) { r := reason; scheduled.DisabledReason = &r }
		switch {
		case s.config.Offline:
			disable(wire.RefreshOffline)
		case s.config.ReadOnly || s.config.Run == nil:
			disable(wire.RefreshReadOnly)
		default:
			plan, err := quota.PlanScopeRefresh(paths, scope, now)
			switch {
			case err != nil || !plan.BudgetKnown:
				scheduled.At = now.Add(5 * time.Minute).UTC()
				disable(wire.RefreshCooldown)
			case plan.PolicyPending || !plan.Admitted || !allowed[scope]:
				disable(wire.RefreshReadOnly)
			case plan.At.After(now):
				scheduled.At = plan.At
				disable(wire.RefreshCooldown)
			default:
				definition, _ := consent.Definition(scope)
				key := definition.Tool
				if definition.Class == consent.Local {
					key = scope
				}
				s.mu.Lock()
				until, busy := s.pending[key]
				if busy && s.credentialWait[key] && !until.After(now) {
					delete(s.pending, key)
					delete(s.credentialWait, key)
					busy = false
				}

				if busy {
					if !until.After(now) {
						until = now.Add(5 * time.Minute)
					}
					scheduled.At = until.UTC()
					disable(wire.RefreshCooldown)
				} else {
					s.pending[key] = now.Add(5 * time.Minute)
					select {
					case s.jobs <- refreshJob{scope: scope, key: key, stamp: stamp}:
					default:
						delete(s.pending, key)
						scheduled.At = now.Add(5 * time.Minute).UTC()
						disable(wire.RefreshCooldown)
					}
				}
				s.mu.Unlock()
			}
		}
		result = append(result, scheduled)
	}
	return result, stamp, nil
}
func stampOfFence(f consent.Fence) Stamp { return Stamp{Epoch: f.StoreEpoch, Generation: f.Generation} }
func (s *RefreshScheduler) paths(admission consent.Admission) quota.Paths {
	p := s.config.Paths(admission)
	if p.ReaderAccess != nil {
		grants := map[string]quota.ReaderGrant{}
		for provider, g := range p.ReaderAccess.Grants {
			if provider == "claude" {
				g.Credential = func(context.Context) ([]byte, string) { return nil, "confirmation-needed" }
			}
			grants[provider] = g
		}
		p.ReaderAccess = &quota.ReaderAccess{Grants: grants}
	}
	return p
}
func (s *RefreshScheduler) work() {
	defer close(s.done)
	for {
		select {
		case <-s.ctx.Done():
			return
		case job := <-s.jobs:
			s.run(job)
		}
	}
}
func (s *RefreshScheduler) run(job refreshJob) {
	keepPending := false
	defer func() {
		if !keepPending {
			s.mu.Lock()
			delete(s.pending, job.key)
			delete(s.credentialWait, job.key)
			s.mu.Unlock()
		}
		if s.ctx.Err() == nil && s.config.Changed != nil {
			s.config.Changed()
		}
	}()
	if s.ctx.Err() != nil {
		return
	}
	admission := consent.Capture()
	if stampOfFence(admission.Fence()) != job.stamp {
		return
	}
	paths := s.paths(admission)
	plan, err := quota.PlanScopeRefresh(paths, job.scope, time.Now())
	if err != nil || !plan.Admitted || !plan.BudgetKnown || plan.PolicyPending || plan.At.After(time.Now()) {
		return
	}
	if s.needsCredential(paths, job.scope) {
		if s.config.CredentialRequest != nil {
			s.mu.Lock()
			s.credentialWait[job.key] = true
			s.pending[job.key] = time.Now().Add(wire.RequestTimeout)
			s.mu.Unlock()
			_, err := s.config.CredentialRequest(CredentialNeed{Provider: "claude", Scope: job.scope})
			keepPending = err == nil
		}
		return
	}
	ctx, cancel := context.WithTimeout(s.ctx, 30*time.Second)
	defer cancel()
	_ = s.config.Run(ctx, paths, job.scope, time.Now())
}
func (s *RefreshScheduler) needsCredential(paths quota.Paths, scope string) bool {
	if scope != consent.ScopeClaudeAccountUsageSavedLogin || os.Getenv("CLAUDE_CONFIG_DIR") != "" {
		return false
	}
	grant, ok := paths.ReaderAccessGrant("claude")
	if !ok || !grant.Keychain || len(grant.Profiles) != 1 {
		return false
	}
	home, _ := os.UserHomeDir()
	if grant.Profiles[0].Root != filepath.Join(home, ".claude") {
		return false
	}
	_, err := os.Stat(filepath.Join(grant.Profiles[0].Root, ".credentials.json"))
	return os.IsNotExist(err)
}

// AcceptCredential is the backend receiver's U3b callback. It holds no token
// after this call and never writes a credential. The real reader owns all
// request destinations and the shared provider budget/fence.
func (s *RefreshScheduler) AcceptCredential(ctx context.Context, stamp Stamp, need CredentialNeed, result wire.CredentialResult) error {
	defer func() {
		s.mu.Lock()
		delete(s.pending, need.Provider)
		delete(s.credentialWait, need.Provider)
		s.mu.Unlock()
		if s.ctx.Err() == nil && s.config.Changed != nil {
			s.config.Changed()
		}
	}()
	if !validCredential(result) || need.Provider != "claude" || need.Scope != consent.ScopeClaudeAccountUsageSavedLogin || s.config.Run == nil {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	admission := consent.Capture()
	if stampOfFence(admission.Fence()) != stamp || !admission.State().AllowsScope(need.Scope, admission.Mode()) || admission.KeychainStatus("claude") != "allowed" {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	if s.config.Offline || s.config.ReadOnly {
		return nil
	}
	paths := s.paths(admission)
	plan, err := quota.PlanScopeRefresh(paths, need.Scope, time.Now())
	if err != nil || !plan.Admitted || !plan.BudgetKnown || plan.PolicyPending || plan.At.After(time.Now()) {
		return nil
	}
	grant, ok := paths.ReaderAccessGrant("claude")
	if !ok {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	var payload []byte
	status := ""
	if result.Outcome == wire.OutcomeOK {
		expires := time.Now().Add(30 * time.Second)
		if result.ExpiresAt != nil {
			expires = *result.ExpiresAt
		}
		payload, err = json.Marshal(map[string]any{"claudeAiOauth": map[string]any{"accessToken": *result.AccessToken, "expiresAt": expires.UnixMilli(), "scopes": []string{"user:profile"}}})
		if err != nil {
			return errors.New("credential_unavailable")
		}
	} else {
		switch result.Outcome {
		case wire.OutcomeCanceled:
			status = "canceled"
		case wire.OutcomeDenied:
			status = "denied"
		case wire.OutcomeNotFound:
			status = "not-found"
		case wire.OutcomeInteractionRequired:
			status = "confirmation-needed"
		default:
			status = "unavailable"
		}
	}
	grant.Credential = func(context.Context) ([]byte, string) { return payload, status }
	paths.ReaderAccess.Grants["claude"] = grant
	err = s.config.Run(ctx, paths, need.Scope, time.Now())
	payload = nil
	result.AccessToken = nil
	return err
}

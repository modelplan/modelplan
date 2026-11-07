// SPDX-License-Identifier: MIT
package appserver

import (
	"bytes"
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
	// Observe records what the local logs show: sessions, speed and quota history. The app has
	// no other trigger for this; the CLI's own commands do it themselves.
	Observe func(quota.Paths, time.Time)
	Now     func() time.Time
	Plan    func(quota.Paths, string, time.Time) (quota.ScopeRefreshPlan, error)
}
type refreshJob struct {
	at         time.Time
	scope, key string
	stamp      Stamp
	member     *wire.RefreshMember
}
type RefreshScheduler struct {
	credentialWait map[string]bool
	config         RefreshConfig
	ctx            context.Context
	cancel         context.CancelFunc
	done           chan struct{}
	scheduled      map[string]refreshJob
	wake           chan struct{}
	mu             sync.Mutex
	pending        map[string]time.Time
	autoOnce       sync.Once
	autoDone       chan struct{}
	autoWake       chan struct{}
	autoNext       map[string]time.Time
	autoReason     map[string]wire.MemberRefreshReason
	autoStarted    bool
	decisions      refreshDecisionRing
}

func (s *RefreshScheduler) now() time.Time {
	if s.config.Now != nil {
		return s.config.Now()
	}
	return time.Now()
}
func (s *RefreshScheduler) plan(paths quota.Paths, scope string, now time.Time) (quota.ScopeRefreshPlan, error) {
	if s.config.Plan != nil {
		return s.config.Plan(paths, scope, now)
	}
	return quota.PlanScopeRefresh(paths, scope, now)
}

// readerBusyRetry: another process, such as a plugin hook, held the reader lock past the
// two-second wait. The failure back-off is for reads that ran.
const readerBusyRetry = 15 * time.Second

// observeEvery matches the live session window closely enough for a current rate.
const observeEvery = 30 * time.Second

func NewRefreshScheduler(ctx context.Context, config RefreshConfig) *RefreshScheduler {
	ctx, cancel := context.WithCancel(ctx)
	s := &RefreshScheduler{config: config, ctx: ctx, cancel: cancel, done: make(chan struct{}), scheduled: map[string]refreshJob{}, wake: make(chan struct{}, 1), pending: map[string]time.Time{}, credentialWait: map[string]bool{}, autoDone: make(chan struct{}), autoWake: make(chan struct{}, 1), autoNext: map[string]time.Time{}, autoReason: map[string]wire.MemberRefreshReason{}}
	go s.work()
	return s
}
func (s *RefreshScheduler) Close() {
	s.cancel()
	<-s.done
	s.mu.Lock()
	started := s.autoStarted
	s.mu.Unlock()
	if started {
		<-s.autoDone
	}
	s.decisions.clear()
}

// PendingDeadline reports the scheduler's in-memory lower bound. A pending
// operation without a future bound is unknown and must not be presented as due.
func (s *RefreshScheduler) PendingDeadline(scope string) (time.Time, bool, bool) {
	definition, ok := consent.Definition(scope)
	if !ok {
		return time.Time{}, false, false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	now := s.now()
	if until, pending := s.pending[definition.Tool]; pending {
		if !until.After(now) {
			return time.Time{}, true, false
		}
		return until.UTC(), true, true
	}
	if until := s.autoNext[definition.Tool]; until.After(now) {
		return until.UTC(), true, true
	}
	return time.Time{}, false, false
}

// Decisions exposes only the bounded code-only history for this process.
func (s *RefreshScheduler) Decisions() []wire.RefreshDecision {
	items := s.decisions.snapshot(s.now())
	out := make([]wire.RefreshDecision, 0, len(items))
	for _, item := range items {
		out = append(out, wire.RefreshDecision{AgoSeconds: item.AgoSeconds, Scope: wire.RefreshDecisionScope(item.Scope), Outcome: wire.RefreshDecisionOutcome(item.Outcome), Reason: wire.RefreshDecisionReason(item.Reason)})
	}
	return out
}
func (s *RefreshScheduler) Handler() Handler {
	return Handler{Capability: "refresh", ExtraCapabilities: []string{CapabilityMemberRefresh}, Handle: func(ctx context.Context, raw json.RawMessage, _ Stamp) (Reply, error) {
		p, err := params[wire.RefreshRequestParams](raw)
		if err != nil {
			return Reply{}, ProtocolError{wire.CodeInvalidParams}
		}
		var fields map[string]json.RawMessage
		if len(raw) > 0 {
			if err := json.Unmarshal(raw, &fields); err != nil {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
		}
		if member, present := fields["member"]; present && bytes.Equal(bytes.TrimSpace(member), []byte("null")) {
			return Reply{}, ProtocolError{wire.CodeInvalidParams}
		}
		if p.Member != nil {
			_, hasScopes := fields["scopes"]
			if !MemberRefreshEnabled(ctx) || hasScopes {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			result, stamp, err := s.RequestMember(ctx, *p.Member)
			return Reply{Stamp: stamp, Data: result, Receipt: true}, err
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
	now := s.now()
	result := []wire.RefreshScheduled{}
	enqueued := false
	for _, scope := range scopes {
		scheduled := wire.RefreshScheduled{Scope: scope, At: now.UTC()}
		disable := func(reason wire.RefreshDisabledReason) { r := reason; scheduled.DisabledReason = &r }
		switch {
		case s.config.Offline:
			disable(wire.RefreshOffline)
		case s.config.ReadOnly || s.config.Run == nil:
			disable(wire.RefreshReadOnly)
		default:
			plan, err := s.plan(paths, scope, now)
			switch {
			case err != nil || !plan.BudgetKnown:
				scheduled.At = now.Add(5 * time.Minute).UTC()
				disable(wire.RefreshCooldown)
			case plan.PolicyPending || !plan.Admitted || !allowed[scope]:
				disable(wire.RefreshReadOnly)
			default:
				if plan.At.After(now) {
					scheduled.At = plan.At
					disable(wire.RefreshCooldown)
				}
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
				} else if len(s.pending) >= len(consent.Definitions()) || len(s.scheduled) >= len(consent.Definitions()) {
					scheduled.At = now.Add(5 * time.Minute).UTC()
					disable(wire.RefreshCooldown)
				} else {
					s.pending[key] = plan.At
					if !plan.At.After(now) {
						s.pending[key] = now.Add(5 * time.Minute)
					}
					s.scheduled[key] = refreshJob{scope: scope, key: key, stamp: stamp, at: plan.At}
					enqueued = true
					s.signal()
				}
				s.mu.Unlock()
			}
		}
		result = append(result, scheduled)
	}
	if enqueued && s.config.Changed != nil {
		s.config.Changed()
	}
	return result, stamp, nil
}
func stampOfFence(f consent.Fence) Stamp { return Stamp{Epoch: f.StoreEpoch, Generation: f.Generation} }
func (s *RefreshScheduler) paths(admission consent.Admission) quota.Paths {
	return s.safePaths(s.config.Paths(admission))
}
func (s *RefreshScheduler) safePaths(p quota.Paths) quota.Paths {
	if p.ReaderAccess != nil {
		grants := map[string]quota.ReaderGrant{}
		for provider, g := range p.ReaderAccess.Grants {
			if provider == "claude" && g.Credential == nil {
				g.Credential = func(context.Context) ([]byte, string) { return nil, "confirmation-needed" }
			}
			grants[provider] = g
		}
		p.ReaderAccess = &quota.ReaderAccess{Grants: grants}
	}
	return p
}
func (s *RefreshScheduler) signal() {
	select {
	case s.wake <- struct{}{}:
	default:
	}
}
func (s *RefreshScheduler) work() {
	defer close(s.done)
	for {
		if s.ctx.Err() != nil {
			return
		}
		s.mu.Lock()
		var next refreshJob
		found := false
		for _, job := range s.scheduled {
			if !found || job.at.Before(next.at) || job.at.Equal(next.at) && job.key < next.key {
				next = job
				found = true
			}
		}
		if found && !s.now().Before(next.at) {
			delete(s.scheduled, next.key)
			s.mu.Unlock()
			s.run(next)
			continue
		}
		s.mu.Unlock()
		if !found {
			select {
			case <-s.ctx.Done():
				return
			case <-s.wake:
			}
			continue
		}
		timer := time.NewTimer(next.at.Sub(s.now()))
		select {
		case <-s.ctx.Done():
			timer.Stop()
			return
		case <-s.wake:
			timer.Stop()
		case <-timer.C:
		}
	}
}
func (s *RefreshScheduler) run(job refreshJob) {
	keepPending := false
	attempted := false
	defer func() {
		if !keepPending {
			currentFence := stampOfFence(consent.Capture().Fence()) == job.stamp
			if !attempted {
				s.decisions.add(s.now(), job.scope, refreshNotAttempted, refreshUnavailable)
			}
			s.mu.Lock()
			// The worker is serial: a queued job for this key is a newer
			// replacement, admitted after a credential wait expired. Its
			// pending guard belongs to it, not to the completing job.
			if _, replaced := s.scheduled[job.key]; !replaced {
				if !attempted && currentFence {
					s.autoNext[job.key] = s.now().Add(10 * time.Minute)
					s.autoReason[job.key] = wire.MemberRefreshBudget
				}
				delete(s.pending, job.key)
				delete(s.credentialWait, job.key)
			}
			s.mu.Unlock()
		}
		if s.ctx.Err() == nil && s.config.Changed != nil {
			s.config.Changed()
		}
		select {
		case s.autoWake <- struct{}{}:
		default:
		}
	}()
	if s.ctx.Err() != nil {
		return
	}
	admission := consent.Capture()
	if stampOfFence(admission.Fence()) != job.stamp {
		return
	}
	rawPaths := s.config.Paths(admission)
	original, _ := rawPaths.ReaderAccessGrant("claude")
	credentialBound := original.Credential != nil
	paths := s.safePaths(rawPaths)
	if job.member != nil {
		definition, ok := consent.Definition(job.scope)
		if !ok {
			return
		}
		view, err := s.config.Backend.Get(s.ctx)
		if err != nil || view.Stamp != job.stamp {
			return
		}
		matches, routeMembers := matchingMemberCount(view, *job.member)
		if matches != 1 || (!quota.MemberProfilesAreScoped(definition.Tool) && routeMembers != 1) || liveMemberScope(job.member.RowID, job.member.Route, admission.State(), admission.Mode(), view.Scopes) != job.scope {
			return
		}
		paths, ok = quota.NarrowMemberPaths(paths, definition.Tool, job.member.AccountLocator, job.member.SubscriptionRef)
		if !ok {
			return
		}
	}
	plan, err := s.plan(paths, job.scope, s.now())
	if err != nil || !plan.Admitted || !plan.BudgetKnown || plan.PolicyPending {
		return
	}
	if plan.At.After(s.now()) {
		job.at = plan.At
		s.mu.Lock()
		s.pending[job.key] = plan.At
		s.scheduled[job.key] = job
		s.signal()
		s.mu.Unlock()
		keepPending = true
		return
	}
	if !credentialBound && s.needsCredential(paths, job.scope) {
		if s.config.CredentialRequest != nil {
			s.mu.Lock()
			s.credentialWait[job.key] = true
			s.pending[job.key] = s.now().Add(wire.RequestTimeout)
			s.mu.Unlock()
			_, err := s.config.CredentialRequest(CredentialNeed{Provider: "claude", Scope: job.scope})
			keepPending = err == nil
		}
		return
	}
	ctx, cancel := context.WithTimeout(s.ctx, 30*time.Second)
	defer cancel()
	started := s.now()
	attempted = true
	err = s.config.Run(ctx, paths, job.scope, started)
	outcome, reason := refreshNotAttempted, refreshUnavailable
	// Lost to another reader before reading anything: nothing failed, so try again soon.
	busy := errors.Is(err, consent.ErrReaderBusy) || errors.Is(err, consent.ErrBusy)
	if busy {
		outcome, reason = refreshDeferred, refreshBudget
	} else if err != nil {
		outcome = refreshFailed
	} else if job.scope == consent.ScopeCodexLocalHistory {
		outcome, reason = refreshSucceeded, refreshCompleted
	} else {
		switch quota.ScopeRefreshOutcome(paths, job.scope, started) {
		case "succeeded":
			outcome, reason = refreshSucceeded, refreshCompleted
		case "failed":
			outcome = refreshFailed
		}
	}
	s.decisions.add(started, job.scope, outcome, reason)
	wait := 5 * time.Minute
	if err != nil {
		wait = 10 * time.Minute
		if job.scope == consent.ScopeCodexRuntimeUsage {
			wait = 30 * time.Minute
		}
	}
	if busy {
		wait = readerBusyRetry
	}
	if stampOfFence(consent.Capture().Fence()) == job.stamp {
		s.mu.Lock()
		s.autoNext[job.key] = started.Add(wait)
		s.autoReason[job.key] = wire.MemberRefreshFloor
		if err != nil || outcome == refreshFailed {
			s.autoReason[job.key] = wire.MemberRefreshBackoff
		}
		s.mu.Unlock()
	}
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
		if s.credentialWait[need.Provider] {
			delete(s.pending, need.Provider)
			delete(s.credentialWait, need.Provider)
		}
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
	plan, err := s.plan(paths, need.Scope, s.now())
	if err != nil || !plan.Admitted || !plan.BudgetKnown || plan.PolicyPending || plan.At.After(s.now()) {
		return nil
	}
	grant, ok := paths.ReaderAccessGrant("claude")
	if !ok {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	var payload []byte
	status := ""
	if result.Outcome == wire.OutcomeOK {
		expires := s.now().Add(30 * time.Second)
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
	err = s.config.Run(ctx, paths, need.Scope, s.now())
	payload = nil
	result.AccessToken = nil
	return err
}

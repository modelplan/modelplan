// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
)

// credentialQuiet keeps automatic reads off a provider just after an explicit read.
const credentialQuiet = 15 * time.Second

type credentialReply struct {
	result wire.CredentialResult
	err    error
}

type credentialOperation struct {
	session string
	reply   chan credentialReply
	stamp   Stamp
	need    CredentialNeed
	expires time.Time
	timer   *time.Timer
}

func validCredential(p wire.CredentialResult) bool {
	if p.OperationID == "" {
		return false
	}
	switch p.Outcome {
	case wire.OutcomeOK:
		return p.AccessToken != nil && len(*p.AccessToken) > 0 && len(*p.AccessToken) <= 64<<10 && (p.ExpiresAt == nil || p.ExpiresAt.After(time.Now()))
	case wire.OutcomeCanceled, wire.OutcomeDenied, wire.OutcomeNotFound, wire.OutcomeInteractionRequired, wire.OutcomeTimeout, wire.OutcomeError:
		return p.AccessToken == nil && p.ExpiresAt == nil
	default:
		return false
	}
}

// credentialParams enforces presence as well as decoded values. A non-success
// result cannot carry token/expiry keys, including explicit null, matching the
// wire schema and generated Swift decoder. Never format the raw payload.
func credentialParams(raw json.RawMessage) (wire.CredentialResult, error) {
	p, err := params[wire.CredentialResult](raw)
	if err != nil || !validCredential(p) {
		return wire.CredentialResult{}, ProtocolError{wire.CodeCredentialRejected}
	}
	if p.Outcome != wire.OutcomeOK {
		var fields map[string]json.RawMessage
		if json.Unmarshal(raw, &fields) != nil {
			return wire.CredentialResult{}, ProtocolError{wire.CodeCredentialRejected}
		}
		_, token := fields["accessToken"]
		_, expiry := fields["expiresAt"]
		if token || expiry {
			return wire.CredentialResult{}, ProtocolError{wire.CodeCredentialRejected}
		}
	}
	return p, nil
}

// RequestCredential starts a background operation only. Interactive operations
// are admitted solely inside the explicit consent/grant Keychain action.
func (s *Server) RequestCredential(need CredentialNeed) (string, error) {
	if need.Interactive {
		return "", ProtocolError{wire.CodeCredentialRejected}
	}
	return s.requestCredential(need, false)
}
func (s *Server) requestCredential(need CredentialNeed, explicit bool) (string, error) {
	return s.openCredential(s.ctx, need, explicit, nil)
}

// ReadCredential is the waitable background capability used by a budgeted
// reader. Interactive operations originate only in the committed grant flow.
func (s *Server) ReadCredential(ctx context.Context, need CredentialNeed) (wire.CredentialResult, error) {
	if err := ctx.Err(); err != nil {
		return wire.CredentialResult{}, err
	}
	if need.Interactive {
		return wire.CredentialResult{}, ProtocolError{wire.CodeCredentialRejected}
	}
	reply := make(chan credentialReply, 1)
	id, err := s.openCredential(ctx, need, false, reply)
	if err != nil {
		return wire.CredentialResult{}, err
	}
	defer func() {
		s.mu.Lock()
		defer s.mu.Unlock()
		if op, ok := s.credentials[id]; ok {
			op.timer.Stop()
			delete(s.credentials, id)
		}
	}()
	select {
	case out := <-reply:
		return out.result, out.err
	case <-ctx.Done():
		return wire.CredentialResult{}, ctx.Err()
	case <-s.ctx.Done():
		return wire.CredentialResult{}, context.Canceled
	}
}
func (s *Server) openCredential(parent context.Context, need CredentialNeed, explicit bool, reply chan credentialReply) (string, error) {
	if need.Provider != "claude" || need.Interactive && !explicit {
		return "", ProtocolError{wire.CodeCredentialRejected}
	}
	if _, ok := s.backend.(CredentialReceiver); !ok {
		return "", ProtocolError{wire.CodeCredentialRejected}
	}
	if s.ctx == nil {
		return "", ProtocolError{wire.CodeNotInitialized}
	}
	ctx, cancel := context.WithTimeout(parent, s.config.RequestTimeout)
	defer cancel()
	if err := s.refresh(ctx); err != nil {
		return "", err
	}
	s.mu.Lock()
	if !s.initialized || s.stopping {
		s.mu.Unlock()
		return "", ProtocolError{wire.CodeNotInitialized}
	}
	if !s.clientCapabilities["credentials"] {
		s.mu.Unlock()
		return "", ProtocolError{wire.CodeCredentialRejected}
	}
	allowed := false
	for _, scope := range s.view.Consent.Scopes {
		if scope.Scope == need.Scope && scope.Tool == need.Provider && scope.State == wire.ConsentAllowed && scope.Keychain != nil && *scope.Keychain == wire.KeychainAllow && !scope.CleanupPending && scope.Disabled == nil {
			allowed = true
			break
		}
	}
	if !allowed {
		s.mu.Unlock()
		return "", ProtocolError{wire.CodeCredentialRejected}
	}
	// The grant's own operation goes ahead of its hold and of an earlier read, which the reader
	// lock orders; only an operation still waiting for its result stands in the way.
	busy := s.credentialActiveLocked(need.Provider)
	if explicit {
		busy = s.credentialOpenLocked(need.Provider)
	}
	if busy {
		s.mu.Unlock()
		return "", ProtocolError{wire.CodeBusy}
	}
	var random [16]byte
	if _, err := rand.Read(random[:]); err != nil {
		s.mu.Unlock()
		return "", ProtocolError{wire.CodeInternal}
	}
	id := "op-" + hex.EncodeToString(random[:])
	stamp, session := s.view.Stamp, s.session
	op := &credentialOperation{session: session, reply: reply, stamp: stamp, need: need, expires: time.Now().Add(s.config.RequestTimeout)}
	op.timer = time.AfterFunc(s.config.RequestTimeout, func() {
		s.mu.Lock()
		delete(s.credentials, id)
		s.mu.Unlock()
		op.reject()
	})
	s.credentials[id] = op
	s.mu.Unlock()
	if !s.out.controlMessage(notification(session, "credentials/request", stamp, nil, wire.CredentialRequest{OperationID: id, Provider: need.Provider, Scope: need.Scope, Interactive: need.Interactive})) {
		op.timer.Stop()
		s.mu.Lock()
		delete(s.credentials, id)
		s.mu.Unlock()
		return "", ProtocolError{wire.CodeInternal}
	}
	return id, nil
}

// holdCredentialForGrant keeps the provider for a Keychain Allow from before the consent commit:
// from then on a background reader is admitted, and if it opened the one operation the user's
// prompt would be dropped. The returned function ends the hold.
func (s *Server) holdCredentialForGrant(p wire.ConsentGrantParams) func() {
	providers := []string{}
	for scope, choice := range p.Keychain {
		if definition, ok := consent.Definition(scope); ok && choice == wire.KeychainAllow {
			providers = append(providers, definition.Tool)
		}
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.credentialGrants == nil {
		s.credentialGrants = map[string]int{}
	}
	for _, provider := range providers {
		s.credentialGrants[provider]++
	}
	return func() {
		s.mu.Lock()
		defer s.mu.Unlock()
		for _, provider := range providers {
			s.credentialGrants[provider]--
		}
	}
}

// CredentialHold reports an operation for the provider that is waiting for its result, or an
// explicit one whose read is still running, and when the quiet time after an explicit read ends.
// One user action is one credential read, whatever its outcome.
func (s *Server) CredentialHold(provider string) (bool, time.Time) {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.credentialActiveLocked(provider), s.credentialReadEnded[provider].Add(credentialQuiet)
}
func (s *Server) credentialActiveLocked(provider string) bool {
	return s.credentialGrants[provider] > 0 || s.credentialReads[provider] > 0 || s.credentialOpenLocked(provider)
}
func (s *Server) credentialOpenLocked(provider string) bool {
	for _, op := range s.credentials {
		if op.need.Provider == provider {
			return true
		}
	}
	return false
}

func (s *Server) acceptCredential(ctx context.Context, p wire.CredentialResult) error {
	// Refresh before matching: an external CLI revoke need not have reached the
	// watcher yet. The receiver repeats the atomic U2 admission/fence before use.
	if err := s.refresh(ctx); err != nil {
		return err
	}
	s.mu.Lock()
	op, ok := s.credentials[p.OperationID]
	if ok {
		delete(s.credentials, p.OperationID)
		op.timer.Stop()
		if op.reply == nil {
			// The operation is spent, but its read has only begun.
			if s.credentialReads == nil {
				s.credentialReads = map[string]int{}
			}
			s.credentialReads[op.need.Provider]++
			defer func() {
				s.mu.Lock()
				defer s.mu.Unlock()
				s.credentialReads[op.need.Provider]--
				if s.credentialReadEnded == nil {
					s.credentialReadEnded = map[string]time.Time{}
				}
				s.credentialReadEnded[op.need.Provider] = time.Now()
			}()
		}
	}
	valid := ok && op.session == s.session && op.stamp == s.view.Stamp && time.Now().Before(op.expires)
	s.mu.Unlock()
	if !valid {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	if op.reply != nil {
		select {
		case op.reply <- credentialReply{result: p}:
			return nil
		default:
			return ProtocolError{wire.CodeCredentialRejected}
		}
	}
	receiver, ok := s.backend.(CredentialReceiver)
	if !ok {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	return receiver.AcceptCredential(ctx, op.stamp, op.need, p)
}

// reject wakes a background reader without retaining a credential or error text.
func (op *credentialOperation) reject() {
	if op.reply != nil {
		select {
		case op.reply <- credentialReply{err: ProtocolError{wire.CodeCredentialRejected}}:
		default:
		}
	}
}

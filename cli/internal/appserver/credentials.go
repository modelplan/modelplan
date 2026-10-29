// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

type credentialOperation struct {
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

// RequestCredential starts a background operation only. Interactive operations
// are admitted solely inside the explicit consent/grant Keychain action.
func (s *Server) RequestCredential(need CredentialNeed) (string, error) {
	if need.Interactive {
		return "", ProtocolError{wire.CodeCredentialRejected}
	}
	return s.requestCredential(need, false)
}
func (s *Server) requestCredential(need CredentialNeed, explicit bool) (string, error) {
	if need.Provider != "claude" || need.Interactive && !explicit {
		return "", ProtocolError{wire.CodeCredentialRejected}
	}
	if _, ok := s.backend.(CredentialReceiver); !ok {
		return "", ProtocolError{wire.CodeCredentialRejected}
	}
	if s.ctx == nil {
		return "", ProtocolError{wire.CodeNotInitialized}
	}
	ctx, cancel := context.WithTimeout(s.ctx, s.config.RequestTimeout)
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
	for _, op := range s.credentials {
		if op.need.Provider == need.Provider {
			s.mu.Unlock()
			return "", ProtocolError{wire.CodeBusy}
		}
	}
	var random [16]byte
	if _, err := rand.Read(random[:]); err != nil {
		s.mu.Unlock()
		return "", ProtocolError{wire.CodeInternal}
	}
	id := "op-" + hex.EncodeToString(random[:])
	stamp, session := s.view.Stamp, s.session
	op := &credentialOperation{stamp: stamp, need: need, expires: time.Now().Add(s.config.RequestTimeout)}
	op.timer = time.AfterFunc(s.config.RequestTimeout, func() { s.mu.Lock(); delete(s.credentials, id); s.mu.Unlock() })
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
	}
	valid := ok && op.stamp == s.view.Stamp && time.Now().Before(op.expires)
	s.mu.Unlock()
	if !valid {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	receiver, ok := s.backend.(CredentialReceiver)
	if !ok {
		return ProtocolError{wire.CodeCredentialRejected}
	}
	return receiver.AcceptCredential(ctx, op.stamp, op.need, p)
}

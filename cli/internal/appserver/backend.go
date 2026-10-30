// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"errors"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// Stamp is the indivisible consent context. Generation is ordered only within
// Epoch. Backends capture it under the shared store's lock, never synthesize it.
type Stamp struct {
	Epoch      string
	Generation uint64
}

// View is immutable after return. The backend owns admission, reader locks,
// publication fencing and shared budgets; the server never rebuilds permission.
type View struct {
	Stamp       Stamp
	Projection  rows.Projection
	Scopes      []string
	Consent     wire.ConsentFacts
	Diagnostics []wire.ScopeDiag
	Health      wire.Health
}

type GrantResult struct {
	Stamp   Stamp
	Receipt wire.ConsentReceipt
	// Interactive needs originate only in the explicit Keychain grant action.
	Credentials []CredentialNeed
}

type CredentialNeed struct {
	Provider    string
	Scope       string
	Interactive bool
}

// Backend is U3's seam to the shared U2 consent/read-state implementation. Get
// must return a generation-fenced snapshot; Grant commits and stores receipts
// before returning, and replays by (epoch,requestId). Committed operations must
// return their receipt even when cancellation/cleanup follows the commit.
// Changes is level-triggered: coalescing is allowed because Get rereads current
// state. All methods must honor ctx and must not log raw errors or credentials.
type Backend interface {
	Get(context.Context) (View, error)
	Publish(context.Context, Stamp, func() error) error
	Grant(context.Context, wire.ConsentGrantParams) (GrantResult, error)
	Changes(context.Context) <-chan struct{}
}

// CredentialReceiver performs the U2 admission/fence and budget check again
// before using a credential. The token stays in memory and is never persisted.
type CredentialReceiver interface {
	AcceptCredential(context.Context, Stamp, CredentialNeed, wire.CredentialResult) error
}

// Capabilities lets a backend advertise only what its production wiring proves.
type Capabilities interface{ Capabilities() []string }

type ProtocolError struct{ Code int }

func (e ProtocolError) Error() string { return wire.ErrorName(e.Code) }
func errorCode(err error) int {
	var protocol ProtocolError
	if errors.As(err, &protocol) {
		switch protocol.Code {
		case wire.CodeInvalidParams, wire.CodeConsentStale, wire.CodeConsentRejected, wire.CodeRequestMismatch, wire.CodeConsentChanged, wire.CodeCredentialRejected, wire.CodeHistoryUnavailable, wire.CodeCursorStale, wire.CodeBusy:
			return protocol.Code
		}
	}
	if errors.Is(err, context.Canceled) || errors.Is(err, context.DeadlineExceeded) {
		return wire.CodeCanceled
	}
	return wire.CodeInternal
}

// UnavailableBackend is the inert fallback when the shared store cannot be
// opened. It reads/writes no home, reports degraded health, advertises no consent
// or credential capability, and never substitutes a second consent store.
type UnavailableBackend struct{}

func (UnavailableBackend) Get(context.Context) (View, error) {
	return View{Stamp: Stamp{Epoch: "unavailable"}, Projection: rows.Build(rows.Input{Now: time.Now(), ReadersOff: true}), Consent: wire.ConsentFacts{Scopes: []wire.ConsentScope{}}, Diagnostics: []wire.ScopeDiag{}, Health: wire.Health{State: wire.HealthDegraded, Code: "consent_unavailable"}}, nil
}
func (UnavailableBackend) Grant(context.Context, wire.ConsentGrantParams) (GrantResult, error) {
	return GrantResult{}, ProtocolError{wire.CodeInternal}
}
func (UnavailableBackend) Changes(context.Context) <-chan struct{} { return nil }
func (UnavailableBackend) Capabilities() []string                  { return []string{"rows", "diagnostics"} }

func (UnavailableBackend) Publish(ctx context.Context, stamp Stamp, write func() error) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	if stamp != (Stamp{Epoch: "unavailable"}) {
		return ProtocolError{wire.CodeConsentChanged}
	}
	return write()
}

// responseContextError preserves the authoritative context of a rejected
// mutation independently of the asynchronous rows/consent watcher.
type responseContextError struct {
	err   error
	stamp Stamp
}

func (e responseContextError) Error() string { return e.err.Error() }
func (e responseContextError) Unwrap() error { return e.err }

type sessionContextKey struct{}

// SessionID returns the initialized pipe session bound by the core to a handler.
// Query cursors use it without exposing mutable Server state.
func SessionID(ctx context.Context) string {
	session, _ := ctx.Value(sessionContextKey{}).(string)
	return session
}

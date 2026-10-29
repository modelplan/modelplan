// SPDX-License-Identifier: MIT
package readers

import (
	"errors"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"net/http"
	"sync"
)

var (
	ErrRequestNotAllowed    = errors.New("reader_request_not_allowed")
	ErrReadExhausted        = errors.New("reader_request_set_exhausted")
	ErrAuthorizationStopped = errors.New("reader_authorization_stopped")
)

// ReadTransport enforces the first-batch fixed request set for one admitted read.
// It records no credentials. The caller reserves the cross-process vendor budget
// before creating it, and must not create another transport to retry a rejection.
// A local-history scope can pass admission but can never send an HTTP request.
// Concurrent calls are serialized so none can slip past a 401 or 403 response.
// Credentialed redirects are stopped even when the caller uses a default Client.
// POST request pins are compiled here, but admission keeps them policy_pending.
//
// Create a fresh transport for the card's bounded request set, never per request.
type ReadTransport struct {
	mu       sync.Mutex
	scope    string
	next     http.RoundTripper
	host     string
	attempts int
	stage    int
	stopped  error
}

func NewReadTransport(scope string, next http.RoundTripper) *ReadTransport {
	if next == nil {
		next = http.DefaultTransport
	}
	return &ReadTransport{scope: scope, next: next, stage: -1}
}

func (t *ReadTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	forwarded := false
	defer func() {
		if !forwarded && req.Body != nil {
			req.Body.Close()
		}
	}()
	if err := CheckAdmission(t.scope); err != nil {
		return nil, err
	}
	if t.stopped != nil {
		return nil, t.stopped
	}
	pin, allowed := requestSet(t.scope, req)
	if !allowed || req.URL.Scheme != "https" || req.URL.User != nil || req.URL.ForceQuery ||
		req.URL.Fragment != "" || req.URL.RawFragment != "" || req.URL.Opaque != "" ||
		(req.Host != "" && req.Host != req.URL.Host) || len(req.Trailer) != 0 ||
		!pin.validHeaders(req) || !pin.validBody(req) {
		return nil, ErrRequestNotAllowed
	}
	if !pin.crossHost && t.host != "" && t.host != req.URL.Host {
		return nil, ErrRequestNotAllowed
	}
	if t.attempts >= pin.limit {
		return nil, ErrReadExhausted
	}
	if pin.stage <= t.stage || (t.attempts == 0 && pin.stage == 1 && t.scope == consent.ScopeMiniMaxAccountUsageAPIKey) {
		return nil, ErrRequestNotAllowed
	}
	t.stage = pin.stage
	t.host = req.URL.Host
	t.attempts++
	forwarded = true
	resp, err := t.next.RoundTrip(req)
	if resp != nil {
		switch resp.StatusCode {
		case http.StatusUnauthorized, http.StatusForbidden:
			t.stopped = ErrAuthorizationStopped
		default:
			if resp.StatusCode >= 300 && resp.StatusCode < 400 {
				t.stopped = ErrRequestNotAllowed
			}
		}
	}
	return resp, err
}

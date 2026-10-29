// SPDX-License-Identifier: MIT
package readers

import (
	"errors"
	"net/http"
	"sync"

	"github.com/modelplan/modelplan/cli/internal/consent"
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
// The only remote scope admitted here is MiniMax; POST approval is not configurable.
//
// Create a fresh transport for the card's bounded request set, never per request.
type ReadTransport struct {
	mu       sync.Mutex
	scope    string
	next     http.RoundTripper
	host     string
	attempts int
	stopped  error
}

func NewReadTransport(scope string, next http.RoundTripper) *ReadTransport {
	if next == nil {
		next = http.DefaultTransport
	}
	return &ReadTransport{scope: scope, next: next}
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
	if t.scope != consent.ScopeMiniMaxAccountUsageAPIKey || req.URL.Scheme != "https" ||
		req.URL.User != nil || req.Method != http.MethodGet || req.URL.RawQuery != "" ||
		req.URL.ForceQuery || req.URL.Fragment != "" || req.URL.Opaque != "" ||
		(req.Host != "" && req.Host != req.URL.Host) ||
		(req.URL.Host != "api.minimax.io" && req.URL.Host != "api.minimaxi.com") ||
		(req.URL.EscapedPath() != "/v1/token_plan/remains" && req.URL.EscapedPath() != "/v1/api/openplatform/coding_plan/remains") ||
		(req.Body != nil && req.Body != http.NoBody) {
		return nil, ErrRequestNotAllowed
	}
	if t.host != "" && t.host != req.URL.Host {
		return nil, ErrRequestNotAllowed
	}
	if t.attempts >= 2 {
		return nil, ErrReadExhausted
	}
	expected := "/v1/token_plan/remains"
	if t.attempts == 1 {
		expected = "/v1/api/openplatform/coding_plan/remains"
	}
	if req.URL.EscapedPath() != expected {
		return nil, ErrRequestNotAllowed
	}
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

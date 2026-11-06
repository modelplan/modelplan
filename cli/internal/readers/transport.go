// SPDX-License-Identifier: MIT
package readers

import (
	"crypto/tls"
	"errors"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"net/http"
	"sync"
)

var (
	ErrRequestNotAllowed    = errors.New("reader_request_not_allowed")
	ErrReadExhausted        = errors.New("reader_request_set_exhausted")
	ErrAuthorizationStopped = errors.New("reader_authorization_stopped")
	ErrUnsafeTransport      = errors.New("reader_transport_not_single_attempt")
)

// SingleAttemptTransport is for explicitly reviewed, in-process transports.
// Implementations must never retry or issue additional requests. The production
// client uses *http.Transport; synthetic recorders use this contract in tests.
type SingleAttemptTransport interface {
	http.RoundTripper
	ReaderSingleAttempt()
}

// ReadTransport enforces the first-batch fixed request set for one admitted read.
// It records no credentials. The caller reserves the cross-process vendor budget
// before creating it, and must not create another transport to retry a rejection.
// A local-history scope can pass admission but can never send an HTTP request.
// Concurrent calls are serialized so none can slip past a 401 or 403 response.
// Credentialed redirects are stopped even when the caller uses a default Client.
// Owner-approved POST methods and closed body schemas are compiled here.
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
	if transport, ok := next.(*http.Transport); ok {
		// A fresh HTTP/1 connection per stage prevents transparent retries on
		// reused HTTP/1 connections and HTTP/2 stream/GOAWAY retries. Clone so
		// the caller's proxy, trust roots, dialer and timeouts stay intact.
		if transport.DialTLS != nil || transport.DialTLSContext != nil {
			next = nil // a custom TLS dialer may negotiate an uncontrolled protocol
		} else {
			clone := transport.Clone()
			clone.DisableKeepAlives = true
			clone.ForceAttemptHTTP2 = false
			clone.TLSNextProto = map[string]func(string, *tls.Conn) http.RoundTripper{}
			clone.Protocols = new(http.Protocols)
			clone.Protocols.SetHTTP1(true)
			if clone.TLSClientConfig != nil {
				clone.TLSClientConfig.NextProtos = []string{"http/1.1"}
			}
			next = clone
		}
	} else if _, ok := next.(SingleAttemptTransport); !ok {
		next = nil
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
	if t.next == nil {
		return nil, ErrUnsafeTransport
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

// SPDX-License-Identifier: MIT

// Package readertest provides a synthetic transport for observable reader tests.
package readertest

import (
	"errors"
	"io"
	"net/http"
	"strings"
	"sync"
)

// Request intentionally excludes credentials, headers and request bodies.
type Request struct{ Method, Host, Path string }
type Response struct {
	StatusCode int
	Body       string
	Header     http.Header
}

// Transport records every attempted outbound request, including unexpected calls.
// It never opens a socket. An exhausted script fails instead of using the network.
type Transport struct {
	mu        sync.Mutex
	responses []Response
	requests  []Request
}

func NewTransport(responses ...Response) *Transport {
	return &Transport{responses: append([]Response(nil), responses...)}
}

func (t *Transport) RoundTrip(req *http.Request) (*http.Response, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if req.Body != nil {
		defer req.Body.Close()
	}
	t.requests = append(t.requests, Request{req.Method, req.URL.Host, req.URL.EscapedPath()})
	if len(t.responses) == 0 {
		return nil, errors.New("unexpected reader request")
	}
	r := t.responses[0]
	t.responses = t.responses[1:]
	header := r.Header.Clone()
	if header == nil {
		header = make(http.Header)
	}
	return &http.Response{StatusCode: r.StatusCode, Header: header, Body: io.NopCloser(strings.NewReader(r.Body)), Request: req}, nil
}

func (t *Transport) Requests() []Request {
	t.mu.Lock()
	defer t.mu.Unlock()
	return append([]Request(nil), t.requests...)
}

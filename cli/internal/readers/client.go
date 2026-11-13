// SPDX-License-Identifier: MIT
package readers

import "net/http"

// NewReadClient preserves the caller's timeout and proxy/TLS policy, but
// removes ambient cookies and redirect following. Standard transports are
// isolated and restricted to one HTTP/1 wire attempt per stage. Create it once
// per logical read so all requests share one guard and its stop state.
func NewReadClient(scope string, base *http.Client) *http.Client {
	if base == nil {
		base = http.DefaultClient
	}
	client := *base
	client.Transport = NewReadTransport(scope, base.Transport)
	client.Jar = nil
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	return &client
}

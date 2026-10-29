// SPDX-License-Identifier: MIT
package readers

import "net/http"

// NewReadClient preserves the caller's timeout and underlying transport, but
// removes ambient cookies and redirect following. Create it once per logical
// read: all requests in that read share one ReadTransport and its stop state.
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

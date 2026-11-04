// SPDX-License-Identifier: MIT
package readers_test

import (
	"context"
	"crypto/tls"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/readers"
)

func TestReadClientDoesNotRetryOnReusedConnection(t *testing.T) {
	var count atomic.Int32
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch count.Add(1) {
		case 2:
			conn, _, err := w.(http.Hijacker).Hijack()
			if err != nil {
				t.Errorf("hijack: %v", err)
				return
			}
			conn.Close()
		default:
			w.WriteHeader(http.StatusOK)
		}
	}))
	defer server.Close()
	transport := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, DialContext: func(ctx context.Context, network, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, network, server.Listener.Addr().String())
	}}
	defer transport.CloseIdleConnections()
	base := &http.Client{Transport: transport, Timeout: 3 * time.Second}
	endpoint := "https://api.minimax.io/v1/token_plan/remains"
	warm, err := base.Get(endpoint)
	if err != nil {
		t.Fatal(err)
	}
	io.Copy(io.Discard, warm.Body)
	warm.Body.Close()
	client := readers.NewReadClient(consent.ScopeMiniMaxAccountUsageAPIKey, base)
	response, _ := client.Get(endpoint)
	if response != nil {
		io.Copy(io.Discard, response.Body)
		response.Body.Close()
	}
	if got := count.Load() - 1; got > 1 {
		t.Fatalf("single admitted request sent %d wire requests", got)
	}
	if got := count.Load(); got < 2 {
		t.Fatalf("server did not receive the tested request: %d", got)
	}
}

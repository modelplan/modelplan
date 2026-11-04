// SPDX-License-Identifier: MIT
package readers_test

import (
	"context"
	"crypto/tls"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
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

func TestReadClientUsesHTTP1ForEachApprovedStage(t *testing.T) {
	seen := make(chan int, 2)
	server := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { seen <- r.ProtoMajor; w.WriteHeader(http.StatusOK) }))
	server.EnableHTTP2 = true
	server.StartTLS()
	defer server.Close()
	baseTransport := server.Client().Transport.(*http.Transport).Clone()
	baseTransport.ForceAttemptHTTP2 = true
	baseTransport.TLSClientConfig.ServerName = "example.com"
	baseTransport.DialContext = func(ctx context.Context, network, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, network, server.Listener.Addr().String())
	}
	base := &http.Client{Transport: baseTransport, Timeout: 3 * time.Second}
	client := readers.NewReadClient(consent.ScopeMiniMaxAccountUsageAPIKey, base)
	for _, endpoint := range []string{"https://api.minimax.io/v1/token_plan/remains", "https://api.minimax.io/v1/api/openplatform/coding_plan/remains"} {
		response, err := client.Get(endpoint)
		if err != nil {
			t.Fatal(err)
		}
		io.Copy(io.Discard, response.Body)
		response.Body.Close()
		if major := <-seen; major != 1 {
			t.Fatalf("request used HTTP/%d; want HTTP/1", major)
		}
	}
}

func TestReadClientPreservesHTTPSProxyAndTLSTrust(t *testing.T) {
	target := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) }))
	defer target.Close()
	var connects atomic.Int32
	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodConnect {
			t.Errorf("unexpected proxy method %s", r.Method)
			return
		}
		connects.Add(1)
		upstream, err := net.Dial("tcp", target.Listener.Addr().String())
		if err != nil {
			t.Errorf("dial: %v", err)
			return
		}
		conn, _, err := w.(http.Hijacker).Hijack()
		if err != nil {
			upstream.Close()
			t.Errorf("hijack: %v", err)
			return
		}
		if _, err = io.WriteString(conn, "HTTP/1.1 200 Connection Established\r\n\r\n"); err != nil {
			conn.Close()
			upstream.Close()
			return
		}
		go func() { io.Copy(upstream, conn); upstream.Close() }()
		go func() { io.Copy(conn, upstream); conn.Close() }()
	}))
	defer proxy.Close()
	proxyURL, err := url.Parse(proxy.URL)
	if err != nil {
		t.Fatal(err)
	}
	tr := target.Client().Transport.(*http.Transport).Clone()
	tr.Proxy = http.ProxyURL(proxyURL)
	tr.TLSClientConfig.ServerName = "example.com"
	client := readers.NewReadClient(consent.ScopeMiniMaxAccountUsageAPIKey, &http.Client{Transport: tr, Timeout: 3 * time.Second})
	resp, err := client.Get("https://api.minimax.io/v1/token_plan/remains")
	if err != nil {
		t.Fatal(err)
	}
	io.Copy(io.Discard, resp.Body)
	resp.Body.Close()
	if connects.Load() != 1 {
		t.Fatalf("proxy CONNECT count %d", connects.Load())
	}
}

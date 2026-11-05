// SPDX-License-Identifier: MIT
package readers_test

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"errors"
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

func TestGuardedReadDoesNotRetryAReusedConnectionOnWire(t *testing.T) {
	var calls atomic.Int32
	srv := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		n := calls.Add(1)
		if n == 2 {
			c, _, err := w.(http.Hijacker).Hijack()
			if err != nil {
				t.Error(err)
				return
			}
			c.Close()
			return
		}
		_, _ = io.WriteString(w, "ok")
	}))
	defer srv.Close()
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.Proxy = nil
	transport.ForceAttemptHTTP2 = false
	transport.TLSClientConfig = srv.Client().Transport.(*http.Transport).TLSClientConfig.Clone()
	transport.TLSClientConfig.ServerName = "example.com"
	transport.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, network, srv.Listener.Addr().String())
	}
	defer transport.CloseIdleConnections()
	base := &http.Client{Transport: transport, Timeout: 5 * time.Second}
	endpoint := "https://api.minimax.io/v1/token_plan/remains"
	warm, err := base.Get(endpoint)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = io.Copy(io.Discard, warm.Body)
	warm.Body.Close()
	client := readers.NewReadClient(consent.ScopeMiniMaxAccountUsageAPIKey, base)
	resp, err := client.Get(endpoint)
	if resp != nil {
		_, _ = io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}
	if n := calls.Load(); n != 2 {
		t.Fatalf("one guarded request reached server %d times (total including warm request: %d); err=%v", n-1, n, err)
	}
}

type uncheckedTransport struct{ calls *int }

func (u uncheckedTransport) RoundTrip(*http.Request) (*http.Response, error) {
	*u.calls++
	return nil, nil
}

func TestGuardRejectsUnreviewedTransport(t *testing.T) {
	calls := 0
	client := readers.NewReadClient(consent.ScopeMiniMaxAccountUsageAPIKey, &http.Client{Transport: uncheckedTransport{calls: &calls}})
	_, err := client.Get("https://api.minimax.io/v1/token_plan/remains")
	if !errors.Is(err, readers.ErrUnsafeTransport) || calls != 0 {
		t.Fatalf("unchecked transport reached: calls=%d err=%v", calls, err)
	}
}

func TestGuardUsesHTTP1AndPreservesProxyAndTLS(t *testing.T) {
	var protocol atomic.Int32
	srv := httptest.NewUnstartedServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		protocol.Store(int32(r.ProtoMajor))
		_, _ = io.WriteString(w, "ok")
	}))
	srv.EnableHTTP2 = true
	srv.StartTLS()
	defer srv.Close()
	tr := http.DefaultTransport.(*http.Transport).Clone()
	tr.ForceAttemptHTTP2 = true
	tr.TLSClientConfig = srv.Client().Transport.(*http.Transport).TLSClientConfig.Clone()
	tr.TLSClientConfig.ServerName = "example.com"
	tr.TLSClientConfig.NextProtos = []string{"h2", "http/1.1"}
	var proxyCalls atomic.Int32
	tr.Proxy = func(*http.Request) (*url.URL, error) { proxyCalls.Add(1); return nil, nil }
	tr.DialContext = func(ctx context.Context, network, address string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, network, srv.Listener.Addr().String())
	}
	client := readers.NewReadClient(consent.ScopeMiniMaxAccountUsageAPIKey, &http.Client{Transport: tr, Timeout: 5 * time.Second})
	resp, err := client.Get("https://api.minimax.io/v1/token_plan/remains")
	if err != nil {
		t.Fatal(err)
	}
	_, _ = io.Copy(io.Discard, resp.Body)
	resp.Body.Close()
	if protocol.Load() != 1 || proxyCalls.Load() != 1 {
		t.Fatalf("protocol=%d proxy calls=%d", protocol.Load(), proxyCalls.Load())
	}
	if !tr.ForceAttemptHTTP2 || len(tr.TLSClientConfig.NextProtos) != 2 || tr.DisableKeepAlives {
		t.Fatal("caller transport was mutated")
	}
}

func TestGuardRetainsConfiguredProxyAndFailsClosed(t *testing.T) {
	var calls atomic.Int32
	proxy := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls.Add(1)
		if r.Method != http.MethodConnect || r.Host != "api.minimax.io:443" {
			t.Errorf("unexpected proxy target: %s %s", r.Method, r.Host)
		}
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer proxy.Close()
	proxyURL, err := url.Parse(proxy.URL)
	if err != nil {
		t.Fatal(err)
	}
	tr := http.DefaultTransport.(*http.Transport).Clone()
	tr.Proxy = http.ProxyURL(proxyURL)
	tr.DialContext = nil
	client := readers.NewReadClient(consent.ScopeMiniMaxAccountUsageAPIKey, &http.Client{Transport: tr, Timeout: 5 * time.Second})
	_, err = client.Get("https://api.minimax.io/v1/token_plan/remains")
	if err == nil || calls.Load() != 1 {
		t.Fatalf("proxy was bypassed or retried: calls=%d err=%v", calls.Load(), err)
	}
}

func TestGuardRejectsCustomTLSDialer(t *testing.T) {
	var calls atomic.Int32
	tr := http.DefaultTransport.(*http.Transport).Clone()
	tr.DialTLSContext = func(context.Context, string, string) (net.Conn, error) {
		calls.Add(1)
		return nil, errors.New("unexpected dial")
	}
	client := readers.NewReadClient(consent.ScopeMiniMaxAccountUsageAPIKey, &http.Client{Transport: tr})
	_, err := client.Get("https://api.minimax.io/v1/token_plan/remains")
	if !errors.Is(err, readers.ErrUnsafeTransport) || calls.Load() != 0 {
		t.Fatalf("custom TLS dialer reached: calls=%d err=%v", calls.Load(), err)
	}
}

func TestGuardDoesNotWeakenTLSVerification(t *testing.T) {
	srv := httptest.NewTLSServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) {
		t.Error("request reached an untrusted TLS server")
	}))
	defer srv.Close()
	tr := http.DefaultTransport.(*http.Transport).Clone()
	tr.Proxy = nil
	tr.TLSClientConfig = &tls.Config{ServerName: "example.com", RootCAs: x509.NewCertPool()}
	tr.DialContext = func(ctx context.Context, network, _ string) (net.Conn, error) {
		return (&net.Dialer{}).DialContext(ctx, network, srv.Listener.Addr().String())
	}
	client := readers.NewReadClient(consent.ScopeMiniMaxAccountUsageAPIKey, &http.Client{Transport: tr, Timeout: 5 * time.Second})
	if resp, err := client.Get("https://api.minimax.io/v1/token_plan/remains"); err == nil {
		resp.Body.Close()
		t.Fatal("untrusted certificate accepted")
	}
}

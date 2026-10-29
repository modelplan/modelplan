// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"errors"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/readers"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/readers/readertest"
)

// The real fetch entry point must reject an unreviewed authority before the
// recording transport can observe the synthetic credential-bearing request.
func TestMiniMaxProductionTransportRejectsOffHost(t *testing.T) {
	old := minimaxHosts
	t.Cleanup(func() { minimaxHosts = old })
	minimaxHosts = map[string]string{"international": "https://unreviewed.invalid"}
	record := readertest.NewTransport(readertest.Response{StatusCode: 200, Body: minimaxModern})
	got := fetchMiniMax(context.Background(), &http.Client{Transport: record}, "international", "synthetic-canary", minimaxNow)
	if got.Status != "error" || len(record.Requests()) != 0 {
		t.Fatalf("production fetch bypassed admission: status=%s requests=%v", got.Status, record.Requests())
	}
}

// readerFixtureClient leaves the compiled authority intact above the guard.
// Only the final socket transport is redirected to the local synthetic server.
func readerFixtureClient(t *testing.T, srv *httptest.Server, hosts ...string) *http.Client {
	t.Helper()
	target, err := url.Parse(srv.URL)
	if err != nil {
		t.Fatal(err)
	}
	base := srv.Client()
	next := base.Transport
	if next == nil {
		next = http.DefaultTransport
	}
	client := *base
	client.Transport = readerFixtureRoundTripper(func(req *http.Request) (*http.Response, error) {
		allowed := false
		for _, host := range hosts {
			if req.URL.Host == host {
				allowed = true
				break
			}
		}
		if !allowed {
			return nil, fmt.Errorf("unexpected fixture authority %q", req.URL.Host)
		}
		clone := req.Clone(req.Context())
		endpoint := *req.URL
		endpoint.Scheme, endpoint.Host = target.Scheme, target.Host
		clone.URL = &endpoint
		return next.RoundTrip(clone)
	})
	return &client
}

type readerFixtureRoundTripper func(*http.Request) (*http.Response, error)

func (f readerFixtureRoundTripper) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func TestAccountUsageProductionTransportRejectsOffHost(t *testing.T) {
	for _, tc := range []struct {
		name, region string
		hosts        *map[string]string
		fetch        func(context.Context, *http.Client, string, string, time.Time) codexbarEntry
	}{
		{"kimi", "china", &kimiHosts, fetchKimi}, {"zai", "global", &zaiHosts, fetchZai}, {"opencodego", "global", &opencodegoHosts, fetchOpenCodeGo},
	} {
		t.Run(tc.name, func(t *testing.T) {
			old := *tc.hosts
			t.Cleanup(func() { *tc.hosts = old })
			*tc.hosts = map[string]string{tc.region: "https://unreviewed.invalid"}
			record := readertest.NewTransport(readertest.Response{StatusCode: 200, Body: `{}`})
			tc.fetch(context.Background(), &http.Client{Transport: record}, tc.region, "synthetic-canary", minimaxNow)
			if len(record.Requests()) != 0 {
				t.Fatalf("production credential escaped guard: %v", record.Requests())
			}
		})
	}
	for _, provider := range []string{"claude", "kimi-login", "grok"} {
		t.Run(provider, func(t *testing.T) {
			var paths Paths
			var host *string
			switch provider {
			case "claude":
				paths, host = claudeTestPaths(t), &claudeOAuthHost
			case "kimi-login":
				paths, _ = kimiLoginTestPaths(t)
				host = &kimiLoginHost
			case "grok":
				paths, host = grokTestPaths(t), &grokHost
			}
			old, client := *host, nativeClient
			t.Cleanup(func() { *host, nativeClient = old, client })
			*host = "https://unreviewed.invalid"
			record := readertest.NewTransport(readertest.Response{StatusCode: 200, Body: `{}`})
			nativeClient = &http.Client{Transport: record}
			_ = RefreshNative(context.Background(), paths, minimaxNow)
			if len(record.Requests()) != 0 {
				t.Fatalf("production credential escaped guard: %v", record.Requests())
			}
		})
	}
}

// Capture, but do not replace, the exact guarded client constructed by the
// production reader. Reusing it probes the same read's stop and request budget.
func TestProductionReaderClientsEnforceReadBoundary(t *testing.T) {
	for _, provider := range []string{"minimax", "claude", "kimi", "kimi-login", "zai", "opencodego", "grok"} {
		for _, status := range []int{200, 401, 403, 307} {
			t.Run(fmt.Sprintf("%s/%d", provider, status), func(t *testing.T) {
				var run func(*http.Client)
				var endpoint, scope string
				var responses []readertest.Response
				switch provider {
				case "minimax":
					endpoint, scope = "https://api.minimax.io/v1/token_plan/remains", consent.ScopeMiniMaxAccountUsageAPIKey
					run = func(c *http.Client) { fetchMiniMax(context.Background(), c, "international", "synthetic", minimaxNow) }
					responses = []readertest.Response{{StatusCode: 404}, {StatusCode: 200, Body: minimaxModern}}
				case "kimi":
					endpoint, scope = "https://api.kimi.com/coding/v1/usages", consent.ScopeKimiAccountUsageAPIKey
					run = func(c *http.Client) { fetchKimi(context.Background(), c, "china", "synthetic", kimiNow) }
				case "zai":
					endpoint, scope = "https://api.z.ai/api/monitor/usage/quota/limit", consent.ScopeZaiAccountUsageAPIKey
					run = func(c *http.Client) { fetchZai(context.Background(), c, "global", "synthetic", zaiNow) }
				case "opencodego":
					endpoint, scope = "https://opencode.ai/zen/go/v1/usage", consent.ScopeOpenCodeGoAccountUsageAPIKey
					run = func(c *http.Client) { fetchOpenCodeGo(context.Background(), c, "global", "synthetic", minimaxNow) }
				default:
					var p Paths
					at := minimaxNow
					switch provider {
					case "claude":
						p, at = claudeTestPaths(t), claudeTestNow
						endpoint, scope = "https://api.anthropic.com/api/oauth/usage", consent.ScopeClaudeAccountUsageSavedLogin
						profile, err := os.ReadFile("testdata/claude-account/profile.json")
						if err != nil {
							t.Fatal(err)
						}
						usage, err := os.ReadFile("testdata/claude-account/usage.json")
						if err != nil {
							t.Fatal(err)
						}
						responses = []readertest.Response{{StatusCode: 200, Body: string(profile)}, {StatusCode: 200, Body: string(usage)}}
					case "kimi-login":
						p, _ = kimiLoginTestPaths(t)
						at = kimiNow
						endpoint, scope = "https://api.kimi.com/coding/v1/usages", consent.ScopeKimiAccountUsageSavedLogin
					case "grok":
						p, at = grokTestPaths(t), grokNow
						endpoint, scope = "https://cli-chat-proxy.grok.com/v1/billing?format=credits", consent.ScopeGrokAccountUsageSavedLogin
					}
					old := nativeClient
					t.Cleanup(func() { nativeClient = old })
					productionID := provider
					if productionID == "kimi-login" {
						productionID = "kimi"
					}
					productionConsent(t, productionID, true)
					p = ProductionPaths(t.TempDir(), "1.0.0")
					run = func(c *http.Client) { nativeClient = c; _ = RefreshNative(context.Background(), p, at) }
				}
				if len(responses) == 0 {
					responses = []readertest.Response{{StatusCode: 200, Body: `{}`}}
				}
				if status != 200 {
					responses = []readertest.Response{{StatusCode: status, Header: http.Header{"Location": {endpoint}}}}
				}
				record := readertest.NewTransport(responses...)
				previous := accountReadClient
				var clients []*http.Client
				var mu sync.Mutex
				accountReadClient = func(s string, base *http.Client) *http.Client {
					client := previous(s, base)
					if s != scope {
						t.Errorf("wrong production scope %q", s)
					}
					if _, ok := client.Transport.(*readers.ReadTransport); !ok {
						t.Error("production client missing transport guard")
					}
					mu.Lock()
					clients = append(clients, client)
					mu.Unlock()
					return client
				}
				t.Cleanup(func() { accountReadClient = previous })
				run(&http.Client{Transport: record})
				mu.Lock()
				defer mu.Unlock()
				if len(clients) != 1 {
					t.Fatalf("guard recreated within a logical read: %d", len(clients))
				}
				wantCalls := len(responses)
				if len(record.Requests()) != wantCalls {
					t.Fatalf("production request set: %v", record.Requests())
				}
				expected := readers.ErrReadExhausted
				if status == 401 || status == 403 {
					expected = readers.ErrAuthorizationStopped
				}
				if status == 307 {
					expected = readers.ErrRequestNotAllowed
				}
				if provider == "minimax" && status == 200 {
					endpoint = "https://api.minimax.io/v1/api/openplatform/coding_plan/remains"
				}
				for range 3 {
					req, err := http.NewRequest("GET", endpoint, nil)
					if err != nil {
						t.Fatal(err)
					}
					req.Header.Set("Authorization", "Bearer synthetic-canary")
					resp, err := clients[0].Do(req)
					if resp != nil {
						resp.Body.Close()
					}
					if !errors.Is(err, expected) {
						t.Fatalf("read boundary not enforced: %v", err)
					}
				}
				if len(record.Requests()) != wantCalls {
					t.Fatalf("extra request reached recording: %v", record.Requests())
				}
			})
		}
	}
}

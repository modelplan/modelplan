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
	"strings"
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
	for _, provider := range []string{"claude", "kimi-login", "grok", "gemini", "cursor"} {
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
			case "gemini":
				paths, host = geminiTestPaths(t), &geminiHost
			case "cursor":
				paths, _ = cursorAdmittedPaths(t)
				host = &cursorHost
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

// Keep the real constructor, consent, shared budget and collector. The seam
// observes the production-created client without replacing its guard.
func TestProductionApprovedPOSTClientsKeepOneGuardAndDeadline(t *testing.T) {
	for _, provider := range []string{"gemini", "cursor"} {
		for _, slot := range []int{0, 1} {
			for _, status := range []int{200, 401, 403, 307} {
				if status == 200 && slot == 1 {
					continue
				}
				t.Run(fmt.Sprintf("%s/%d/%d", provider, slot, status), func(t *testing.T) {
					at := geminiNow
					scope := consent.ScopeGeminiAccountUsageSavedLogin
					files := []string{"assist.json", "quota.json"}
					endpoint := "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
					body := `{"project":"synthetic-project-001"}`
					if provider == "gemini" {
						_ = geminiTestPaths(t)
					} else {
						_, _ = cursorAdmittedPaths(t)
						at = cursorNow
						scope = consent.ScopeCursorAccountUsageSavedLogin
						files = []string{"merged-plan.json", "period-usage.json"}
						endpoint = "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage"
						body = `{}`
					}
					productionConsent(t, provider, true)
					paths := ProductionPaths(t.TempDir(), "1.0.0")
					responses := []readertest.Response{}
					for i, file := range files {
						raw, err := os.ReadFile("testdata/" + provider + "/" + file)
						if err != nil {
							t.Fatal(err)
						}
						response := readertest.Response{StatusCode: 200, Body: string(raw)}
						if status != 200 && i == slot {
							response = readertest.Response{StatusCode: status, Header: http.Header{"Location": {"https://unreviewed.invalid/credential-target"}}}
						}
						responses = append(responses, response)
					}
					record := readertest.NewTransport(responses...)
					var deadlines []time.Time
					base := &http.Client{Transport: readerFixtureRoundTripper(func(r *http.Request) (*http.Response, error) {
						deadline, ok := r.Context().Deadline()
						if !ok || time.Until(deadline) > nativeTimeout {
							t.Error("logical read has no bounded deadline")
						}
						deadlines = append(deadlines, deadline)
						return record.RoundTrip(r)
					})}
					previousFactory, previousClient := accountReadClient, nativeClient
					var clients []*http.Client
					accountReadClient = func(s string, c *http.Client) *http.Client {
						if s != scope {
							t.Errorf("wrong POST scope: %s", s)
						}
						client := previousFactory(s, c)
						if _, ok := client.Transport.(*readers.ReadTransport); !ok {
							t.Error("production POST bypassed transport")
						}
						clients = append(clients, client)
						return client
					}
					nativeClient = base
					t.Cleanup(func() { accountReadClient, nativeClient = previousFactory, previousClient })
					_ = RefreshNative(context.Background(), paths, at)
					want := 2
					if status != 200 {
						want = slot + 1
					}
					if len(clients) != 1 || len(record.Requests()) != want {
						t.Fatalf("logical POST guard/request set: clients=%d requests=%v", len(clients), record.Requests())
					}
					for _, deadline := range deadlines {
						if deadline != deadlines[0] {
							t.Fatal("deadline restarted between POST stages")
						}
					}
					expected := readers.ErrReadExhausted
					if status == 401 || status == 403 {
						expected = readers.ErrAuthorizationStopped
					}
					if status == 307 {
						expected = readers.ErrRequestNotAllowed
					}
					for range 3 {
						request, err := http.NewRequest("POST", endpoint, strings.NewReader(body))
						if err != nil {
							t.Fatal(err)
						}
						request.Header.Set("Accept", "application/json")
						request.Header.Set("Content-Type", "application/json")
						request.Header.Set("User-Agent", "modelplan")
						request.Header.Set("Authorization", "Bearer synthetic-canary")
						if provider == "cursor" {
							request.Header.Set("Connect-Protocol-Version", "1")
						}
						response, err := clients[0].Do(request)
						if response != nil {
							response.Body.Close()
						}
						if !errors.Is(err, expected) {
							t.Fatalf("POST boundary escaped: %v", err)
						}
					}
					if len(record.Requests()) != want {
						t.Fatal("POST retry or redirect reached provider")
					}
				})
			}
		}
	}
}

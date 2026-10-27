package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"
)

const antigravityFixture = `{"userStatus":{"email":"private-email-canary","cascadeModelConfigData":{"clientModelConfigs":[{"label":"private-label-canary","modelOrAlias":{"model":"MODEL_CLAUDE"},"quotaInfo":{"remainingFraction":0.25,"resetTime":"2026-11-01T00:00:00Z"}},{"modelOrAlias":{"model":"MODEL_GEMINI"},"quotaInfo":{"remainingFraction":0}},{"modelOrAlias":{"model":"MISSING"},"quotaInfo":{}}]}}}`

func antigravityTestServer(t *testing.T, h http.HandlerFunc) (AntigravityServer, *httptest.Server) {
	t.Helper()
	old := antigravityVerify
	t.Cleanup(func() { antigravityVerify = old })
	antigravityVerify = func(context.Context, AntigravityServer) error { return nil }
	s := httptest.NewServer(h)
	t.Cleanup(s.Close)
	_, port, _ := net.SplitHostPort(s.Listener.Addr().String())
	n, _ := strconv.Atoi(port)
	return AntigravityServer{PID: 101, Port: n, CSRF: "csrf-canary"}, s
}
func TestAntigravityLocalRPCAndCache(t *testing.T) {
	isolateHome(t)
	calls := 0
	fail := false
	desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) {
		calls++
		if r.Method != "POST" || r.URL.Path != "/exa.language_server_pb.LanguageServerService/GetUserStatus" || r.Header.Get("X-Codeium-Csrf-Token") != "csrf-canary" {
			t.Error("wrong RPC")
		}
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		if _, ok := body["metadata"]; !ok || strings.Contains(r.Header.Get("Authorization"), "Bearer") {
			t.Error("wrong metadata")
		}
		if fail {
			http.Error(w, "private-error-canary", 500)
			return
		}
		_, _ = w.Write([]byte(antigravityFixture))
	})
	ctx := WithAntigravityServer(context.Background(), desc)
	cache := t.TempDir()
	e := collectAntigravity(ctx, nil, cache, now)
	if e.Status != "ok" || len(e.Windows) != 2 || *e.Windows[0].UsedPercent != 75 || *e.Windows[1].UsedPercent != 100 || e.Plan != "" || e.SubscriptionRef != "" {
		t.Fatal(e)
	}
	collectAntigravity(ctx, nil, cache, now.Add(time.Minute))
	if calls != 1 {
		t.Fatal(calls)
	}
	fail = true
	collectAntigravity(ctx, nil, cache, now.Add(10*time.Minute))
	r := ReadAntigravityCache(ctx, cache, now.Add(11*time.Minute))
	if calls != 2 || !r.Beta || r.Freshness != "stale" || !r.ObservedAt.Equal(now) || r.Reading == nil {
		t.Fatal(r)
	}
	b, _ := os.ReadFile(antigravityStatePath(cache))
	out, _ := json.Marshal(r)
	for _, canary := range []string{"csrf-canary", "private-email-canary", "private-label-canary", "private-error-canary"} {
		if bytes.Contains(append(b, out...), []byte(canary)) {
			t.Fatal("private text persisted")
		}
	}
	r = ReadAntigravityCache(ctx, cache, time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC))
	if len(r.Reading.Windows) != 1 || r.Reading.Windows[0].Limit != "MODEL_GEMINI" {
		t.Fatal(r)
	}
}
func TestAntigravityAdmissionAndDiscovery(t *testing.T) {
	isolateHome(t)
	old := antigravityCommand
	t.Cleanup(func() { antigravityCommand = old })
	calls := 0
	antigravityCommand = func(context.Context, string, ...string) ([]byte, error) { calls++; return nil, nil }
	for _, mode := range []string{"off", "passive"} {
		t.Setenv("MODELPLAN_READERS", mode)
		collectAntigravity(context.Background(), nil, t.TempDir(), now)
	}
	t.Setenv("MODELPLAN_READERS", "")
	collectAntigravity(WithAntigravityAccess(context.Background(), AntigravityAccess{Allowed: true, Denied: true}), nil, t.TempDir(), now)
	if calls != 0 {
		t.Fatal("discovery before admission")
	}
	e := collectAntigravity(context.Background(), nil, t.TempDir(), now)
	if e.Status != "error" || e.Error != "Open Antigravity" || calls != 1 {
		t.Fatal(e, calls)
	}
	raw := []byte(fmt.Sprintf("123 %d language_server /app/language_server --app_data_dir antigravity --csrf_token synthetic-token --extension_server_port 9876\n124 %d language_server language_server --app_data_dir other --csrf_token private --extension_server_port 9999\n", os.Getuid(), os.Getuid()))
	servers := antigravityServers(raw)
	if len(servers) != 1 || servers[0].Port != 9876 {
		t.Fatal(servers)
	}
	if got := antigravityServers([]byte("1 language_server --app_data_dir antigravity --csrf_token x --extension_server_port 70000")); len(got) != 0 {
		t.Fatal(got)
	}
}
func TestAntigravityNoRedirectRetryOrOAuth(t *testing.T) {
	isolateHome(t)
	calls := 0
	targetCalls := 0
	target := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { targetCalls++ }))
	defer target.Close()
	desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) { calls++; http.Redirect(w, r, target.URL, 302) })
	e := fetchAntigravity(WithAntigravityServer(context.Background(), desc), nil, "", "", now)
	if e.Status != "error" || calls != 1 || targetCalls != 0 {
		t.Fatal(e, calls, targetCalls)
	}
	for _, raw := range []string{`null`, `{}`, `{"userStatus":{"cascadeModelConfigData":{"clientModelConfigs":[{"modelOrAlias":{"model":"a"},"quotaInfo":{"remainingFraction":2}}]}}}`} {
		if e := parseAntigravity([]byte(raw), now); e.Status != "error" {
			t.Fatal(e)
		}
	}
}

func TestAntigravityListenerBindingBeforeHTTP(t *testing.T) {
	isolateHome(t)
	for _, mode := range []string{"wrong_owner", "reused_port", "exited", "nonce_changed", "owner_changes_after_dial"} {
		t.Run(mode, func(t *testing.T) {
			calls := 0
			desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) { calls++; _, _ = w.Write([]byte(antigravityFixture)) })
			antigravityVerify = verifyAntigravityServer
			old := antigravityCommand
			t.Cleanup(func() { antigravityCommand = old })
			checks := 0
			antigravityCommand = func(_ context.Context, bin string, args ...string) ([]byte, error) {
				if bin == "/bin/ps" {
					checks++
					if mode == "exited" {
						return nil, errors.New("synthetic exited process")
					}
					nonce := desc.CSRF
					if mode == "nonce_changed" {
						nonce = "other-nonce"
					}
					return []byte(fmt.Sprintf("%d %d language_server /app/language_server --app_data_dir antigravity --csrf_token %s --extension_server_port %d\n", desc.PID, os.Getuid(), nonce, desc.Port)), nil
				}
				owner := desc.PID
				if mode == "wrong_owner" || mode == "reused_port" || (mode == "owner_changes_after_dial" && checks >= 2) {
					owner++
				}
				return []byte(fmt.Sprintf("p%d\nu%d\nn127.0.0.1:%d\n", owner, os.Getuid(), desc.Port)), nil
			}
			e := fetchAntigravity(WithAntigravityServer(context.Background(), desc), nil, "", "", now)
			if e.Status != "error" || calls != 0 {
				t.Fatal("nonce sent to an unbound listener", mode, e, calls)
			}
		})
	}
}
func TestAntigravityNativeFailureGenerationAndLegacyRecovery(t *testing.T) {
	isolateHome(t)
	expired := false
	desc, _ := antigravityTestServer(t, func(w http.ResponseWriter, r *http.Request) {
		if expired {
			w.WriteHeader(401)
			return
		}
		_, _ = w.Write([]byte(antigravityFixture))
	})
	p := nativePaths(t)
	_ = SetConnection(p.ConnectionsFile, QuotaSource{Provider: "antigravity", Backend: BackendNative, Enabled: true})
	ctx := WithAntigravityServer(context.Background(), desc)
	if err := RefreshNative(ctx, p, now); err != nil {
		t.Fatal(err)
	}
	expired = true
	_ = RefreshNative(ctx, p, now.Add(10*time.Minute))
	found := false
	for _, s := range Read(p, now.Add(10*time.Minute)).Sources {
		if s.Source == "native:antigravity" {
			found = true
			if s.Status != "unavailable" {
				t.Fatal(s)
			}
		}
	}
	if !found {
		t.Fatal("native source missing")
	}
	r := ReadAntigravityCache(ctx, p.Cache, now.Add(10*time.Minute))
	if r.Reading == nil || r.Freshness != "stale" || !r.ObservedAt.Equal(now) {
		t.Fatal(r)
	}
	expired = false
	_ = RefreshNative(ctx, p, now.Add(19*time.Minute))
	if !loadAntigravityState(p.Cache).Good.ObservedAt.Equal(now) {
		t.Fatal("backoff bypass")
	}
	_ = RefreshNative(ctx, p, now.Add(20*time.Minute))
	if !loadAntigravityState(p.Cache).Good.ObservedAt.Equal(now.Add(20 * time.Minute)) {
		t.Fatal("legacy recovery blocked")
	}
	// Explicit generations isolate both cache-only, throttled and failed reads.
	cache := t.TempDir()
	ctxA := WithAntigravityAccess(ctx, AntigravityAccess{Allowed: true, LoginGeneration: strings.Repeat("a", 64)})
	ctxB := WithAntigravityAccess(ctx, AntigravityAccess{Allowed: true, LoginGeneration: strings.Repeat("b", 64)})
	collectAntigravity(ctxA, nil, cache, now)
	if r := ReadAntigravityCache(ctxB, cache, now.Add(time.Minute)); r.Reading != nil {
		t.Fatal(r)
	}
	if e := collectAntigravity(ctxB, nil, cache, now.Add(time.Minute)); e.Status != "error" || len(e.Windows) != 0 {
		t.Fatal(e)
	}
	if !loadAntigravityState(cache).AttemptAt.Equal(now) {
		t.Fatal("generation bypassed floor")
	}
	expired = true
	if e := collectAntigravity(ctxB, nil, cache, now.Add(10*time.Minute)); e.Status != "error" || len(e.Windows) != 0 {
		t.Fatal(e)
	}
	if r := ReadAntigravityCache(ctxB, cache, now.Add(10*time.Minute)); r.Reading != nil || r.Availability != "expired_login" {
		t.Fatal(r)
	}
}

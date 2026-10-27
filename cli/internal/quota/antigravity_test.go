package quota

import (
	"bytes"
	"context"
	"encoding/json"
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
	s := httptest.NewServer(h)
	t.Cleanup(s.Close)
	_, port, _ := net.SplitHostPort(s.Listener.Addr().String())
	n, _ := strconv.Atoi(port)
	return AntigravityServer{Port: n, CSRF: "csrf-canary"}, s
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
	raw := []byte("123 /app/language_server --app_data_dir antigravity --csrf_token synthetic-token --extension_server_port 9876\n124 language_server --app_data_dir other --csrf_token private --extension_server_port 9999\n")
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

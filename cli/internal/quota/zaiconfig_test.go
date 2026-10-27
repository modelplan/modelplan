package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func zaiConfigTestFile(t *testing.T, body string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "config.json")
	if os.WriteFile(p, []byte(body), 0600) != nil {
		t.Fatal("write")
	}
	return p
}
func TestZaiConfigProvenanceAndRegion(t *testing.T) {
	isolateHome(t)
	for _, tc := range []struct{ base, region string }{
		{"https://api.z.ai/api/anthropic", "global"}, {"https://open.bigmodel.cn/api/anthropic/", "bigmodel-cn"}, {"https://api.z.ai/api/coding/paas/v4", "global"},
		{"https://api.z.ai.evil.test/api/anthropic", ""}, {"http://api.z.ai/api/anthropic", ""}, {"https://api.z.ai:443/api/anthropic", ""}, {"https://secret@api.z.ai/api/anthropic", ""}, {"https://api.z.ai/api/anthropic?key=x", ""}, {"https://api.z.ai/api/anthropic#x", ""}, {"https://api.anthropic.com/api/anthropic", ""}, {"https://api.z.ai/api/paas/v4", ""},
	} {
		if got := ZaiConfigRegion(tc.base); got != tc.region {
			t.Fatal(tc, got)
		}
	}
	for _, base := range []string{"https://api.z.ai/api/anthropic", "https://open.bigmodel.cn/api/anthropic", "https://unrelated.test/api/anthropic"} {
		b, _ := json.Marshal(map[string]any{"env": map[string]string{"ANTHROPIC_BASE_URL": base, "ANTHROPIC_AUTH_TOKEN": "key-canary"}})
		source := ZaiConfigSource{Tool: "claude-code", SettingsPath: zaiConfigTestFile(t, string(b))}
		region, key, state := zaiConfiguredKey(source)
		if strings.Contains(base, "unrelated") {
			if key != "" || state != "not_supported_yet" {
				t.Fatal("foreign key accepted")
			}
		} else if key != "key-canary" || region == "" || state != "" {
			t.Fatal(region, state)
		}
	}
}
func TestZaiConfigOpenCodeSelectedOnly(t *testing.T) {
	isolateHome(t)
	auth := zaiConfigTestFile(t, `{"selected":{"type":"api","key":"selected-canary"},"unrelated":{"type":"api","key":"other-canary"}}`)
	source := ZaiConfigSource{Tool: "opencode", SettingsPath: zaiConfigTestFile(t, `{"provider":{"selected":{"options":{"baseURL":"https://open.bigmodel.cn/api/coding/paas/v4"}},"unrelated":{"options":{"baseURL":"https://api.other.test"}}}}`), AuthPath: auth, OpenCodeProvider: "selected"}
	region, key, state := zaiConfiguredKey(source)
	if region != "bigmodel-cn" || key != "selected-canary" || state != "" {
		t.Fatal(region, state)
	}
	source.OpenCodeProvider = "unrelated"
	if _, key, state := zaiConfiguredKey(source); key != "" || state != "not_supported_yet" {
		t.Fatal("foreign auth imported")
	}
	source.OpenCodeProvider = "selected"
	source.AuthPath = zaiConfigTestFile(t, `{"selected":{"type":"oauth","access":"oauth-canary"}}`)
	if _, key, state := zaiConfiguredKey(source); key != "" || state != "not_supported_yet" {
		t.Fatal("OAuth accepted")
	}
	t.Setenv("GLM_TEST_KEY", "env-canary")
	source.SettingsPath = zaiConfigTestFile(t, `{"provider":{"selected":{"options":{"baseURL":"https://api.z.ai/api/coding/paas/v4","apiKey":"{env:GLM_TEST_KEY}"}}}}`)
	if _, key, state := zaiConfiguredKey(source); key != "env-canary" || state != "" {
		t.Fatal(state)
	}
	target := zaiConfigTestFile(t, `{}`)
	link := filepath.Join(t.TempDir(), "link")
	_ = os.Symlink(filepath.Dir(target), link)
	source.SettingsPath = filepath.Join(link, filepath.Base(target))
	if _, key, state := zaiConfiguredKey(source); key != "" || state != "not_detected" {
		t.Fatal("ancestor symlink accepted")
	}
}
func TestZaiConfigConsentPassiveCadenceAndRedaction(t *testing.T) {
	isolateHome(t)
	calls := 0
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		if r.URL.Path != "/api/monitor/usage/quota/limit" || r.Header.Get("Authorization") != "Bearer key-canary" {
			t.Error("bad request")
		}
		_, _ = w.Write([]byte(`{"success":true,"code":200,"data":{"planName":"provider-private-canary","limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25}]}}`))
	}))
	defer server.Close()
	oldHost, oldClient := zaiHosts["global"], nativeClient
	t.Cleanup(func() { zaiHosts["global"] = oldHost; nativeClient = oldClient })
	zaiHosts["global"] = server.URL
	nativeClient = server.Client()
	source := ZaiConfigSource{Tool: "claude-code", SettingsPath: zaiConfigTestFile(t, `{"env":{"ANTHROPIC_BASE_URL":"https://api.z.ai/api/anthropic","ANTHROPIC_AUTH_TOKEN":"key-canary"}}`)}
	cache := t.TempDir()
	ctx := context.Background()
	r := RefreshConfiguredZai(ctx, cache, source, now)
	if calls != 0 || r.Availability != "consent_required" {
		t.Fatal(r, calls)
	}
	ctx = WithZaiConfigAccess(ctx, ZaiConfigAccess{Allowed: true})
	t.Setenv("MODELPLAN_READERS", "passive")
	r = RefreshConfiguredZai(ctx, cache, source, now)
	if calls != 1 || r.Reading == nil || r.Availability != "ok" || !r.Beta {
		t.Fatal(r, calls)
	}
	RefreshConfiguredZai(ctx, cache, source, now.Add(time.Minute))
	if calls != 1 {
		t.Fatal("gate bypass")
	}
	b, _ := os.ReadFile(zaiConfigStatePath(cache))
	out, _ := json.Marshal(r)
	for _, canary := range []string{"key-canary", "provider-private-canary", source.SettingsPath} {
		if bytes.Contains(append(b, out...), []byte(canary)) {
			t.Fatal("private bytes persisted")
		}
	}
	t.Setenv("MODELPLAN_READERS", "off")
	RefreshConfiguredZai(ctx, cache, source, now.Add(time.Hour))
	if calls != 1 {
		t.Fatal("off ignored")
	}
	// --json/cache projection never reopens the tool config or requests usage.
	_ = os.Remove(source.SettingsPath)
	ReadZaiConfigCache(ctx, cache, now.Add(time.Hour))
	if calls != 1 {
		t.Fatal("cache read requested")
	}
}

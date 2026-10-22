package quota

import (
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

var zaiNow = time.Date(2026, 10, 22, 2, 0, 0, 0, time.UTC)

func zaiParse(t *testing.T, body string) codexbarEntry {
	t.Helper()
	var r zaiResponse
	if err := json.Unmarshal([]byte(body), &r); err != nil {
		t.Fatal(err)
	}
	return parseZai(r, zaiNow)
}

// The payload shapes of CodexBar's ZaiPlugin tests: five-hour and weekly token windows plus the
// monthly MCP marker.
func TestParseZai(t *testing.T) {
	five, week, mcp := zaiNow.Add(3*time.Hour).UnixMilli(), zaiNow.Add(4*24*time.Hour).UnixMilli(), zaiNow.Add(20*24*time.Hour).UnixMilli()
	e := zaiParse(t, `{"code":200,"success":true,"data":{"level":"pro","limits":[
		{"type":"TIME_LIMIT","unit":5,"number":1,"percentage":22,"nextResetTime":`+itoa64(mcp)+`},
		{"type":"TOKENS_LIMIT","unit":6,"number":1,"percentage":9,"nextResetTime":`+itoa64(week)+`},
		{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":25,"usage":1000,"currentValue":300,"remaining":700,"nextResetTime":`+itoa64(five)+`},
		{"type":"SOMETHING_NEW","unit":1,"number":1,"percentage":1}]}}`)
	if e.Status != "ok" || e.Plan != "pro" || len(e.Windows) != 3 {
		t.Fatalf("entry = %+v", e)
	}
	got := []string{}
	for _, w := range e.Windows {
		got = append(got, w.Kind+"/"+w.Limit+"/"+itoa(w.WindowMinutes)+"/"+itoa(int(*w.UsedPercent)))
	}
	if strings.Join(got, " ") != "five_hour//300/30 weekly//10080/9 monthly/MCP/43200/22" {
		t.Errorf("windows = %v", got)
	}
	if !e.Windows[0].ResetsAt.Equal(time.UnixMilli(five)) {
		t.Errorf("reset = %v", e.Windows[0].ResetsAt)
	}

	// A five-hour reset ten hours away is a clock mix-up: no reset rather than a wrong one.
	far := zaiNow.Add(10 * time.Hour).UnixMilli()
	e = zaiParse(t, `{"code":200,"success":true,"data":{"limits":[{"type":"CREDIT_LIMIT","unit":3,"number":5,"percentage":40,"nextResetTime":`+itoa64(far)+`}]}}`)
	if e.Status != "ok" || e.Windows[0].ResetsAt != nil || *e.Windows[0].UsedPercent != 40 {
		t.Fatalf("implausible reset = %+v", e.Windows)
	}

	for body, want := range map[string]string{
		`{"code":1001,"success":false,"msg":"Invalid key"}`:                                  "the quota API said no: Invalid key",
		`{"code":200,"success":true,"data":{}}`:                                              "unsupported quota format",
		`{"code":200,"success":true,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":3}]}}`:   "unsupported quota entry",
		`{"code":200,"success":true,"data":{"limits":[{"type":"TOKENS_LIMIT","unit":"x"}]}}`: "unsupported quota entry",
	} {
		if e := zaiParse(t, body); e.Status != "error" || e.Error != want {
			t.Errorf("%s: %+v", body, e)
		}
	}
}

func itoa64(v int64) string { b, _ := json.Marshal(v); return string(b) }

// zaiServer answers like the quota endpoint for the key "test-key" and records what it was sent.
func zaiServer(t *testing.T) (*[]string, func()) {
	var seen []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		seen = append(seen, r.Method+" "+r.URL.Path+" "+r.Header.Get("Authorization"))
		if r.Header.Get("Authorization") != "Bearer test-key" {
			w.WriteHeader(http.StatusUnauthorized)
			return
		}
		w.Write([]byte(`{"code":200,"success":true,"data":{"planName":"GLM Coding Pro","limits":[{"type":"TOKENS_LIMIT","unit":3,"number":5,"percentage":61,"nextResetTime":` + itoa64(time.Now().Add(time.Hour).UnixMilli()) + `}]}}`))
	}))
	oldHosts, oldClient := zaiHosts, nativeClient
	zaiHosts, nativeClient = map[string]string{"global": srv.URL, "bigmodel-cn": srv.URL}, srv.Client()
	return &seen, func() { srv.Close(); zaiHosts, nativeClient = oldHosts, oldClient }
}

func nativePaths(t *testing.T) Paths {
	dir := t.TempDir()
	return Paths{Cache: filepath.Join(dir, "cache"), CodexBarFile: filepath.Join(dir, "codexbar.json"), ConnectionsFile: filepath.Join(dir, "connections.json")}
}

func TestNativeZaiRefresh(t *testing.T) {
	seen, done := zaiServer(t)
	defer done()
	p := nativePaths(t)
	t.Setenv("Z_AI_API_KEY", "test-key")
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "zai", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	now := time.Now()
	if !NativeDue(p, now) {
		t.Fatal("nothing read yet: due")
	}
	if err := RefreshNative(context.Background(), p, now); err != nil {
		t.Fatal(err)
	}
	if strings.Join(*seen, ",") != "GET /api/monitor/usage/quota/limit Bearer test-key" {
		t.Fatalf("requests = %v", *seen)
	}
	b, _ := os.ReadFile(nativePath(p.Cache))
	if strings.Contains(string(b), "test-key") {
		t.Fatal("the key reached the cache")
	}
	if NativeDue(p, now.Add(5*time.Minute)) || !NativeDue(p, now.Add(10*time.Minute)) {
		t.Fatal("at most every 10 minutes")
	}
	r := Read(p, now)
	var a *Account
	for i := range r.Accounts {
		if r.Accounts[i].Source == "native:zai" {
			a = &r.Accounts[i]
		}
	}
	if a == nil || a.Via != "native" || a.Plan != "GLM Coding Pro" || len(a.Windows) != 1 || *a.Windows[0].UsedPercent != 61 {
		t.Fatalf("report = %+v", r)
	}

	// A rejected key is a reason, and the next try waits longer.
	t.Setenv("Z_AI_API_KEY", "other-key")
	_ = RefreshNative(context.Background(), p, now)
	r = Read(p, now)
	for _, s := range r.Sources {
		if s.Source == "native:zai" && (s.Status != "unavailable" || s.Reason != "the API key was rejected (HTTP 401)") {
			t.Fatalf("status = %+v", s)
		}
	}
	if NativeDue(p, now.Add(15*time.Minute)) || !NativeDue(p, now.Add(30*time.Minute)) {
		t.Fatal("a failure waits half an hour")
	}
}

func TestSelections(t *testing.T) {
	p := nativePaths(t)
	t.Setenv("Z_AI_API_KEY", "")
	if err := SetCodexBarEnabled(p.CodexBarFile, []string{"cursor", "zai", "kiro"}); err != nil {
		t.Fatal(err)
	}
	sel := func() map[string]Selection {
		ss, err := Selections(p)
		if err != nil {
			t.Fatal(err)
		}
		m := map[string]Selection{}
		for _, s := range ss {
			m[s.Provider] = s
		}
		return m
	}
	if m := sel(); m["zai"].Backend != BackendCodexBar || m["zai"].Origin != "codexbar.json" || strings.Join(CodexBarActive(p), ",") != "cursor,kiro,zai" {
		t.Fatalf("legacy = %+v", m)
	}
	// An explicit entry decides: native for zai (blocked until its key is set), off for kiro.
	SetConnection(p.ConnectionsFile, QuotaSource{Provider: "zai", Backend: BackendNative, Enabled: true, Region: "bigmodel-cn"})
	SetConnection(p.ConnectionsFile, QuotaSource{Provider: "kiro", Backend: BackendNative, Enabled: false})
	m := sel()
	if z := m["zai"]; z.Backend != BackendNative || z.Region != "bigmodel-cn" || z.KeyEnv != "Z_AI_API_KEY" || z.KeySet || z.Blocked != "no-key" {
		t.Fatalf("zai = %+v", z)
	}
	if m["kiro"].Backend != BackendOff || strings.Join(CodexBarActive(p), ",") != "cursor" {
		t.Fatalf("kiro = %+v, codexbar = %v", m["kiro"], CodexBarActive(p))
	}
	t.Setenv("Z_AI_API_KEY", "test-key")
	if z := sel()["zai"]; !z.KeySet || z.Blocked != "" {
		t.Fatalf("with the key: %+v", z)
	}
	// The off-switches stop their own backend only; nothing falls back to the other one.
	t.Setenv("MODELPLAN_NATIVE", "off")
	if z := sel()["zai"]; z.Blocked != "native-off" || len(active(p, BackendNative)) != 0 || strings.Join(CodexBarActive(p), ",") != "cursor" {
		t.Fatalf("native off: %+v", z)
	}
	t.Setenv("MODELPLAN_NATIVE", "")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	if c := sel()["cursor"]; c.Blocked != "codexbar-off" || len(CodexBarActive(p)) != 0 || len(active(p, BackendNative)) != 1 {
		t.Fatalf("codexbar off: %+v", c)
	}
	t.Setenv("MODELPLAN_CODEXBAR", "")

	// A provider without a native reader set to native reads nothing; CodexBar does not step in.
	os.WriteFile(p.ConnectionsFile, []byte(`{"schemaVersion":1,"quotaSources":[{"provider":"cursor","backend":"native","enabled":true}]}`), 0o600)
	if c := sel()["cursor"]; c.Blocked != "no-native-reader" || strings.Join(CodexBarActive(p), ",") != "kiro,zai" {
		t.Fatalf("cursor = %+v, codexbar = %v", c, CodexBarActive(p))
	}
	// An unusable file stops every provider it might decide, legacy ones included.
	for _, bad := range []string{`{"schemaVersion":2}`, `{"schemaVersion":1,"quotaSources":[{"provider":"nope","backend":"native"}]}`,
		`{"schemaVersion":1,"quotaSources":[{"provider":"zai","backend":"native","keyEnv":"A B"}]}`,
		`{"schemaVersion":1,"quotaSources":[{"provider":"zai","backend":"native","region":"mars"}]}`,
		`{"schemaVersion":1,"quotaSources":[{"provider":"zai","backend":"native"},{"provider":"zai","backend":"codexbar-compat"}]}`} {
		os.WriteFile(p.ConnectionsFile, []byte(bad), 0o600)
		if _, err := Selections(p); err == nil || len(CodexBarActive(p)) != 0 {
			t.Errorf("%s: accepted", bad)
		}
	}
	r := Read(p, time.Now())
	if s := r.Sources[len(r.Sources)-1]; s.Source != "connections" || s.Status != "invalid" {
		t.Fatalf("sources = %+v", r.Sources)
	}
}

package quota

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// Hand-written from the official SDK schema, with no recorded account data.
const copilotQuota = `{"quotaSnapshots":{"premium_interactions":{"usedRequests":75,"entitlementRequests":300,"remainingPercentage":75,"resetDate":"2026-11-01T00:00:00Z"},"chat":{"entitlementRequests":-1}}}`

func TestCopilotHelperProcess(t *testing.T) {
	if os.Getenv("MODELPLAN_TEST_COPILOT_HELPER") != "1" {
		return
	}
	f, _ := os.OpenFile(os.Getenv("MODELPLAN_TEST_COPILOT_LOG"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
	defer f.Close()
	fmt.Fprintln(f, strings.Join(os.Args, " "))
	r := bufio.NewReader(os.Stdin)
	for {
		raw, err := readCopilotFrame(r)
		if err != nil {
			return
		}
		var req struct {
			ID     int            `json:"id"`
			Method string         `json:"method"`
			Params map[string]any `json:"params"`
		}
		if json.Unmarshal(raw, &req) != nil {
			os.Exit(2)
		}
		fmt.Fprintln(f, string(raw))
		if len(req.Params) != 0 {
			os.Exit(3)
		}
		result := `{"protocolVersion":3}`
		switch req.Method {
		case "connect":
		case "auth.getStatus":
			result = os.Getenv("MODELPLAN_TEST_COPILOT_AUTH_STATUS")
			if result == "" {
				result = `{"isAuthenticated":true,"authType":"user"}`
			}
		case "account.getQuota":
			result = copilotQuota
		default:
			os.Exit(4) // no session, login or inference may be requested
		}
		body := fmt.Sprintf(`{"jsonrpc":"2.0","id":%d,"result":%s}`, req.ID, result)
		fmt.Printf("Content-Length: %d\r\n\r\n%s", len(body), body)
	}
}

func fakeCopilot(t *testing.T) (string, string) {
	t.Helper()
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	bin, log := filepath.Join(dir, "copilot"), filepath.Join(dir, "calls")
	// The shell wrapper runs only this test binary; it never discovers a real CLI.
	script := "#!/bin/sh\nexec '" + strings.ReplaceAll(exe, "'", "'\\''") + "' -test.run=^TestCopilotHelperProcess$ -- \"$@\"\n"
	if err := os.WriteFile(bin, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_TEST_COPILOT_HELPER", "1")
	t.Setenv("MODELPLAN_TEST_COPILOT_LOG", log)
	return bin, log
}

func TestCopilotRuntimeOptInAndCache(t *testing.T) {
	isolateHome(t)
	bin, log := fakeCopilot(t)
	t.Setenv("MODELPLAN_COPILOT", bin)
	p := nativePaths(t)
	if NativeDue(p, now) {
		t.Fatal("runtime is off by default")
	}
	_ = RefreshNative(context.Background(), p, now)
	if _, err := os.Stat(log); !os.IsNotExist(err) {
		t.Fatal("runtime ran before opt-in")
	}
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "copilot", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if err := RefreshNative(context.Background(), p, now); err != nil {
		t.Fatal(err)
	}
	calls, _ := os.ReadFile(log)
	for _, s := range []string{"--headless --no-auto-update --stdio", `"method":"connect"`, `"method":"account.getQuota"`} {
		if !bytes.Contains(calls, []byte(s)) {
			t.Fatal(string(calls))
		}
	}
	if bytes.Contains(calls, []byte("session.")) {
		t.Fatal(string(calls))
	}
	r := Read(p, now)
	var a *Account
	for i := range r.Accounts {
		if r.Accounts[i].Source == "native:copilot" {
			a = &r.Accounts[i]
		}
	}
	if a == nil || a.Subscription != nil || len(a.Windows) != 2 {
		t.Fatalf("%+v", r)
	}
	w := a.Windows[0]
	if *w.UsedPercent != 25 || *w.Requests.Used != 75 || *w.Requests.Limit != 300 || w.ResetsAt == nil {
		t.Fatalf("%+v", w)
	}
	if NativeDue(p, now.Add(time.Minute)) {
		t.Fatal("cache must throttle refresh")
	}
	ss, _ := Selections(p)
	if len(ss) != 1 || ss[0].KeyEnv != "" || ss[0].Read == "" || len(ss[0].Hosts) == 0 || ss[0].SecretPolicy == "" {
		t.Fatalf("%+v", ss)
	}
	t.Setenv("MODELPLAN_NATIVE", "off")
	if NativeDue(p, now.Add(time.Hour)) {
		t.Fatal("off switch ignored")
	}
	t.Setenv("MODELPLAN_NATIVE", "")
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "copilot", Backend: BackendCodexBar, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	if got := CodexBarActive(p); len(got) != 1 || got[0] != "copilot" {
		t.Fatal(got)
	}
}

func TestCopilotPartialQuota(t *testing.T) {
	isolateHome(t)
	for _, tc := range []struct {
		raw  string
		used *float64
	}{
		{copilotQuota, ptr(25.0)},
		{`{"quotaSnapshots":{"premium_interactions":{"usedRequests":75,"entitlementRequests":300}}}`, ptr(25.0)},
		{`{"quotaSnapshots":{"premium_interactions":{"usedRequests":0,"entitlementRequests":0,"remainingPercentage":100}}}`, nil},
		{`{"quotaSnapshots":{"premium_interactions":{"entitlementRequests":300}}}`, nil},
		{`{"quotaSnapshots":{"premium_interactions":{"usedRequests":3,"entitlementRequests":-1,"remainingPercentage":100}}}`, nil},
		{`{"quotaSnapshots":{"premium_interactions":{"usedRequests":-2,"entitlementRequests":300}}}`, nil},
	} {
		e := parseCopilot(json.RawMessage(tc.raw), now)
		if e.Status != "ok" || len(e.Windows) < 1 {
			t.Fatalf("%s: %+v", tc.raw, e)
		}
		got := e.Windows[0].UsedPercent
		if (got == nil) != (tc.used == nil) || (got != nil && *got != *tc.used) {
			t.Fatalf("%s: %+v", tc.raw, e.Windows[0])
		}
	}
	for _, raw := range []string{`{}`, `null`, `{"quotaSnapshots":{"chat":{}}}`, `{"quotaSnapshots":{"premium_interactions":{"usedRequests":"bad"}}}`} {
		if e := parseCopilot(json.RawMessage(raw), now); e.Status != "error" {
			t.Fatalf("%+v", e)
		}
	}
}

func copilotFrame(raw string) string {
	return fmt.Sprintf("Content-Length: %d\r\n\r\n%s", len(raw), raw)
}
func TestCopilotProtocolFailuresAndLegacy(t *testing.T) {
	isolateHome(t)
	for _, raw := range []string{
		"Content-Length: 999999999\r\n\r\n", "Content-Length: -1\r\n\r\n", "\r\n", "Content-Length: 5\r\n\r\nx",
		copilotFrame(`{"id":1,"result":{"protocolVersion":999}}`),
		copilotFrame(`{"id":1,"error":{"code":-32000,"message":"secret token must never appear"}}`),
	} {
		_, err := copilotQuotaRPC(strings.NewReader(raw), &bytes.Buffer{})
		if err == nil || strings.Contains(err.Error(), "secret") {
			t.Fatalf("%q: %v", raw, err)
		}
	}
	raw := copilotFrame(`{"id":1,"error":{"code":-32601}}`) + copilotFrame(`{"id":2,"result":{"protocolVersion":3}}`) + copilotFrame(`{"method":"notification"}`) + copilotFrame(`{"id":3,"result":{"isAuthenticated":true,"authType":"user"}}`) + copilotFrame(`{"id":4,"result":`+copilotQuota+`}`)
	var calls bytes.Buffer
	if _, err := copilotQuotaRPC(strings.NewReader(raw), &calls); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(calls.String(), `"method":"ping"`) {
		t.Fatal(calls.String())
	}
}

func TestCopilotMissingRuntimeAndResetCounts(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_COPILOT", filepath.Join(t.TempDir(), "missing"))
	if e := fetchCopilot(context.Background(), nil, "local", "", now); e.Status != "error" || !strings.Contains(e.Error, "Open Copilot") {
		t.Fatalf("%+v", e)
	}
	e := parseCopilot(json.RawMessage(copilotQuota), now)
	a := Account{Source: "native:copilot", Windows: e.Windows}
	reset := *a.Windows[0].ResetsAt
	Evaluate(&a, reset.Add(time.Second))
	if a.Windows[0].Requests != nil {
		t.Fatal("expired counts exposed")
	}
	if a.Windows[0].ObservedRequests() == nil {
		t.Fatal("original reading lost for snapshot revision")
	}
}

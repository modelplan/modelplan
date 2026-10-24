package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const kiroUsage = `{"success":true,"data":{"planName":"KIRO PRO","billingCycleReset":"2026-11-01","usageBreakdowns":[
	{"resourceType":"CREDIT","displayName":"Credits","used":250,"limit":1000,"hasLimit":true},
	{"resourceType":"AGENTIC_REQUEST","displayName":"Agentic requests","percentage":40,"limit":500},
	{"resourceType":"OVERAGE","displayName":"Overage","used":3,"hasLimit":false}]}}`

// fakeKiro answers like `kiro-cli acp`: initialize, then _kiro/account/getUsage, and logs every
// method and its arguments.
func fakeKiro(t *testing.T, usage string) (bin, log string) {
	dir := t.TempDir()
	bin, log = filepath.Join(dir, "kiro-cli"), filepath.Join(dir, "calls")
	script := `#!/bin/sh
echo "args: $*" >> "` + log + `"
while IFS= read -r line; do
  m=$(printf '%s' "$line" | sed -n 's/.*"method":"\([^"]*\)".*/\1/p'); echo "$m" >> "` + log + `"
  case "$m" in
    initialize) echo '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":1}}' ;;
    _kiro/account/getUsage) printf '{"jsonrpc":"2.0","id":2,"result":%s}\n' '` + strings.ReplaceAll(usage, "\n", "") + `' ;;
  esac
done
`
	if err := os.WriteFile(bin, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return bin, log
}

func TestKiroUsageOverACP(t *testing.T) {
	isolateHome(t)
	bin, log := fakeKiro(t, kiroUsage)
	t.Setenv("MODELPLAN_KIRO", bin)
	p := nativePaths(t)
	if err := SetConnection(p.ConnectionsFile, QuotaSource{Provider: "kiro", Backend: BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	ss, _ := Selections(p)
	if len(ss) != 1 || ss[0].KeyEnv != "" || ss[0].Blocked != "" {
		t.Fatalf("selection = %+v", ss)
	}
	now := time.Now()
	if err := RefreshNative(context.Background(), p, now); err != nil {
		t.Fatal(err)
	}
	calls, _ := os.ReadFile(log)
	if got := strings.Fields(string(calls)); strings.Join(got, " ") != "args: acp --agent-engine v3 --auth-method cli initialize _kiro/account/getUsage" {
		t.Fatalf("calls = %v", got)
	}
	var a *Account
	r := Read(p, now)
	for i := range r.Accounts {
		if r.Accounts[i].Source == "native:kiro" {
			a = &r.Accounts[i]
		}
	}
	if a == nil || a.Plan != "KIRO PRO" || len(a.Windows) != 2 || a.Subscription != nil {
		t.Fatalf("report = %+v", r)
	}
	if w := a.Windows[0]; w.Kind != "monthly" || w.Limit != "Credits" || *w.UsedPercent != 25 || !w.ResetsAt.Equal(time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)) {
		t.Errorf("credits = %+v", w)
	}
	if w := a.Windows[1]; w.Limit != "Agentic requests" || *w.UsedPercent != 40 {
		t.Errorf("requests = %+v", w)
	}
}

func TestParseKiroFailures(t *testing.T) {
	isolateHome(t)
	now := time.Now()
	for raw, want := range map[string]string{
		`{"success":false,"message":"User is not authenticated"}`:                   "Kiro CLI is signed out (kiro-cli login)",
		`{"success":true,"data":{"usageBreakdowns":[{"used":1,"hasLimit":false}]}}`: "no limits reported",
		`"nope"`: "unreadable reply",
	} {
		if e := parseKiro(json.RawMessage(raw), now); e.Status != "error" || e.Error != want {
			t.Errorf("%s: %+v", raw, e)
		}
	}
	t.Setenv("MODELPLAN_KIRO", filepath.Join(t.TempDir(), "missing"))
	if e := fetchKiro(context.Background(), nil, "local", "", now); e.Error == "" {
		t.Fatal("a missing kiro-cli is an error")
	}
}

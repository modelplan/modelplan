package connections

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestDiagnose(t *testing.T) {
	for _, k := range []string{"MODELPLAN_CODEXBAR", "MODELPLAN_CODEX_ACCOUNT"} {
		t.Setenv(k, "")
	}
	t.Setenv("PATH", "/bin")
	dir := t.TempDir()
	cb := filepath.Join(dir, "codexbar.json")
	os.WriteFile(cb, []byte(`{"schemaVersion":1,"providers":["kiro","zai"]}`), 0o600)
	paths := map[string]bool{"/home/u/.codex": true, "/bin/kiro-cli": true, "/home/u/.local/share/opencode": true}
	looked := []string{}
	e := Env{Home: "/home/u", CodexHome: "/home/u/.codex", CodexBarFile: cb, Exists: func(p string) bool { looked = append(looked, p); return paths[p] }}
	t.Setenv("XDG_DATA_HOME", "")
	at := time.Date(2026, 10, 21, 9, 0, 0, 0, time.UTC)
	used := 20.0
	r := quota.Report{
		Accounts: []quota.Account{{Source: "codex", ObservedAt: at, Harness: &quota.Harness{Model: "m", ObservedAt: &at}, Windows: []quota.Window{{Kind: "five_hour", UsedPercent: &used}}},
			{Source: "codexbar:kiro", ObservedAt: at, Windows: []quota.Window{{Kind: "monthly", UsedPercent: &used}}}},
		Sources: []quota.SourceStatus{{Source: "claude-code", Status: "missing"}, {Source: "codex", Status: "ok"}, {Source: "codexbar:kiro", Status: "ok"}, {Source: "codexbar:zai", Status: "unavailable"}},
	}
	got := map[string]Connection{}
	for _, c := range Diagnose(e, r) {
		got[c.ID] = c
	}
	cx, cc, oc, kiro, zai, cur := got["codex"], got["claude-code"], got["opencode"], got["codexbar:kiro"], got["codexbar:zai"], got["codexbar:cursor"]
	if cx.Installed.Status != "yes" || cx.History.Status != "yes" || cx.Authorization.Via != "agent-owned-reader" || cx.Quota.Status != "yes" || cx.Quota.Binding != "unknown" || !cx.Quota.At.Equal(at) {
		t.Errorf("codex = %+v", cx)
	}
	if cc.Installed.Status != "no" || cc.History.Status != "no" || cc.History.Reason != "missing" || cc.Authorization.Status != "not-applicable" || cc.Quota.Status != "no" {
		t.Errorf("claude-code = %+v", cc)
	}
	if oc.Installed.Status != "yes" || oc.History.Reason != "no-session-reader" || oc.Support != "detected-only" {
		t.Errorf("opencode = %+v", oc)
	}
	if kiro.Installed.Status != "yes" || kiro.Support != "quota-only" || kiro.Authorization.Via != "codexbar" || kiro.Quota.Status != "yes" {
		t.Errorf("kiro = %+v", kiro)
	}
	if zai.Authorization.Status != "yes" || zai.Quota.Status != "no" || zai.Quota.Reason != "unavailable" || cur.Authorization.Reason != "not-enabled" {
		t.Errorf("zai = %+v, cursor = %+v", zai, cur)
	}
	for _, p := range looked {
		if strings.Contains(p, "auth") || strings.Contains(p, "credentials") || strings.Contains(p, "Keychain") {
			t.Errorf("looked at %s", p)
		}
	}

	t.Setenv("MODELPLAN_CODEXBAR", "off")
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	for _, c := range Diagnose(e, r) {
		if (c.ID == "codex" || strings.HasPrefix(c.ID, "codexbar:")) && c.Authorization.Status != "off" {
			t.Errorf("%s with its switch off: %+v", c.ID, c.Authorization)
		}
	}
	b, _ := json.Marshal(Diagnose(e, quota.Report{}))
	if !strings.Contains(string(b), `"id":"codex","kind":"agent"`) {
		t.Errorf("json = %s", b)
	}
}

// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// The real app-server, with no plugin hook and no CLI command, on a recent Claude Code session
// log: the cockpit reports the running session with its rate.
func TestAppServerObservesLiveSessionsItself(t *testing.T) {
	home := setupQueryHome(t)
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	project := filepath.Join(home, ".claude", "projects", "-synthetic-project")
	if err := os.MkdirAll(project, 0o700); err != nil {
		t.Fatal(err)
	}
	cwd := filepath.Join(home, "alpha")
	if err := os.MkdirAll(cwd, 0o700); err != nil {
		t.Fatal(err)
	}
	start := time.Now().UTC().Add(-20 * time.Second)
	stamp := func(s int) string { return start.Add(time.Duration(s) * time.Second).Format(time.RFC3339Nano) }
	lines := []string{fmt.Sprintf(`{"parentUuid":null,"isSidechain":false,"type":"user","cwd":%q,"message":{"role":"user","content":"a question"},"uuid":"u0","timestamp":%q}`, cwd, stamp(0))}
	for i := 0; i < 5; i++ {
		at := i*3 + 2
		lines = append(lines, fmt.Sprintf(`{"isSidechain":false,"type":"assistant","cwd":%q,"requestId":"req-%d","effort":"high","thinkingDurationMs":1000,"message":{"model":"synthetic-model","role":"assistant","content":[{"type":"thinking","thinking":"hmm"}],"stop_reason":"tool_use","usage":{"input_tokens":5,"output_tokens":100,"speed":""}},"timestamp":%q}`, cwd, i, stamp(at)))
		lines = append(lines, fmt.Sprintf(`{"isSidechain":false,"type":"user","cwd":%q,"message":{"role":"user","content":[{"tool_use_id":"x","type":"tool_result","content":"said"}]},"timestamp":%q}`, cwd, stamp(at+1)))
	}
	lines = append(lines, fmt.Sprintf(`{"isSidechain":false,"type":"assistant","cwd":%q,"requestId":"req-end","effort":"high","message":{"model":"synthetic-model","role":"assistant","content":[{"type":"text","text":"done"}],"stop_reason":"end_turn","usage":{"input_tokens":5,"output_tokens":100,"speed":""}},"timestamp":%q}`, cwd, stamp(18)))
	if err := os.WriteFile(filepath.Join(project, "session.jsonl"), []byte(strings.Join(lines, "\n")+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	c := startQueryBinaryCaps(t, binary, []string{"rows", "cockpit", "cockpitDetailsV1"})
	deadline := time.Now().Add(25 * time.Second)
	for {
		response := c.call("cockpit/query", map[string]any{})
		var result wire.Envelope[wire.CockpitData]
		if err := json.Unmarshal(response["result"], &result); err == nil && result.Data.Details != nil && len(result.Data.Details.Sessions) > 0 {
			session := result.Data.Details.Sessions[0]
			if session.Source != "claude-code" {
				t.Fatalf("session = %+v", session)
			}
			if session.Rate == nil {
				t.Fatalf("running session without a rate: %+v", session)
			}
			if session.ProjectLabel == nil {
				// The session list follows the live record by one observation.
				if time.Now().After(deadline) {
					t.Fatalf("running session without a project: %+v", session)
				}
				time.Sleep(200 * time.Millisecond)
				continue
			}
			if *session.ProjectLabel != "alpha" {
				t.Fatalf("project = %q", *session.ProjectLabel)
			}
			return
		}
		if time.Now().After(deadline) {
			t.Fatalf("no session reached the cockpit: %s %s", response["result"], response["error"])
		}
		time.Sleep(200 * time.Millisecond)
	}
}

// The real app-server, with no plugin hook, on a Claude Code turn waiting for a tool: the signed-in
// account's row carries verified activity, which is what lights the flames in the app.
func TestAppServerSessionActivityReachesTheAccountRow(t *testing.T) {
	home := setupQueryHome(t)
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	if err := os.WriteFile(filepath.Join(home, ".claude.json"), []byte(`{"oauthAccount":{"accountUuid":"synthetic-account-001","organizationUuid":"synthetic-org-001"}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	status := exec.Command(binary, "statusline")
	status.Stdin = strings.NewReader(fmt.Sprintf(`{"session_id":"s","model":{"id":"claude-opus-5-5"},"rate_limits":{"five_hour":{"used_percentage":30,"resets_at":%d}}}`, time.Now().Add(time.Hour).Unix()))
	if raw, err := status.CombinedOutput(); err != nil {
		t.Fatalf("statusline: %v %s", err, raw)
	}
	project := filepath.Join(home, ".claude", "projects", "-synthetic-project")
	if err := os.MkdirAll(project, 0o700); err != nil {
		t.Fatal(err)
	}
	at := time.Now().UTC().Format(time.RFC3339Nano) // after the grant: older records stay unbound
	log := fmt.Sprintf(`{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"a question"},"timestamp":%q}
{"isSidechain":false,"type":"assistant","requestId":"req-1","message":{"model":"claude-opus-5-5","stop_reason":"tool_use","usage":{"output_tokens":20}},"timestamp":%q}
`, at, at)
	if err := os.WriteFile(filepath.Join(project, "session.jsonl"), []byte(log), 0o600); err != nil {
		t.Fatal(err)
	}
	c := startQueryBinaryCaps(t, binary, []string{"rows"})
	deadline := time.Now().Add(25 * time.Second)
	var last json.RawMessage
	for time.Now().Before(deadline) {
		response := c.call("rows/subscribe", map[string]any{})
		last = response["result"]
		var snapshot wire.Envelope[wire.RowsSnapshot]
		if err := json.Unmarshal(last, &snapshot); err != nil {
			t.Fatal(err)
		}
		for _, row := range snapshot.Data.Projection.Rows {
			for _, account := range row.Accounts {
				if row.ID == "claude" && len(account.Activity) > 0 {
					activity := account.Activity[0]
					if !activity.BindingVerified || string(activity.Phase) != "tool" || account.SubscriptionRef == nil || activity.SubscriptionRef != *account.SubscriptionRef {
						t.Fatalf("activity = %+v", activity)
					}
					return
				}
			}
		}
		time.Sleep(200 * time.Millisecond)
	}
	t.Fatalf("no activity reached the Claude row: %s", last)
}

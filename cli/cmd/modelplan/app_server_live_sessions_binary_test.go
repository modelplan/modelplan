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
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
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
	// Its own repository: CI's temporary directory is inside the checkout, and a label names the repository.
	cwd := filepath.Join(home, "alpha")
	if err := os.MkdirAll(filepath.Join(cwd, ".git"), 0o700); err != nil {
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
	waitForActivity(t, binary, "claude", "tool")
}

// waitForActivity starts the real app-server and waits for verified activity on that tool's account.
func waitForActivity(t *testing.T, binary, tool, phase string) {
	t.Helper()
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
				if row.ID == tool && len(account.Activity) > 0 {
					activity := account.Activity[0]
					if !activity.BindingVerified || string(activity.Phase) != phase || account.SubscriptionRef == nil || activity.SubscriptionRef != *account.SubscriptionRef {
						t.Fatalf("activity = %+v", activity)
					}
					return
				}
			}
		}
		time.Sleep(200 * time.Millisecond)
	}
	t.Fatalf("no activity reached the %s row: %s", tool, last)
}

func buildObserverBinary(t *testing.T) string {
	t.Helper()
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	return binary
}

func writeObserved(t *testing.T, path string, value any) {
	t.Helper()
	raw, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, raw, 0o600); err != nil {
		t.Fatal(err)
	}
}

// Codex: the recorded account reading plus a rollout waiting for a tool.
func TestAppServerCodexActivityReachesTheAccountRow(t *testing.T) {
	home := setupQueryHome(t)
	binary := buildObserverBinary(t)
	now := time.Now().UTC()
	state, _ := consent.Current()
	used := 30.0
	writeObserved(t, filepath.Join(home, "cache", "observed", "codex-account.json"), map[string]any{
		"admission": state.CaptureStamp(consent.ScopeCodexRuntimeUsage), "schemaVersion": 1, "observedAt": now, "status": "ok",
		"subscriptionRef": "0123456789abcdef",
		"windows":         []map[string]any{{"kind": "five_hour", "windowMinutes": 300, "usedPercent": used, "resetsAt": now.Add(time.Hour), "observedAt": now}},
	})
	rollout := filepath.Join(home, ".codex", "sessions", "2026", "11", "07", "rollout-synthetic.jsonl")
	if err := os.MkdirAll(filepath.Dir(rollout), 0o700); err != nil {
		t.Fatal(err)
	}
	at := time.Now().UTC().Format(time.RFC3339Nano)
	lines := fmt.Sprintf(`{"timestamp":%[1]q,"type":"event_msg","payload":{"type":"task_started"}}
{"timestamp":%[1]q,"type":"turn_context","payload":{"model":"gpt-5.5","effort":"high"}}
{"timestamp":%[1]q,"type":"response_item","payload":{"type":"function_call"}}
`, at)
	if err := os.WriteFile(rollout, []byte(lines), 0o600); err != nil {
		t.Fatal(err)
	}
	waitForActivity(t, binary, "codex", "tool")
}

// ZCode: its ledger has no account, so a turn binds to the configured key's recorded reading.
func TestAppServerZCodeActivityReachesTheAccountRow(t *testing.T) {
	home := setupQueryHome(t)
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	providers := filepath.Join(home, ".zcode", "v2", "provider_config.json")
	if err := os.MkdirAll(filepath.Dir(providers), 0o700); err != nil {
		t.Fatal(err)
	}
	config := `{"schemaVersion":1,"config":{"providerConfigRules":{"providerRules":[{"providerId":"glm-plan","templateId":"zai-api","enabled":true,"config":{"access":{"type":"zhipu-coding-plan-api-key","apiKey":"synthetic-canary"}}}]},"modelConfigRules":{"providerModelRules":[],"manualProviderModelRules":[]},"defaultModelSelection":{"providerId":"glm-plan","modelId":"glm-5"}}}`
	if err := os.WriteFile(providers, []byte(config), 0o600); err != nil {
		t.Fatal(err)
	}
	binary := buildObserverBinary(t)
	cache := filepath.Join(home, "cache")
	grant, ok := quota.ProductionPathsWithAdmission(cache, version, consent.Capture()).ReaderAccessGrant("zai")
	if !ok || grant.ConfigSource == nil {
		t.Skip("ZCode route not admitted by this profile")
	}
	now := time.Now().UTC()
	used := 25.0
	good := map[string]any{"admission": grant.Admission, "provider": "zai", "source": "api", "status": "ok", "observedAt": now, "subscriptionRef": "fedcba9876543210",
		"windows": []map[string]any{{"kind": "five_hour", "windowMinutes": 300, "usedPercent": used, "resetsAt": now.Add(time.Hour), "observedAt": now}}}
	writeObserved(t, filepath.Join(cache, "observed", "zai-config-v1.json"), map[string]any{"schemaVersion": 1, "attemptAt": now, "nextAt": now.Add(time.Hour), "availability": "ok",
		"loginGeneration": grant.Generation, "goodGeneration": grant.Generation, "lastGood": good})
	writeObserved(t, filepath.Join(cache, "observed", "native.json"), map[string]any{"schemaVersion": 1, "observedAt": now, "providers": []any{good}})
	log := filepath.Join(home, ".zcode", "cli", "log", "synthetic.jsonl")
	if err := os.MkdirAll(filepath.Dir(log), 0o700); err != nil {
		t.Fatal(err)
	}
	at := time.Now().UTC().Format(time.RFC3339Nano)
	if err := os.WriteFile(log, []byte(fmt.Sprintf(`{"timestamp":%q,"event":"turn.started","sessionId":"synthetic","turnId":"a"}`+"\n", at)), 0o600); err != nil {
		t.Fatal(err)
	}
	waitForActivity(t, binary, "zai", "model")
}

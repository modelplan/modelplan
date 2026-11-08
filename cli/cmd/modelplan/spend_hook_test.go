package main

import (
	"bytes"
	"encoding/json"
	"strings"
	"testing"
	"time"
)

// spawn runs the PreToolUse hook as the plugins do when a thread spawns a subagent and returns
// what the user sees and what the model gets.
func (h quotaHookTest) spawn(thread, agentID, model string, now time.Time) (user, modelText string) {
	h.t.Helper()
	tool := map[string]any{"description": "review", "prompt": "look"}
	if model != "" {
		tool["model"] = model
	}
	in := map[string]any{"session_id": thread, "hook_event_name": "PreToolUse", "tool_name": "Agent", "tool_input": tool}
	if agentID != "" {
		in["agent_id"] = agentID
	}
	var out bytes.Buffer
	if code := adviseHookAt(bytes.NewReader(publicationJSON(h.t, in)), &out, h.style, h.st, nil, common{offline: true}, h.harness, "user-only", "setup notice", now); code != 0 {
		h.t.Fatalf("hook exit %d", code)
	}
	if out.Len() == 0 {
		return "", ""
	}
	var result map[string]any
	if err := json.Unmarshal(out.Bytes(), &result); err != nil {
		h.t.Fatalf("hook output %s: %v", out.String(), err)
	}
	hook, _ := result["hookSpecificOutput"].(map[string]any)
	if len(result) != 2 || hook["hookEventName"] != "PreToolUse" || len(hook) != 2 {
		// Only a message and context: no permission decision, no changed input.
		h.t.Fatalf("spend output: %s", out.String())
	}
	user, _ = result["systemMessage"].(string)
	modelText, _ = hook["additionalContext"].(string)
	if strings.Contains(user+modelText, "user-only") || strings.Contains(user+modelText, "setup notice") {
		h.t.Fatalf("prompt-only text in the spend warning: %s", out.String())
	}
	return user, modelText
}

func TestSpendWarningOnSubagentSpawn(t *testing.T) {
	for _, harness := range []string{"claude-code", "codex"} {
		t.Run(harness, func(t *testing.T) {
			h := newQuotaHookTest(t, harness, "en")
			now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
			resetW := now.Add(3 * time.Hour)
			h.reading(harness, now, hookWindow("weekly", 40, resetW))
			if u, m := h.spawn("thread", "", "", now); u != "" || m != "" {
				t.Fatalf("roomy quota warned: %q %q", u, m)
			}
			h.reading(harness, now, hookWindow("weekly", 8, resetW))
			// Inside a subagent nothing is said, and nothing is marked.
			if u, m := h.spawn("thread", "agent-1", "", now); u != "" || m != "" {
				t.Fatalf("subagent warned: %q %q", u, m)
			}
			want := "Spawning subagents with low quota: Weekly quota: 8% left, resets in 3h."
			u, m := h.spawn("thread", "", "", now)
			if u != want || !strings.HasPrefix(m, want) {
				t.Fatalf("warning:\nuser  %q\nmodel %q", u, m)
			}
			// Ten more spawns in the same cycle: no repeat.
			for i := 0; i < 10; i++ {
				if u, m := h.spawn("thread", "", "", now); u != "" || m != "" {
					t.Fatalf("repeat %d: %q %q", i, u, m)
				}
			}
			// The prompt does not tell the same level again.
			if got := h.prompt("thread", now); got != "" {
				t.Fatalf("prompt repeated the spend warning: %s", got)
			}
			// A lower level is a new warning.
			h.reading(harness, now, hookWindow("weekly", 4, resetW))
			if u, _ := h.spawn("thread", "", "", now); !strings.Contains(u, "4% left") {
				t.Fatalf("5%% warning: %q", u)
			}
			// A stale reading says nothing.
			later := now.Add(61 * time.Minute)
			h.reading(harness, now, hookWindow("weekly", 2, later.Add(time.Hour)))
			if u, m := h.spawn("thread-2", "", "", later); u != "" || m != "" {
				t.Fatalf("stale reading warned: %q %q", u, m)
			}
			// Off with the automatic hints.
			t.Setenv("MODELPLAN_TASK_BRIEF", "off")
			h.reading(harness, now, hookWindow("weekly", 8, resetW))
			if u, m := h.spawn("thread-3", "", "", now); u != "" || m != "" {
				t.Fatalf("hints off: %q %q", u, m)
			}
		})
	}
}

func TestSpendWarningCapPerThread(t *testing.T) {
	h := newQuotaHookTest(t, "codex", "zh")
	now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
	sent := 0
	// Each new cycle may warn again, up to three times per thread.
	for i := 0; i < 5; i++ {
		reset := now.Add(time.Duration(i+1) * 24 * time.Hour)
		h.reading("codex", now, hookWindow("weekly", 15, reset))
		if u, _ := h.spawn("thread", "", "", now); u != "" {
			if !strings.HasPrefix(u, "额度偏低时派子代理：每周额度：剩余15%") {
				t.Fatalf("zh warning: %q", u)
			}
			sent++
		}
	}
	if sent != 3 {
		t.Fatalf("sent %d spend warnings, want 3", sent)
	}
}

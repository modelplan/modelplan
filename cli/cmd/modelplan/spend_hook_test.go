package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
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
			want := "Quota is tight; keep an eye on usage when spawning subagents. Weekly quota: 8% left, resets in 3h."
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
			if !strings.HasPrefix(u, "额度偏紧，派子代理时可以留意一下用量。每周额度：剩余15%") {
				t.Fatalf("zh warning: %q", u)
			}
			sent++
		}
	}
	if sent != 3 {
		t.Fatalf("sent %d spend warnings, want 3", sent)
	}
}

// Claude Code runs the hooks of spawns started in one turn in parallel: they warn once between them.
func TestSpendWarningParallelSpawnsWarnOnce(t *testing.T) {
	h := newQuotaHookTest(t, "claude-code", "en")
	now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
	h.reading("claude-code", now, hookWindow("weekly", 8, now.Add(3*time.Hour)))
	var wg sync.WaitGroup
	var warned atomic.Int32
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if u, _ := h.spawn("thread", "", "", now); u != "" {
				warned.Add(1)
			}
		}()
	}
	wg.Wait()
	if n := warned.Load(); n != 1 {
		t.Fatalf("%d of 10 parallel spawns warned, want 1", n)
	}
}

// A Codex subagent is a thread of its own; its hook input names no agent, its log does.
func TestSpendWarningSilentInCodexSubagentThread(t *testing.T) {
	h := newQuotaHookTest(t, "codex", "en")
	codexHome := t.TempDir()
	t.Setenv("CODEX_HOME", codexHome)
	now := time.Date(2026, 10, 24, 12, 0, 0, 0, time.UTC)
	h.reading("codex", now, hookWindow("weekly", 8, now.Add(3*time.Hour)))
	day := filepath.Join(codexHome, "sessions", "2026", "10", "24")
	if err := os.MkdirAll(day, 0o700); err != nil {
		t.Fatal(err)
	}
	thread := "019a0000-0000-7000-8000-00000000c41d"
	meta := `{"type":"session_meta","payload":{"id":"` + thread + `","source":{"subagent":"review"}}}` + "\n"
	if err := os.WriteFile(filepath.Join(day, "rollout-2026-10-24T11-59-00-"+thread+".jsonl"), []byte(meta), 0o600); err != nil {
		t.Fatal(err)
	}
	if u, m := h.spawn(thread, "", "", now); u != "" || m != "" {
		t.Fatalf("Codex subagent thread warned: %q %q", u, m)
	}
	if u, _ := h.spawn("019a0000-0000-7000-8000-0000000000aa", "", "", now); u == "" {
		t.Fatal("the user's own thread (no log found) was not warned")
	}
}

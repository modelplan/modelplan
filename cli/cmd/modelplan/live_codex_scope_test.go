// SPDX-License-Identifier: MIT
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// Scenario C-09: a profile that allowed only Codex local history (the walkthrough seed: consent
// codex.local_history, runtime and Gemini, no Claude Code scope) still turns a live Codex rollout
// into a live record in perf.json within one app-server refresh. Before, observeLive required the
// Claude Code local scope too, so no tool's live records were ever written.
func TestLiveCodexRolloutReachesLedgerWithoutClaudeScope(t *testing.T) {
	home := setupQueryHome(t)
	codex := filepath.Join(home, ".codex")
	t.Setenv("CODEX_HOME", codex)
	t.Setenv("CLAUDE_CONFIG_DIR", filepath.Join(home, ".claude"))
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		s.RequireConsent = true
		s.Scopes = map[string]consent.Record{
			consent.ScopeCodexLocalHistory: {Allowed: true, ConsentTextVersion: consent.TextVersion, At: now.Add(-time.Hour)},
		}
		s.Tools = map[string]consent.Record{}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if consent.Allowed("claude", consent.Local) || !consent.Allowed("codex", consent.Local) {
		t.Fatal("fixture must allow Codex local history only")
	}
	dir := filepath.Join(codex, "sessions", now.Format("2006"), now.Format("01"), now.Format("02"))
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	line := func(s float64, kind, payload string) string {
		return fmt.Sprintf(`{"timestamp":%q,"type":%q,"payload":%s}`+"\n", now.Add(-time.Duration(s*float64(time.Second))).Format(time.RFC3339Nano), kind, payload)
	}
	rollout := line(40, "session_meta", `{"id":"live-1","source":"cli"}`) +
		line(40, "event_msg", `{"type":"task_started","turn_id":"1"}`) +
		line(39.9, "turn_context", `{"model":"gpt-6-astra","effort":"high"}`) +
		line(30, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"output_tokens":300}}}`)
	if err := os.WriteFile(filepath.Join(dir, "rollout-live-1.jsonl"), []byte(rollout), 0o600); err != nil {
		t.Fatal(err)
	}
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	observeForApp(st)(now)
	perf, ok := speed.LoadPerf(st.Dir)
	if !ok || len(perf.Live) != 1 {
		t.Fatalf("one refresh must record the live Codex session: ok=%v live=%+v", ok, perf.Live)
	}
	if r := perf.Live[0]; r.Source != "codex" || r.Model != "gpt-6-astra" || !r.Running {
		t.Fatalf("live record = %+v", r)
	}
}

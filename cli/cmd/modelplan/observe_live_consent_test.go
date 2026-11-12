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
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// Owner build 13: a Codex-only first run (no Claude Code grant) still records the running Codex session, so the
// cockpit's record strip, fader lights and bells have something to show. Claude's logs stay unread without its grant.
func TestObserveLiveRecordsCodexWithoutClaudeConsent(t *testing.T) {
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "cache"))
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("CLAUDE_CONFIG_DIR", filepath.Join(home, "claude"))
	granted := time.Now().UTC().Add(-time.Hour)
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		if err := consent.Set(s, "codex", true, "native:codex", "native", granted); err != nil {
			return err
		}
		// After first run every scope needs a decision; Claude Code was not chosen.
		s.RequireConsent = true
		s.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if consent.Allowed("claude", consent.Local) || !consent.Allowed("codex", consent.Local) {
		t.Fatal("fixture: want Codex-only local consent")
	}
	now := time.Now().UTC().Truncate(time.Second)
	line := func(at time.Time, kind, payload string) string {
		return fmt.Sprintf(`{"timestamp":%q,"type":%q,"payload":%s}`, at.Format(time.RFC3339Nano), kind, payload)
	}
	write := func(path string, lines ...string) {
		t.Helper()
		if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
			t.Fatal(err)
		}
		body := ""
		for _, l := range lines {
			body += l + "\n"
		}
		if err := os.WriteFile(path, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	codexHome := filepath.Join(home, "codex")
	write(filepath.Join(codexHome, "sessions", "2026", "11", "08", "rollout-synthetic.jsonl"),
		line(now.Add(-20*time.Second), "session_meta", `{"id":"SYNTHETIC","source":"cli"}`),
		line(now.Add(-20*time.Second), "event_msg", `{"type":"task_started"}`),
		line(now.Add(-10*time.Second), "turn_context", `{"model":"gpt-6.1-sol","effort":"high"}`))
	// A Claude log is present but must stay unread without the Claude grant.
	write(filepath.Join(home, "claude", "projects", "p", "s.jsonl"), `{"type":"user","timestamp":"`+now.Add(-5*time.Second).Format(time.RFC3339Nano)+`","message":{"role":"user","content":"x"}}`)
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	observeLiveLogs(st, codexHome, nil, now)
	ledger, ok := speed.LoadPerf(st.Dir)
	if !ok {
		t.Fatal("no performance ledger written")
	}
	var sources []string
	for _, r := range ledger.Live {
		sources = append(sources, r.Source+":"+r.Model)
	}
	if len(sources) != 1 || sources[0] != "codex:gpt-6.1-sol" {
		t.Fatalf("live records %v, want the one Codex session", sources)
	}
}

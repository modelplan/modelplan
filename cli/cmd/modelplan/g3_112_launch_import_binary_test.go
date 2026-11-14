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
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// writeHistoryLogs: one Claude Code turn and one Codex turn two days ago, in the synthetic home.
func writeHistoryLogs(t *testing.T, home string) {
	t.Helper()
	at := func(d time.Duration) string {
		return time.Now().Add(-48*time.Hour + d).UTC().Format("2006-01-02T15:04:05.000Z")
	}
	claude := filepath.Join(home, ".claude", "projects", "P")
	codex := filepath.Join(home, ".codex", "sessions", "2026", "11", "01")
	for _, dir := range []string{claude, codex} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	cl := []string{
		fmt.Sprintf(`{"type":"user","message":{"role":"user","content":"q"},"timestamp":%q}`, at(0)),
		fmt.Sprintf(`{"type":"assistant","requestId":"r1","message":{"model":"m","content":[{"type":"text","text":"a"}],"stop_reason":"end_turn","usage":{"input_tokens":3,"output_tokens":200}},"timestamp":%q}`, at(3*time.Second)),
	}
	cx := func(d time.Duration, kind, payload string) string {
		return fmt.Sprintf(`{"timestamp":%q,"type":%q,"payload":%s}`, at(d), kind, payload)
	}
	co := []string{
		cx(0, "event_msg", `{"type":"task_started"}`),
		cx(0, "turn_context", `{"model":"codex-fixture","effort":"high"}`),
		cx(2*time.Second, "event_msg", fmt.Sprintf(`{"type":"item_completed","item":{"type":"AgentMessage","id":"i"},"started_at_ms":%d}`, time.Now().Add(-48*time.Hour+time.Second).UnixMilli())),
		cx(2*time.Second, "event_msg", `{"type":"token_count","info":{"last_token_usage":{"output_tokens":300}}}`),
		cx(3*time.Second, "event_msg", `{"type":"task_complete","duration_ms":3000}`),
	}
	if err := os.WriteFile(filepath.Join(claude, "s.jsonl"), []byte(strings.Join(cl, "\n")+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(codex, "rollout-a.jsonl"), []byte(strings.Join(co, "\n")+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
}

func grantHistoryScopes(t *testing.T, cache string, allow, deny []string) {
	t.Helper()
	cstate, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) { return consent.Record{}, nil }, Cleanup: func(scope string, forget bool) error {
		return quota.EraseScope(quota.Paths{Cache: cache}, scope, forget)
	}}
	if _, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: fmt.Sprint(time.Now().UnixNano()), ExpectStoreEpoch: cstate.StoreEpoch, ExpectGeneration: cstate.Generation, ConsentTextVersion: consent.TextVersion, Allow: allow, Deny: deny}, hooks); err != nil {
		t.Fatal(err)
	}
}

func coverageOf(cache string) map[string]bool {
	l, _ := speed.LoadImported(cache)
	out := map[string]bool{}
	for source := range l.Coverage {
		out[source] = true
	}
	return out
}

// G3-112 and the GLMREV findings through the real executable:
//   - a grant recorded before launch starts nothing (the Swift RealHistoryImportTests flow);
//   - glm-967-1: an owed launch import reads only the recorded grant, never the undecided source;
//   - glm-967-3: a source cleared and granted again in the running engine is imported again.
func TestOwedHistoryImportThroughTheRealEngine(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-ldflags", "-X main.version=1.0.0", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, raw)
	}
	t.Run("grant before launch starts nothing", func(t *testing.T) {
		home := setupQueryHome(t)
		writeHistoryLogs(t, home)
		grantHistoryScopes(t, filepath.Join(home, "cache"), []string{consent.ScopeClaudeLocalHistory}, nil)
		p := startQueryBinary(t, binary)
		time.Sleep(owedLaunchDelay + time.Second) // past the launch retry's delay
		if st := importStatus(t, p); st.Phase != wire.ImportIdle || st.FirstRunDone {
			t.Fatalf("a grant recorded before launch started an import: %+v", st)
		}
	})
	t.Run("owed launch reads only the recorded grant", func(t *testing.T) {
		home := setupQueryHome(t)
		writeHistoryLogs(t, home)
		cache := filepath.Join(home, "cache")
		grantHistoryScopes(t, cache, []string{consent.ScopeClaudeLocalHistory}, nil) // codex left undecided
		if err := speed.MarkAutoRequested(cache, time.Now()); err != nil {
			t.Fatal(err)
		}
		p := startQueryBinary(t, binary)
		st := waitImport(t, p, func(st wire.HistoryImportStatus) bool { return st.Phase == wire.ImportDone })
		if cov := coverageOf(cache); !cov["claude-code"] || cov["codex"] {
			t.Fatalf("owed launch import coverage %v (status %+v): the undecided Codex history was read", cov, st)
		}
	})
	t.Run("cleared then granted again is imported again", func(t *testing.T) {
		home := setupQueryHome(t)
		writeHistoryLogs(t, home)
		cache := filepath.Join(home, "cache")
		grantHistoryScopes(t, cache, []string{consent.ScopeClaudeLocalHistory, consent.ScopeCodexLocalHistory}, nil)
		var out, errb strings.Builder
		if code := run([]string{"history", "--import", "--first-run", "--json", "--offline"}, nil, &out, &errb); code != 0 {
			t.Fatal(code, errb.String())
		}
		if cov := coverageOf(cache); !cov["claude-code"] || !cov["codex"] {
			t.Fatalf("first run coverage %v: %s", cov, out.String())
		}
		grantHistoryScopes(t, cache, nil, []string{consent.ScopeCodexLocalHistory}) // clears Codex's imported history
		if cov := coverageOf(cache); cov["codex"] {
			t.Fatal("revoke kept Codex coverage")
		}
		p := startQueryBinary(t, binary)
		var facts wire.Envelope[wire.ConsentFacts]
		if json.Unmarshal(p.call("consent/get", map[string]any{})["result"], &facts) != nil {
			t.Fatal("consent read failed")
		}
		grant := p.call("consent/grant", wire.ConsentGrantParams{RequestID: "regrant", ExpectStoreEpoch: facts.StoreEpoch, ExpectGeneration: facts.ConsentGeneration, TextVersion: consent.TextVersion, Allow: []string{consent.ScopeCodexLocalHistory}, Deny: []string{}})
		if _, bad := grant["error"]; bad {
			t.Fatalf("grant rejected: %s", grant["error"])
		}
		waitImport(t, p, func(wire.HistoryImportStatus) bool { return coverageOf(cache)["codex"] })
	})
}

func importStatus(t *testing.T, p *queryBinary) wire.HistoryImportStatus {
	t.Helper()
	var env wire.Envelope[wire.HistoryImportStatus]
	msg := p.call("history/import_status", map[string]any{})
	if json.Unmarshal(msg["result"], &env) != nil {
		t.Fatalf("status: %s", msg["error"])
	}
	return env.Data
}

func waitImport(t *testing.T, p *queryBinary, done func(wire.HistoryImportStatus) bool) wire.HistoryImportStatus {
	t.Helper()
	var st wire.HistoryImportStatus
	for i := 0; i < 1000; i++ { // the retry waits owedLaunchDelay / owedGrantDelay first
		if st = importStatus(t, p); done(st) {
			return st
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatalf("import never finished: %+v", st)
	return st
}

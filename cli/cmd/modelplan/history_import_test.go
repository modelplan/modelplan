// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestHistoryImportCommand(t *testing.T) {
	consentFixtureHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	cache := t.TempDir()
	t.Setenv("MODELPLAN_CACHE", cache)
	cstate, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) { return consent.Record{}, nil }, Cleanup: func(scope string, forget bool) error {
		return quota.EraseScope(quota.Paths{Cache: cache}, scope, forget)
	}}
	if _, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "allow", ExpectStoreEpoch: cstate.StoreEpoch, ExpectGeneration: cstate.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeClaudeLocalHistory}}, hooks); err != nil {
		t.Fatal(err)
	}
	claude := t.TempDir()
	t.Setenv("CLAUDE_CONFIG_DIR", claude)
	t.Setenv("CODEX_HOME", t.TempDir())
	dir := filepath.Join(claude, "projects", "CANARY-PROJECT-DIR")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	ts := func(d time.Duration) string { return time.Now().Add(d).UTC().Format("2006-01-02T15:04:05.000Z") }
	lines := []string{
		fmt.Sprintf(`{"type":"user","message":{"role":"user","content":"CANARY-PROMPT"},"timestamp":%q}`, ts(-48*time.Hour)),
		fmt.Sprintf(`{"type":"assistant","requestId":"CANARY-ID","effort":"high","message":{"model":"m","content":[{"type":"text","text":"CANARY-REPLY"}],"stop_reason":"end_turn","usage":{"input_tokens":3,"output_tokens":200}},"timestamp":%q}`, ts(-48*time.Hour+3*time.Second)),
	}
	if err := os.WriteFile(filepath.Join(dir, "CANARY-SESSION.jsonl"), []byte(strings.Join(lines, "\n")+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	var out, errb bytes.Buffer
	if code := run([]string{"history", "--import", "--days", "7", "--json", "--offline"}, nil, &out, &errb); code != 0 {
		t.Fatal(code, errb.String())
	}
	var got struct {
		Days    int `json:"days"`
		Sources []struct {
			Source, Status string
			Turns          int
		} `json:"sources"`
	}
	if err := json.Unmarshal(out.Bytes(), &got); err != nil || got.Days != 7 || len(got.Sources) != 2 || got.Sources[0].Status != "imported" || got.Sources[0].Turns != 1 {
		t.Fatalf("%s %v", out.String(), err)
	}
	st := &store.Store{Dir: cache}
	b, err := os.ReadFile(filepath.Join(st.Dir, "observed", "imported.json"))
	if err != nil || !strings.Contains(string(b), `"origin":"import"`) {
		t.Fatalf("%s %v", b, err)
	}
	for _, c := range []string{"CANARY", claude} {
		if strings.Contains(string(b), c) {
			t.Fatalf("ledger holds %q", c)
		}
	}
	// Revoking the tool's history grant erases its imported rows like every other ledger.
	if err := quota.EraseScope(quota.Paths{Cache: cache}, consent.ScopeClaudeLocalHistory, false); err != nil {
		t.Fatal(err)
	}
	b, _ = os.ReadFile(filepath.Join(st.Dir, "observed", "imported.json"))
	if strings.Contains(string(b), `"claude-code"`) && strings.Contains(string(b), `"origin"`) {
		t.Fatalf("revoke left imported rows: %s", b)
	}
	out.Reset()
	if code := run([]string{"history", "--remove-imported", "--json"}, nil, &out, &errb); code != 0 {
		t.Fatal(code, errb.String())
	}
	b, _ = os.ReadFile(filepath.Join(st.Dir, "observed", "imported.json"))
	if strings.Contains(string(b), `"origin"`) {
		t.Fatalf("rows left: %s", b)
	}
	for _, args := range [][]string{{"history", "--import", "--remove-imported"}, {"history", "--days", "5"}, {"plan", "--import"}} {
		if code := run(args, nil, &out, &errb); code != exitUsage {
			t.Fatalf("%v: %d", args, code)
		}
	}
}

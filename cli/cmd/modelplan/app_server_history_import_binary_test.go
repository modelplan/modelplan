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
)

// HIST-IMP-01 through the real executable: start, poll, remove, with canaries kept out of the ledger.
func TestHistoryImportMethodsRealBinary(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-ldflags", "-X main.version=1.0.0", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, raw)
	}
	home := setupQueryHome(t)
	dir := filepath.Join(home, ".claude", "projects", "CANARY-PROJECT-DIR")
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
	p := startQueryBinary(t, binary)
	current := p.call("consent/get", map[string]any{})
	var facts wire.Envelope[wire.ConsentFacts]
	if json.Unmarshal(current["result"], &facts) != nil {
		t.Fatal("consent read failed")
	}
	grant := p.call("consent/grant", wire.ConsentGrantParams{RequestID: "hist-imp", ExpectStoreEpoch: facts.StoreEpoch, ExpectGeneration: facts.ConsentGeneration, TextVersion: consent.TextVersion, Allow: []string{consent.ScopeClaudeLocalHistory}, Deny: []string{}})
	if _, ok := grant["error"]; ok {
		t.Fatalf("grant rejected: %s", grant["error"])
	}
	status := func(method string, params any) wire.HistoryImportStatus {
		t.Helper()
		msg := p.call(method, params)
		var env wire.Envelope[wire.HistoryImportStatus]
		if json.Unmarshal(msg["result"], &env) != nil {
			t.Fatalf("%s: %s", method, msg["error"])
		}
		return env.Data
	}
	if st := status("history/import_status", map[string]any{}); st.Phase != wire.ImportIdle || st.FirstRunDone {
		t.Fatalf("%+v", st)
	}
	status("history/import_start", map[string]any{"days": 30, "firstRun": true})
	var st wire.HistoryImportStatus
	for i := 0; i < 200; i++ {
		if st = status("history/import_status", map[string]any{}); st.Phase != wire.ImportRunning {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if st.Phase != wire.ImportDone || len(st.Sources) != 2 || st.Sources[0].Status != wire.ImportSourceImported || st.Sources[0].Turns != 1 || st.Sources[1].Source != "codex" {
		t.Fatalf("import did not finish cleanly: %+v", st)
	}
	st = status("history/import_status", map[string]any{})
	if !st.FirstRunDone || st.ImportedRows == 0 || len(st.Coverage) < 1 {
		t.Fatalf("%+v", st)
	}
	var ledger string
	_ = filepath.WalkDir(home, func(path string, d os.DirEntry, _ error) error {
		if d != nil && d.Name() == "imported.json" {
			b, _ := os.ReadFile(path)
			ledger = string(b)
		}
		return nil
	})
	if !strings.Contains(ledger, `"origin":"import"`) || strings.Contains(ledger, "CANARY") {
		t.Fatalf("ledger: %s", ledger)
	}
	if st = status("history/import_remove", map[string]any{}); st.ImportedRows != 0 || !st.FirstRunDone {
		t.Fatalf("%+v", st)
	}
}

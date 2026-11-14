// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"path/filepath"
	"testing"
)

// G3-112: Codex moves archived threads to <CODEX_HOME>/archived_sessions (flat rollout files). The
// importer reads them as well, so a user who archives threads still gets their past usage.
func TestImportReadsCodexArchivedSessions(t *testing.T) {
	f := newFixture(t)
	f.codexLog("rollout-live.jsonl", -2)
	p := f.codexLog("rollout-archived.jsonl", -6, -5)
	archived := filepath.Join(f.home, "archived_sessions", filepath.Base(p))
	os.MkdirAll(filepath.Dir(archived), 0o700)
	if err := os.Rename(p, archived); err != nil {
		t.Fatal(err)
	}
	os.Chtimes(archived, f.now, f.now)
	f.run(30, both())
	l, _ := LoadImported(f.cache)
	if r, _ := total(l, "codex"); r != 3 {
		t.Fatalf("codex requests %d, want 3 (live 1 + archived 2)", r)
	}
	// A second run counts nothing twice, even after the live thread is archived too.
	live := filepath.Join(f.home, "sessions", "2026", "10", "rollout-live.jsonl")
	os.Rename(live, filepath.Join(f.home, "archived_sessions", "rollout-live.jsonl"))
	f.run(30, both())
	l, _ = LoadImported(f.cache)
	if r, _ := total(l, "codex"); r != 3 {
		t.Fatalf("re-import after archiving counted %d, want 3", r)
	}
}

// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// G3-112: doctor lists the Codex and Claude Code history import next to the other history readers,
// so "is my past usage read" has an answer without opening the cockpit.
func TestDoctorListsCodexAndClaudeHistoryImport(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	home, _ := os.UserHomeDir()
	codexHome := filepath.Join(home, ".codex")
	t.Setenv("CODEX_HOME", codexHome)
	if err := os.MkdirAll(filepath.Join(codexHome, "sessions"), 0700); err != nil {
		t.Fatal(err)
	}
	productionConsent(t, "codex", true)
	cache := t.TempDir()
	at := time.Date(2026, 11, 14, 16, 0, 0, 0, time.UTC)
	through := at.Add(-30 * time.Minute)
	if err := os.MkdirAll(filepath.Join(cache, "observed"), 0700); err != nil {
		t.Fatal(err)
	}
	led := `{"schemaVersion":1,"autoRan":"2026-11-14T15:29:54Z","coverage":{"codex":{"from":"2026-10-15T00:00:00Z","through":"` + through.Format(time.RFC3339) + `"}},"rows":[{"source":"codex","day":"2026-11-10","origin":"import"}]}`
	if err := os.WriteFile(speed.ImportPath(cache), []byte(led), 0600); err != nil {
		t.Fatal(err)
	}
	rows := ReaderDiagnostics(ProductionPaths(cache, "1.0.0"), at)
	r := diagnosticRow(t, rows, "codex:history")
	if r.Detected != "yes" || r.Admitted != "yes" || r.Consent != "granted" || r.State != "ok" || r.Last != "1800s" {
		t.Fatalf("codex:history %+v", r)
	}
	c := diagnosticRow(t, rows, "claude:history")
	if c.Admitted == "yes" && c.State == "ok" {
		t.Fatalf("claude:history without any import reported ok: %+v", c)
	}
}

// glm-967-3: clearing one tool's history keeps the shared first-run markers, so the other tool is
// not imported again, and the cleared tool is owed an import as soon as it is granted again.
func TestHistoryScopeCleanupLeavesTheClearedSourceOwed(t *testing.T) {
	for _, forget := range []bool{false, true} {
		t.Run(map[bool]string{false: "revoke", true: "forget"}[forget], func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			t.Setenv("MODELPLAN_HISTORY", "")
			cache := t.TempDir()
			if err := os.MkdirAll(filepath.Join(cache, "observed"), 0700); err != nil {
				t.Fatal(err)
			}
			state := consent.Empty()
			state.StoreEpoch = "0123456789abcdef0123456789abcdef"
			for _, scope := range []string{consent.ScopeClaudeLocalHistory, consent.ScopeCodexLocalHistory} {
				state.Scopes[scope] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
			}
			adm := consent.NewAdmission(state, consent.Automatic)
			epoch := `{"storeEpoch":"0123456789abcdef0123456789abcdef","revokedGeneration":0}`
			span := `{"accountingVersion":1,"projectsVersion":1,"from":"2026-10-15T00:00:00Z","through":"2026-11-14T00:00:00Z","epoch":` + epoch
			b := []byte(`{"schemaVersion":1,"autoRan":"2026-11-14T15:29:54Z","coverage":{"codex":` + span + `,"archived":true},"claude-code":` + span + `}},"rows":[{"source":"codex","day":"2026-10-02"}]}`)
			if err := os.WriteFile(speed.ImportPath(cache), b, 0600); err != nil {
				t.Fatal(err)
			}
			if got := speed.OwedSources(cache, adm); len(got) != 0 {
				t.Fatalf("fixture: owed %v", got)
			}
			if err := EraseScope(Paths{Cache: cache}, consent.ScopeCodexLocalHistory, forget); err != nil {
				t.Fatal(err)
			}
			if speed.NeedsAutoImport(cache) {
				t.Fatal("clearing one tool re-armed the shared first-run import")
			}
			if got := speed.OwedSources(cache, adm); len(got) != 1 || got[0] != "codex" {
				t.Fatalf("re-granted codex owed %v, want [codex]", got)
			}
		})
	}
}

// G3-112: an admitted GLM key-file reader that has never read reports not_read, not stale; stale
// means an old reading exists.
func TestDoctorZaiNeverReadIsNotStale(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	home, _ := os.UserHomeDir()
	writeZCodeProviders(t, home, zcodeTemplateProvider)
	writeLegacyConsent(t, `"zai":{"allowed":true,`+legacyAt+`,"readerId":"native:zai","backend":"native"}`)
	cache := t.TempDir()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if g, ok := p.ReaderAccessGrant("zai"); !ok || g.ConfigSource == nil {
		t.Fatalf("fixture: ZCode route not admitted: %+v %v", g, ok)
	}
	r := diagnosticRow(t, ReaderDiagnostics(p, time.Now()), "zai")
	if r.Admitted != "yes" || r.State != "unavailable:not_read" || r.Last != "unknown" {
		t.Fatalf("never-read zai: %+v", r)
	}
}

// G3-117: a signed-in Cursor account on the free (or hobby) plan has no included-usage period. That
// is "no plan to read", not a changed schema.
func TestCursorFreePlanIsNoPlanNotSchemaChanged(t *testing.T) {
	for _, name := range []string{"Free", "Hobby"} {
		t.Run(name, func(t *testing.T) {
			p, token := cursorAdmittedPaths(t)
			mode, paths := "free-plan", []string{}
			cursorPeriodServer(t, token, &mode, &paths)
			if name == "Hobby" {
				mode = "hobby-plan"
			}
			_ = RefreshNative(context.Background(), p, cursorNow)
			s, _ := loadReaderState(p.Cache, "cursor")
			if len(s.Entries) != 1 || s.Entries[0].ErrorCode != "no_plan" {
				t.Fatalf("free Cursor plan: %+v", s.Entries)
			}
			if got := nativeDiagnosticState(s.Entries[0].Status, s.Entries[0].ErrorCode); got != "unavailable:reader_error:no_plan" {
				t.Fatal(got)
			}
		})
	}
}

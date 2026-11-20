// SPDX-License-Identifier: MIT
package speed

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// HIST-IMP-10 (D168): imported history keeps the project folder name per day, nothing above it.

const secretCwd = "/Users/alice-SECRET-HOME/clients/acme-SECRET-CLIENT/widgets"

// claudeLogIn writes a transcript whose prompts record the working directory cwd.
func (f *fixture) claudeLogIn(name, cwd string, offsets ...float64) {
	var lines []string
	for i, o := range offsets {
		pair := claudeTurnAt(o*dayS, fmt.Sprintf("%s-%s-%d", canaryID, name, i), "claude-fixture")
		pair[0] = strings.Replace(pair[0], `"type":"user"`, `"cwd":"`+cwd+`","type":"user"`, 1)
		lines = append(lines, pair...)
	}
	p := filepath.Join(f.claude, "projects", canaryPath, name)
	writeLines(f.t, p, lines...)
	os.Chtimes(p, f.now, f.now)
}

func projectOf(l ImportLedger, day, source, name string) (ImportProject, bool) {
	for _, p := range l.Projects {
		if p.Day == day && p.Source == source && p.Name == name {
			return p, true
		}
	}
	return ImportProject{}, false
}

func TestImportKeepsOnlyTheLastPathComponent(t *testing.T) {
	f := newFixture(t)
	f.claudeLogIn("a.jsonl", secretCwd, -3)
	f.codexLog("rollout-a.jsonl", -2)
	f.run(30, both())
	l, _ := LoadImported(f.cache)
	if _, ok := projectOf(l, day(t0.Add(-3*24*time.Hour)), "claude-code", "widgets"); !ok {
		t.Fatalf("folder name missing: %+v", l.Projects)
	}
	if _, ok := projectOf(l, day(t0.Add(-2*24*time.Hour)), "codex", "codex-proj"); !ok {
		t.Fatalf("codex folder name missing: %+v", l.Projects)
	}
	b, _ := os.ReadFile(ImportPath(f.cache))
	for _, c := range []string{"SECRET-HOME", "SECRET-CLIENT", "clients", "/Users", canaryParent, canaryPath, canaryPrompt, canaryID, ".jsonl"} {
		if strings.Contains(string(b), c) {
			t.Fatalf("ledger holds %q: %s", c, b)
		}
	}
}

func TestFolderNameRejectsWhatIsNotAFolder(t *testing.T) {
	for in, want := range map[string]string{
		secretCwd: "widgets", "/a/b/": "b", "/": "", "": "", "relative/dir": "", "/a/b\nc": "", "/a/\x00b": "",
	} {
		if got := FolderName(in); got != want {
			t.Fatalf("FolderName(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestImportSumsProjectsPerDay(t *testing.T) {
	f := newFixture(t)
	f.claudeLogIn("a.jsonl", secretCwd, -3, -2.9, -2)
	f.claudeLogIn("b.jsonl", "/x/other", -3)
	f.run(30, both())
	l, _ := LoadImported(f.cache)
	d3, d2 := day(t0.Add(-3*24*time.Hour)), day(t0.Add(-2*24*time.Hour))
	if p, ok := projectOf(l, d3, "claude-code", "widgets"); !ok || p.Turns != 2 || p.ObservedOutputTokens != 800 {
		t.Fatalf("widgets day -3: %+v", p)
	}
	if p, ok := projectOf(l, d2, "claude-code", "widgets"); !ok || p.Turns != 1 || p.ObservedOutputTokens != 400 {
		t.Fatalf("widgets day -2: %+v", p)
	}
	if p, ok := projectOf(l, d3, "claude-code", "other"); !ok || p.Turns != 1 {
		t.Fatalf("other: %+v", p)
	}
	if len(l.Projects) != 3 {
		t.Fatalf("one entry per day and project: %+v", l.Projects)
	}
	f.run(30, both()) // an import again adds nothing
	l2, _ := LoadImported(f.cache)
	if len(l2.Projects) != 3 {
		t.Fatalf("doubled: %+v", l2.Projects)
	}
}

func TestImportKeepsNoNamesWhenProjectLabelsAreOff(t *testing.T) {
	f := newFixture(t)
	f.claudeLogIn("a.jsonl", secretCwd, -3)
	if _, err := Import(context.Background(), f.cache, ImportOptions{Claude: &ImportRoot{Dir: f.claude}, Now: f.now, Admission: both(), NoProjectNames: true}); err != nil {
		t.Fatal(err)
	}
	l, _ := LoadImported(f.cache)
	if len(l.Projects) != 0 || len(l.Rows) == 0 || l.Coverage["claude-code"].ProjectsVersion != 1 {
		t.Fatalf("%+v", l)
	}
}

func TestRemoveImportedDeletesTheProjectNames(t *testing.T) {
	f := newFixture(t)
	f.claudeLogIn("a.jsonl", secretCwd, -3)
	if _, err := Import(context.Background(), f.cache, ImportOptions{Claude: &ImportRoot{Dir: f.claude}, Now: f.now, Admission: both(), Auto: true}); err != nil {
		t.Fatal(err)
	}
	if l, _ := LoadImported(f.cache); len(l.Projects) == 0 {
		t.Fatal("nothing to remove")
	}
	if err := RemoveImported(f.cache); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(ImportPath(f.cache)); strings.Contains(string(b), "widgets") {
		t.Fatalf("project name survived the removal: %s", b)
	}
	if l, _ := LoadImported(f.cache); len(l.Projects) != 0 {
		t.Fatalf("%+v", l.Projects)
	}
}

func TestTurningProjectLabelsOffDeletesImportedNamesNotRows(t *testing.T) {
	f := newFixture(t)
	f.claudeLogIn("a.jsonl", secretCwd, -3)
	f.run(30, both())
	if err := SetProjectLabels(filepath.Join(t.TempDir(), "labels.json"), f.cache, false); err != nil {
		t.Fatal(err)
	}
	l, _ := LoadImported(f.cache)
	if len(l.Projects) != 0 || len(l.Rows) == 0 {
		t.Fatalf("%+v", l)
	}
}

// An import made before project names were kept is read once more, within its granted span, and not
// again after that.
func TestImportRescansAnOlderImportOnce(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("old.jsonl", -3)
	f.claudeLogIn("a.jsonl", secretCwd, -2)
	adm := both()
	f.run(30, adm)
	// Make it look like an earlier build's import: no names, no projects version.
	l, _ := LoadImported(f.cache)
	rows := total2(l)
	span := l.Coverage["claude-code"]
	span.ProjectsVersion, l.Projects = 0, nil
	l.Coverage["claude-code"] = span
	at := f.now
	l.AutoRan = &at
	if err := writeImported(f.cache, l); err != nil {
		t.Fatal(err)
	}
	if owed := OwedSourcesAt(f.cache, *adm, f.now); len(owed) != 1 || owed[0] != "claude-code" {
		t.Fatalf("the rescan is owed once: %v", owed)
	}
	f.run(30, adm)
	l, _ = LoadImported(f.cache)
	if len(l.Projects) == 0 || l.Coverage["claude-code"].ProjectsVersion != 1 {
		t.Fatalf("not rescanned: %+v", l)
	}
	if got := total2(l); got != rows {
		t.Fatalf("rows changed by the rescan: %d != %d", got, rows)
	}
	if owed := OwedSourcesAt(f.cache, *adm, f.now); len(owed) != 0 {
		t.Fatalf("the rescan runs once: still owed %v", owed)
	}
	// A second run reads nothing: with the log gone, the names stay.
	os.RemoveAll(filepath.Join(f.claude, "projects"))
	f.run(30, adm)
	if l2, _ := LoadImported(f.cache); len(l2.Projects) != len(l.Projects) {
		t.Fatalf("rescanned twice: %+v", l2.Projects)
	}
}

func total2(l ImportLedger) (n int) {
	for _, r := range l.Rows {
		n += r.ObservedRequests
	}
	return
}

func TestImportedProjectsFeedTheRankingBeforeTheLiveDays(t *testing.T) {
	cache := t.TempDir()
	a := both()
	epoch := currentEpoch(*a, "claude-code")
	now := time.Date(2026, 11, 20, 12, 0, 0, 0, time.Local)
	imp := ImportLedger{SchemaVersion: 1, Projects: []ImportProject{
		{Day: "2026-11-18", Source: "claude-code", Name: "widgets", ObservedOutputTokens: 300, Turns: 1, GrantEpoch: epoch},
		{Day: "2026-11-17", Source: "claude-code", Name: "docs", ObservedOutputTokens: 100, Turns: 1, GrantEpoch: epoch},
		{Day: "2026-11-19", Source: "claude-code", Name: "live-day", ObservedOutputTokens: 900, Turns: 1, GrantEpoch: epoch},
		{Day: "2026-11-18", Source: "claude-code", Name: "stale", ObservedOutputTokens: 900, Turns: 1, GrantEpoch: &GrantEpoch{StoreEpoch: "other"}},
	}}
	live := PerfView{OK: true, Ledger: PerfLedger{Rows: []PerfRow{{Day: "2026-11-19", Source: "claude-code"}}}}
	ps := live.ImportedProjects(imp, *a)
	if len(ps) != 2 {
		t.Fatalf("only admitted days before the first live day count: %+v", ps)
	}
	r := (PerfView{Now: now}).Projects().WithImportedProjects(cache, now, ps)
	top := r.Recent7d.Top
	if len(top) != 2 || *top[0].Label != "widgets" || top[0].Share != 0.75 || *top[1].Label != "docs" || top[1].Share != 0.25 {
		t.Fatalf("%+v", top)
	}
	if top[0].Ref == "" || strings.Contains(top[0].Ref, "widgets") {
		t.Fatalf("ref: %q", top[0].Ref)
	}
}

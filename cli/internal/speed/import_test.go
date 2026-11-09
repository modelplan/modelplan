// SPDX-License-Identifier: MIT
package speed

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

const (
	canaryPrompt = "CANARY-PROMPT-TEXT-7731"
	canaryID     = "CANARY-SESSION-ID-4410"
	canaryPath   = "CANARY-PROJECT-DIR-9902"
)

func admitted(sources ...string) *consent.Admission {
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	for _, s := range sources {
		state.Scopes[s] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
	}
	for _, s := range []string{consent.ScopeClaudeLocalHistory, consent.ScopeCodexLocalHistory} {
		if _, ok := state.Scopes[s]; !ok { // undecided scopes would be implicit grants: deny explicitly
			state.Scopes[s] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
		}
	}
	a := consent.NewAdmission(state, consent.Automatic)
	return &a
}

func both() *consent.Admission {
	return admitted(consent.ScopeClaudeLocalHistory, consent.ScopeCodexLocalHistory)
}

const dayS = 86400.0

// claudeTurnAt: one Claude Code turn (prompt, one reply) starting s seconds after t0.
func claudeTurnAt(s float64, req, model string) []string {
	return []string{
		strings.Replace(ccPrompt(s), "a question", canaryPrompt, 1),
		strings.Replace(ccReply(s+2, req, model, "high", "", 400, 0, "end_turn", false), `"text":"answer"`, `"text":"`+canaryPrompt+`"`, 1),
	}
}

type fixture struct {
	t            *testing.T
	cache        string
	claude, home string
	now          time.Time
}

func newFixture(t *testing.T) *fixture {
	utc(t)
	root := t.TempDir()
	f := &fixture{t: t, cache: filepath.Join(root, "cache"), claude: filepath.Join(root, "claude"), home: filepath.Join(root, "codex"), now: t0.Add(2 * 24 * time.Hour)}
	os.MkdirAll(filepath.Join(f.claude, "projects", canaryPath), 0o700)
	os.MkdirAll(filepath.Join(f.home, "sessions", "2026", "10"), 0o700)
	return f
}

// claudeLog writes a transcript whose turns start at the given day offsets (negative = before t0).
func (f *fixture) claudeLog(name string, offsets ...float64) string {
	var lines []string
	for i, o := range offsets {
		lines = append(lines, claudeTurnAt(o*dayS, fmt.Sprintf("%s-%d", canaryID, i), "claude-fixture")...)
	}
	p := filepath.Join(f.claude, "projects", canaryPath, name)
	writeLines(f.t, p, lines...)
	os.Chtimes(p, f.now, f.now)
	return p
}

func (f *fixture) codexLog(name string, offsets ...float64) string {
	var lines []string
	for _, o := range offsets {
		lines = append(lines, cxTurnLines(o*dayS, `{"model":"codex-fixture","effort":"high","cwd":"/`+canaryPath+`"}`, 30, req{out: 300, gen: 10, ttft: 1})...)
	}
	p := filepath.Join(f.home, "sessions", "2026", "10", name)
	writeLines(f.t, p, lines...)
	os.Chtimes(p, f.now, f.now)
	return p
}

func (f *fixture) run(days int, adm *consent.Admission) ImportResult {
	f.t.Helper()
	res, err := Import(context.Background(), f.cache, ImportOptions{Days: days, Claude: &ImportRoot{Dir: f.claude}, Codex: &ImportRoot{Dir: f.home}, Now: f.now, Admission: adm})
	if err != nil {
		f.t.Fatal(err)
	}
	return res
}

func total(l ImportLedger, source string) (reqs int, out int64) {
	for _, r := range l.Rows {
		if r.Source == source {
			reqs += r.ObservedRequests
			out += r.ObservedOutputTokens
		}
	}
	return
}

func TestImportReadsBothSourcesTaggedAndPrivate(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("s-"+canaryID+".jsonl", -3, -2, -1)
	f.codexLog("rollout-"+canaryID+".jsonl", -5, -1)
	res := f.run(30, both())
	if len(res.Sources) != 2 || res.Sources[0].Status != StatusImported || res.Sources[1].Status != StatusImported {
		t.Fatalf("result: %+v", res)
	}
	l, ok := LoadImported(f.cache)
	if !ok {
		t.Fatal("unreadable")
	}
	if r, o := total(l, "claude-code"); r != 3 || o != 1200 {
		t.Fatalf("claude %d/%d", r, o)
	}
	if r, o := total(l, "codex"); r != 2 || o != 600 {
		t.Fatalf("codex %d/%d", r, o)
	}
	for _, r := range l.Rows {
		if r.Origin != OriginImport || r.GrantEpoch == nil {
			t.Fatalf("untagged row %+v", r)
		}
		if r.Source == "claude-code" && (r.Effort != "high" || r.Model != "claude-fixture") {
			t.Fatalf("config %+v", r)
		}
	}
	b, _ := os.ReadFile(ImportPath(f.cache))
	for _, c := range []string{canaryPrompt, canaryID, canaryPath, f.claude, f.home} {
		if strings.Contains(string(b), c) {
			t.Fatalf("ledger holds %q", c)
		}
	}
	// nothing else was written under the cache either
	filepath.WalkDir(f.cache, func(p string, d os.DirEntry, _ error) error {
		if !d.IsDir() {
			if b, _ := os.ReadFile(p); strings.Contains(string(b), canaryPrompt) || strings.Contains(string(b), canaryPath) {
				t.Fatalf("%s holds a canary", p)
			}
		}
		return nil
	})
}

func TestImportTwiceAddsNothing(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("a.jsonl", -3, -2)
	f.codexLog("rollout-a.jsonl", -4)
	f.run(30, both())
	first, _ := os.ReadFile(ImportPath(f.cache))
	f.run(30, both())
	second, _ := os.ReadFile(ImportPath(f.cache))
	l, _ := LoadImported(f.cache)
	if r, _ := total(l, "claude-code"); r != 2 {
		t.Fatalf("claude %d", r)
	}
	if string(first) != string(second) {
		// only the coverage end may move (now is the same here, so nothing may change)
		t.Fatalf("re-import changed the ledger:\n%s\n%s", first, second)
	}
}

func TestImportGrowsIncrementallyWithoutRecounting(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("a.jsonl", -3)
	f.run(30, both())
	// the log grows by a turn that started after the first import's cutoff
	f.now = f.now.Add(time.Hour)
	writeLines(t, filepath.Join(f.claude, "projects", canaryPath, "a.jsonl"), claudeTurnAt(2*dayS+1800, "late", "claude-fixture")...)
	f.run(30, both())
	l, _ := LoadImported(f.cache)
	if r, _ := total(l, "claude-code"); r != 2 {
		t.Fatalf("want 2 requests, got %d", r)
	}
}

func TestImportStopsAtLiveLedgerStart(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("a.jsonl", -3, -0.5, 0.5, 1)
	seedPerf(t, f.cache, t0) // live ledger started at t0: it counts turns from there on
	f.run(30, both())
	l, _ := LoadImported(f.cache)
	if r, _ := total(l, "claude-code"); r != 2 {
		t.Fatalf("only turns before the live ledger: got %d", r)
	}
	// live then import: the live observer's own count of the later turns is not repeated here
	if c := l.Coverage["claude-code"]; !c.Through.Equal(t0) {
		t.Fatalf("coverage %+v", c)
	}
}

func TestImportDepthCutoffAndExtension(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("a.jsonl", -40, -20, -5)
	f.run(7, both())
	l, _ := LoadImported(f.cache)
	if r, _ := total(l, "claude-code"); r != 1 {
		t.Fatalf("7 days: %d", r)
	}
	f.run(30, both())
	l, _ = LoadImported(f.cache)
	if r, _ := total(l, "claude-code"); r != 2 {
		t.Fatalf("30 days: %d (40 days back must stay out)", r)
	}
	f.run(90, both())
	l, _ = LoadImported(f.cache)
	if r, _ := total(l, "claude-code"); r != 3 {
		t.Fatalf("90 days: %d", r)
	}
	f.run(5000, both())
	if res := f.run(5000, both()); res.Days != ImportMaxDays {
		t.Fatalf("cap: %d", res.Days)
	}
}

func TestImportSkipsUnconsentedAndOff(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("a.jsonl", -3)
	f.codexLog("rollout-a.jsonl", -3)
	res := f.run(30, admitted(consent.ScopeClaudeLocalHistory))
	if res.Sources[0].Status != StatusImported || res.Sources[1].Status != StatusNoConsent {
		t.Fatalf("%+v", res)
	}
	l, _ := LoadImported(f.cache)
	if r, _ := total(l, "codex"); r != 0 || len(l.Coverage) != 1 {
		t.Fatalf("codex read without consent: %+v", l.Coverage)
	}
	t.Setenv("MODELPLAN_HISTORY", "off")
	f2 := newFixture(t)
	f2.claudeLog("a.jsonl", -3)
	if res := f2.run(30, both()); res.Sources[0].Status != StatusOff {
		t.Fatalf("%+v", res)
	}
	if _, err := os.Stat(ImportPath(f2.cache)); err == nil {
		t.Fatal("wrote while history is off")
	}
}

func TestImportMalformedUnreadableAndHugeLines(t *testing.T) {
	f := newFixture(t)
	p := f.claudeLog("a.jsonl", -3)
	writeLines(t, p, `{"type":"assistant", broken`, `not json at all`, `{"type":"user"`, `{"type":"assistant","timestamp":"bad","message":{}}`)
	writeLines(t, p, `{"type":"user","message":{"content":"`+strings.Repeat("x", maxLine+10)+`"},"timestamp":"`+at(-2*dayS)+`"}`)
	bad := filepath.Join(f.claude, "projects", canaryPath, "b.jsonl")
	writeLines(t, bad, "x")
	os.Chmod(bad, 0)
	os.Symlink("/nonexistent", filepath.Join(f.claude, "projects", "dangling.jsonl"))
	f.run(30, both())
	l, _ := LoadImported(f.cache)
	if r, _ := total(l, "claude-code"); r != 1 {
		t.Fatalf("got %d", r)
	}
	// a missing tool is nothing found, not an error
	empty := t.TempDir()
	res, err := Import(context.Background(), filepath.Join(t.TempDir(), "c"), ImportOptions{Claude: &ImportRoot{Dir: empty}, Now: f.now, Admission: both()})
	if err != nil || res.Sources[0].Status != StatusNothing {
		t.Fatalf("%+v %v", res, err)
	}
}

func TestImportCancelLeavesLedgerUntouched(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("a.jsonl", -3)
	f.run(30, both())
	before, _ := os.ReadFile(ImportPath(f.cache))
	f.claudeLog("b.jsonl", -2)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	res, err := Import(ctx, f.cache, ImportOptions{Days: 90, Claude: &ImportRoot{Dir: f.claude}, Codex: &ImportRoot{Dir: f.home}, Now: f.now, Admission: both()})
	if err != nil || !res.Cancelled {
		t.Fatalf("%+v %v", res, err)
	}
	after, _ := os.ReadFile(ImportPath(f.cache))
	if string(before) != string(after) {
		t.Fatal("a cancelled import changed the ledger")
	}
}

func TestRemoveImportedDeletesOnlyImportedRows(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("a.jsonl", -3)
	seedPerf(t, f.cache, t0.Add(-100*24*time.Hour))
	liveBefore, _ := os.ReadFile(PerfPath(f.cache))
	if _, err := Import(context.Background(), f.cache, ImportOptions{Claude: &ImportRoot{Dir: f.claude}, Now: f.now, Admission: both(), Auto: true}); err != nil {
		t.Fatal(err)
	}
	if err := RemoveImported(f.cache); err != nil {
		t.Fatal(err)
	}
	l, _ := LoadImported(f.cache)
	if len(l.Rows) != 0 || len(l.Coverage) != 0 || l.AutoRan == nil {
		t.Fatalf("%+v", l)
	}
	if NeedsAutoImport(f.cache) {
		t.Fatal("remove must not re-arm the first-run import")
	}
	liveAfter, _ := os.ReadFile(PerfPath(f.cache))
	if string(liveBefore) != string(liveAfter) {
		t.Fatal("live ledger touched")
	}
}

func TestAutoImportRunsOnceEvenWhenEverythingIsSkipped(t *testing.T) {
	f := newFixture(t)
	if !NeedsAutoImport(f.cache) {
		t.Fatal("first run must need the import")
	}
	if _, err := Import(context.Background(), f.cache, ImportOptions{Now: f.now, Admission: both(), Auto: true}); err != nil {
		t.Fatal(err)
	}
	if NeedsAutoImport(f.cache) {
		t.Fatal("still pending")
	}
}

func TestImportLedgerSizeBound(t *testing.T) {
	utc(t)
	now := t0
	l := ImportLedger{SchemaVersion: 1, Coverage: map[string]Span{"codex": {From: now.AddDate(0, 0, -300), Through: now}}}
	for i := 0; i < maxRows+500; i++ {
		d := now.AddDate(0, 0, -(i % 300)).Local().Format("2006-01-02")
		l.Rows = append(l.Rows, PerfRow{Day: d, Source: "codex", Model: fmt.Sprintf("m%d", i), Parser: ParserCodex, Eligibility: EligibilityV1})
	}
	l.prune(now)
	b, _ := marshalLen(l)
	if len(l.Rows) > maxRows || b >= maxFile {
		t.Fatalf("rows %d, bytes %d", len(l.Rows), b)
	}
	if c := l.Coverage["codex"]; !c.From.After(now.AddDate(0, 0, -300)) {
		t.Fatalf("coverage start did not move past the dropped days: %+v", c)
	}
}

func marshalLen(l ImportLedger) (int, error) {
	b, err := json.Marshal(l)
	return len(b), err
}

func TestImportAfterRevokeAndRegrantStartsOver(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("a.jsonl", -3, -2)
	f.run(30, both())
	state := consent.Empty()
	state.StoreEpoch = "0123456789abcdef0123456789abcdef"
	state.Generation = 2
	state.Revoked[consent.ScopeClaudeLocalHistory] = 1
	state.Scopes[consent.ScopeClaudeLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion, At: t0}
	state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
	regrant := consent.NewAdmission(state, consent.Automatic)
	f.run(30, &regrant)
	l, _ := LoadImported(f.cache)
	if r, _ := total(l, "claude-code"); r != 2 {
		t.Fatalf("rows doubled or lost after a regrant: %d", r)
	}
	for _, r := range l.Rows {
		if r.GrantEpoch == nil || r.GrantEpoch.RevokedGeneration != 1 {
			t.Fatalf("old epoch row left: %+v", r)
		}
	}
}

func TestImportReportsProgressAndStatusWithoutReadingLogs(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("a.jsonl", -3)
	f.claudeLog("b.jsonl", -2)
	f.codexLog("rollout-a.jsonl", -2)
	var last [2]int
	calls := 0
	_, err := Import(context.Background(), f.cache, ImportOptions{Claude: &ImportRoot{Dir: f.claude}, Codex: &ImportRoot{Dir: f.home}, Now: f.now, Admission: both(), Auto: true,
		Progress: func(done, total int) { calls++; last = [2]int{done, total} }})
	if err != nil || last != [2]int{3, 3} || calls < 4 {
		t.Fatalf("progress %v after %d calls, %v", last, calls, err)
	}
	// status reads only imported.json: remove the logs and it still answers
	os.RemoveAll(f.claude)
	os.RemoveAll(f.home)
	st := ImportStatus(f.cache)
	if !st.AutoRan || st.Rows == 0 || len(st.Coverage) != 2 || st.Coverage[0].Source != "claude-code" || st.Coverage[0].Through != day(f.now.Add(-time.Second)) {
		t.Fatalf("%+v", st)
	}
}

func TestImportCancelledAfterReadsBeforeCommitWritesNothing(t *testing.T) {
	f := newFixture(t)
	f.claudeLog("a.jsonl", -3)
	ctx, cancel := context.WithCancel(context.Background())
	// the cancel arrives after every read and before the write: Progress reports the last file, Guard runs at commit
	res, err := Import(ctx, f.cache, ImportOptions{Claude: &ImportRoot{Dir: f.claude}, Now: f.now, Admission: both(), Auto: true,
		Guard: func(tool string, write func() error) error { cancel(); return write() }})
	if err != nil || !res.Cancelled {
		t.Fatalf("%+v %v", res, err)
	}
	if _, err := os.Stat(ImportPath(f.cache)); err == nil {
		t.Fatal("a cancelled import wrote imported.json")
	}
	if !NeedsAutoImport(f.cache) {
		t.Fatal("a cancelled first-run import must not count as run")
	}
	// cancelled before the first write, between reads and commit
	ctx2, cancel2 := context.WithCancel(context.Background())
	res, err = Import(ctx2, f.cache, ImportOptions{Claude: &ImportRoot{Dir: f.claude}, Now: f.now, Admission: both(),
		Progress: func(done, total int) {
			if done == total && total > 0 {
				cancel2()
			}
		}})
	if err != nil || !res.Cancelled {
		t.Fatalf("%+v %v", res, err)
	}
	if _, err := os.Stat(ImportPath(f.cache)); err == nil {
		t.Fatal("wrote after a late cancel")
	}
}

func TestImportCountsAResumedSessionsRequestOnceAcrossFiles(t *testing.T) {
	f := newFixture(t)
	// the same assistant request id appears in both files (a resumed session copies its messages)
	f.claudeLog("a.jsonl", -3)
	f.claudeLog("b.jsonl", -3)
	// and a request with a fresh id only in b
	writeLines(t, filepath.Join(f.claude, "projects", canaryPath, "b.jsonl"), claudeTurnAt(-2*dayS, "fresh-request", "claude-fixture")...)
	f.run(30, both())
	l, _ := LoadImported(f.cache)
	if r, _ := total(l, "claude-code"); r != 2 {
		t.Fatalf("want 2 requests (one shared, one fresh), got %d", r)
	}
}

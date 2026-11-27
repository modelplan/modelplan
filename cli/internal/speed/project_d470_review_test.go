package speed

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/tokenacct"
)

// macrevb-1299 round 1: the reviewer's reproductions, kept as regression tests. Every path and name is synthetic.

// macrevb-1299-2: the repository comes before the independent-chat bucket; a projectless thread is independent
// only in a folder that is in no repository.
func TestD470ReviewProjectlessThreadInACheckoutIsTheRepository(t *testing.T) {
	d470Home(t)
	root := t.TempDir()
	repo := d470Repo(t, filepath.Join(root, "sample-repo"), "")
	scratch := filepath.Join(root, "listed-scratch")
	os.MkdirAll(scratch, 0o700)
	os.MkdirAll(filepath.Join(repo, "pkg"), 0o700)
	r := newProjectResolver(t.TempDir(), []byte("synthetic"), true)
	r.codex = &codexProjects{roots: []string{scratch}, projectless: map[string]bool{"synthetic-thread": true}}
	if got := r.resolve("codex", filepath.Join(repo, "pkg"), nativeProject{Thread: "synthetic-thread"}); got.Kind != KindRepo || got.Label != "sample-repo" {
		t.Fatalf("an unassigned thread in a checkout: %+v, want the repository", got)
	}
	if got := r.resolve("codex", scratch, nativeProject{Thread: "synthetic-thread"}); got.Kind != KindIndependent {
		t.Fatalf("an unassigned thread in a listed scratch folder: %+v, want independent", got)
	}
	// Assigned to a project, the listed folder is its workspace.
	r.codex.assigned = map[string]bool{"synthetic-thread": true}
	if got := r.resolve("codex", scratch, nativeProject{Thread: "synthetic-thread"}); got.Kind != KindWorkspace {
		t.Fatalf("an assigned thread in a listed folder: %+v, want the workspace", got)
	}
}

// macrevb-1299-3: a session seen only from a folder inside a linked worktree keeps the repository (same reference
// and kind) after the worktree and its git metadata are removed, through a fresh resolver.
func TestD470ReviewRemovedWorktreeSeenOnlyFromASubfolder(t *testing.T) {
	d470Home(t)
	root := t.TempDir()
	repo := d470Repo(t, filepath.Join(root, "sample-repo"), "")
	wt := filepath.Join(root, "sample-worktree")
	linkWorktree(t, repo, wt)
	child := filepath.Join(wt, "pkg", "deep")
	os.MkdirAll(child, 0o700)
	cache := t.TempDir()
	want := projectorInfo(cache, true)("claude-code", child, nativeProject{})
	if want.Kind != KindRepo || want.Label != "sample-repo" {
		t.Fatalf("live: %+v", want)
	}
	os.RemoveAll(wt)
	os.RemoveAll(filepath.Join(repo, ".git", "worktrees"))
	if got := projectorInfo(cache, true)("claude-code", child, nativeProject{}); got != want {
		t.Fatalf("removed worktree: %+v, want %+v", got, want)
	}
	if got := projectorInfo(cache, true)("claude-code", filepath.Join(wt, "other"), nativeProject{}); got != want {
		t.Fatalf("another folder of the removed worktree: %+v, want %+v", got, want)
	}
}

// macrevb-1299-5: the remembered worktrees hold no path, user name or (with labels off) label; nothing is written
// while labels are off, and turning them off deletes what was stored. The grouping stays stable.
func TestD470ReviewRememberedWorktreesHoldNoPaths(t *testing.T) {
	home := d470Home(t)
	root := filepath.Join(home, "code")
	repo := d470Repo(t, filepath.Join(root, "synthetic-project"), "")
	wt := filepath.Join(root, "synthetic-worktree")
	linkWorktree(t, repo, wt)
	file := filepath.Join(t.TempDir(), "project-labels.json")
	os.MkdirAll(filepath.Join(wt, "src"), 0o700)

	off := t.TempDir()
	offInfo := projectorInfo(off, false)("claude-code", wt, nativeProject{})
	if offInfo.Kind != KindRepo || offInfo.Label != "" {
		t.Fatalf("labels off: %+v", offInfo)
	}
	if _, err := os.Stat(rememberPath(off)); err == nil {
		t.Fatal("remembered worktrees written while labels are off")
	}

	cache := t.TempDir()
	on := projectorInfo(cache, true)("claude-code", filepath.Join(wt, "src"), nativeProject{})
	b, err := os.ReadFile(rememberPath(cache))
	if err != nil {
		t.Fatal(err)
	}
	for _, leak := range []string{home, root, wt, repo, "sampleperson", "synthetic-worktree", "/"} {
		if strings.Contains(string(b), leak) {
			t.Fatalf("the remembered worktrees hold %q: %s", leak, b)
		}
	}
	// An older build's raw-path file is removed on sight.
	legacy := filepath.Join(cache, "observed", legacyRememberFile)
	os.WriteFile(legacy, []byte(`[["`+wt+`","`+repo+`"]]`), 0o600)
	projectorInfo(cache, true)("claude-code", wt, nativeProject{})
	if _, err := os.Stat(legacy); err == nil {
		t.Fatal("the raw-path file of an older build is kept")
	}
	seedPerf(t, cache, t0.Add(-time.Minute))
	if err := SetProjectLabels(file, cache, false); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(rememberPath(cache)); err == nil {
		t.Fatal("turning labels off kept the remembered worktrees")
	}
	if got := projectorInfo(cache, false)("claude-code", wt, nativeProject{}); got.Ref != on.Ref || got.Kind != KindRepo || got.Label != "" {
		t.Fatalf("labels off after on: %+v, want ref %s", got, on.Ref)
	}
	// A labels file edited by hand (no command) still deletes what an earlier run remembered.
	projectorInfo(cache, true)("claude-code", wt, nativeProject{})
	projectorInfo(cache, false)("claude-code", wt, nativeProject{})
	if _, err := os.Stat(rememberPath(cache)); err == nil {
		t.Fatal("a run with labels off kept the remembered worktrees")
	}
}

// macrevb-1299-4: a ledger written under the older project rule is re-attributed through ordinary observation even
// when its log has no new turns; counts and session references are kept and the kind is a published one.
func TestD470ReviewQuietSessionIsReattributedOnUpgrade(t *testing.T) {
	home := d470Home(t)
	utc(t)
	cache := t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	repo := d470Repo(t, filepath.Join(home, "code", "sample-repo"), "")
	p := filepath.Join(t.TempDir(), "sample.jsonl")
	prompt := strings.Replace(ccPrompt(0), `"type":"user"`, fmt.Sprintf(`"cwd":%q,"type":"user"`, repo), 1)
	writeLines(t, p, prompt, ccReply(10, "r1", "claude-fixture", "high", "", 900, 0, "end_turn", false))
	if err := ObserveClaude(cache, p, false, Ingest{Labels: true}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	before, ok := LoadPerf(cache)
	if !ok || len(before.Sessions) != 1 {
		t.Fatal("expected one stored session")
	}
	want := before.Sessions[0]
	// Downgrade to what the older rule stored.
	old := before
	old.Sessions = append([]PerfSession(nil), before.Sessions...)
	old.Sessions[0].ProjectRule, old.Sessions[0].ProjectRef, old.Sessions[0].ProjectLabel, old.Sessions[0].ProjectKind = 1, "0123456789abcdef0123456789abcdef", "old-label", ""
	b, _ := json.Marshal(old)
	if err := write(PerfPath(cache), b); err != nil {
		t.Fatal(err)
	}
	// Before it is observed again, readers never show the older guess and always publish a kind.
	if v, _ := LoadPerf(cache); true {
		if ref, label, kind := v.Sessions[0].Project(); ref != "" || label != "" || kind != KindNone {
			t.Fatalf("an unmigrated session reads as %q %q %q", ref, label, kind)
		}
	}
	if err := ObserveClaude(cache, p, false, Ingest{Labels: true}, t0.Add(2*time.Minute)); err != nil {
		t.Fatal(err)
	}
	after, _ := LoadPerf(cache)
	got := after.Sessions[0]
	if got.ProjectRule != projectRule || got.ProjectRef != want.ProjectRef || got.ProjectKind != KindRepo || got.ProjectLabel != "sample-repo" {
		t.Fatalf("after observation: %+v, want project %s", got, want.ProjectRef)
	}
	if got.Ref != want.Ref || !sameDays(got.Days, want.Days) {
		t.Fatalf("counts or reference changed: %+v vs %+v", got, want)
	}
	v := view(t, cache, t0.Add(3*time.Minute))
	for _, row := range v.Usage(nil).Recent7d.ProjectRows {
		if row.ProjectKind == "" {
			t.Fatalf("a usage row without a kind: %+v", row)
		}
	}
}

// macrevb-1299-4, ZCode: an older session in the tool's database is re-attributed from its session table.
func TestD470ReviewQuietDatabaseSessionIsReattributed(t *testing.T) {
	d470Home(t)
	utc(t)
	cache, home, root := t.TempDir(), t.TempDir(), t.TempDir()
	repo := d470Repo(t, filepath.Join(root, "sample-repo"), "")
	seedPerf(t, cache, t0.Add(-time.Minute))
	db := sqliteDB(t, ZCodeDB(home), `
		CREATE TABLE model_usage (id TEXT PRIMARY KEY, session_id TEXT, turn_id TEXT, model_id TEXT, started_at INTEGER,
			completed_at INTEGER, duration_ms INTEGER, input_tokens INTEGER, output_tokens INTEGER, reasoning_tokens INTEGER,
			cache_read_input_tokens INTEGER, cache_creation_input_tokens INTEGER, agent TEXT, mode TEXT);
		CREATE TABLE session (id TEXT PRIMARY KEY, directory TEXT, path TEXT, title TEXT, project_id TEXT);`)
	exec(t, db, `INSERT INTO session VALUES ('z-1', ?, '', '', '')`, repo)
	done := t0.Add(20 * time.Second)
	exec(t, db, `INSERT INTO model_usage (id, session_id, turn_id, model_id, started_at, completed_at, input_tokens, output_tokens, reasoning_tokens)
		VALUES ('r1', 'z-1', 't', 'GLM-5.2', ?, ?, 9000, 300, 40)`, ms(t0), ms(done))
	if err := ObserveZCode(cache, home, Ingest{Labels: true}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	l, _ := LoadPerf(cache)
	if len(l.Sessions) != 1 || l.Sessions[0].ProjectKind != KindRepo {
		t.Fatalf("%+v", l.Sessions)
	}
	want := l.Sessions[0]
	l.Sessions[0].ProjectRule, l.Sessions[0].ProjectRef, l.Sessions[0].ProjectKind = 1, "0123456789abcdef0123456789abcdef", ""
	b, _ := json.Marshal(l)
	write(PerfPath(cache), b)
	if err := ObserveZCode(cache, home, Ingest{Labels: true}, t0.Add(time.Hour)); err != nil {
		t.Fatal(err)
	}
	l, _ = LoadPerf(cache)
	if got := l.Sessions[0]; got.ProjectRule != projectRule || got.ProjectRef != want.ProjectRef || got.ProjectKind != KindRepo || !sameDays(got.Days, want.Days) {
		t.Fatalf("after observation: %+v, want %+v", got, want)
	}
}

// macrevb-1299-6: an unnamed Auto Review rollout read by the real accounting parser is one background run with its
// tokens and the dated fallback price; an interactive rollout with no model metadata stays its own session.
func TestD470ReviewUnnamedAutoReviewThroughTheAccountingParser(t *testing.T) {
	utc(t)
	parse := func(file string) usageRecord {
		p := newAccountingParser("codex", file)
		p.line(0, 0, []byte(`{"timestamp":"2026-11-26T12:00:00Z","type":"session_meta","payload":{"id":"`+file+`"}}`))
		p.line(0, 0, []byte(`{"timestamp":"2026-11-26T12:00:01Z","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":20,"output_tokens":10}}}}`))
		if len(p.records) != 1 {
			t.Fatalf("records=%d", len(p.records))
		}
		return p.records[0]
	}
	review, chat := parse("synthetic-review"), parse("synthetic-chat")
	resp := func(r usageRecord) []SessionResponse {
		return []SessionResponse{{Source: "codex", Model: r.Model, Response: Response{At: r.At, Buckets: r.usageBuckets}}}
	}
	v := PerfView{OK: true, Now: review.At.Add(time.Minute), Ledger: PerfLedger{
		UsageSessions: map[string][]SessionResponse{"k-review": resp(review), "k-chat": resp(chat)},
		Sessions:      []PerfSession{{Ref: "aaaaaaaaaaaaaaaa", Key: "k-chat", Source: "codex", FirstAt: chat.At, LastAt: chat.At}},
	}}
	priced := modelPricer{}
	got := v.reviewRuns(day(review.At), priced)
	if got.Runs != 1 || got.Tokens.Total != review.usageBuckets.Sum() || !got.ModelApprox || got.Model != FallbackModel(day(review.At)) {
		t.Fatalf("review row: %+v (parsed model %q)", got, review.Model)
	}
	got.Cost.settle()
	if got.Cost.USD == nil {
		t.Fatalf("review not priced as the dated fallback: %+v", got.Cost)
	}
	if c := v.sessionCost(v.Ledger.Sessions[0], day(chat.At), priced); c.USD == nil {
		t.Fatalf("the interactive session lost its own usage: %+v", c)
	}
	if w := v.Usage(priced).Today; w.Review.Runs != 1 || len(w.SessionRows) != 0 && w.SessionRows[0].Ref != "aaaaaaaaaaaaaaaa" {
		t.Fatalf("usage window: %+v", w)
	}
}

// modelPricer prices only the published fallback models, one cent a request: a response priced under the
// "unknown" sentinel is unpriced.
type modelPricer struct{}

func (modelPricer) Request(source, model, tier string, b tokenacct.Buckets) (float64, bool) {
	for _, f := range autoReviewFallbacks {
		if f.model == model {
			return 0.01, true
		}
	}
	return 0, false
}

func (p modelPricer) Aggregate(source, model string, b tokenacct.Buckets) (float64, bool, bool) {
	usd, ok := p.Request(source, model, "", b)
	return usd, ok, false
}

// macrevb-1299-7: a Codex thread's native name is known before its project, so a project folder named after the
// thread's slug is never its label; the title is kept under consent.
func TestD470ReviewCodexThreadNameIsNeverTheProjectLabel(t *testing.T) {
	utc(t)
	home := d470Home(t)
	cx := filepath.Join(home, ".codex")
	os.MkdirAll(cx, 0o700)
	thread := "00000000-0000-4000-8000-000000000001"
	db := sqliteDB(t, filepath.Join(cx, "state_5.sqlite"), `CREATE TABLE threads (id TEXT PRIMARY KEY, name TEXT, title TEXT);`)
	exec(t, db, `INSERT INTO threads VALUES ('`+thread+`','Synthetic Thread Name','')`)
	cwd := filepath.Join(home, "workspace", "synthetic-thread-name")
	os.MkdirAll(cwd, 0o700)
	os.WriteFile(filepath.Join(cx, "config.toml"), []byte(fmt.Sprintf("[projects.%q]\ntrust_level = \"trusted\"\n", cwd)), 0o600)
	cache := t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	log := filepath.Join(t.TempDir(), "rollout-2026-11-26T10-00-00-"+thread+".jsonl")
	writeLines(t, log, cxSession(cwd, 0, 700)...)
	if err := ObserveCodex(cache, []string{log}, func(string) bool { return false }, Ingest{Labels: true}, t0.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	l, ok := LoadPerf(cache)
	if !ok || len(l.Sessions) != 1 {
		t.Fatal("expected one stored session")
	}
	s := l.Sessions[0]
	if s.Title != "Synthetic Thread Name" {
		t.Fatalf("thread name not loaded: %+v", s)
	}
	if s.ProjectLabel != "" || s.ProjectKind != KindNone {
		t.Fatalf("the thread's slug became a project label: %+v", s)
	}
}

func sameDays(a, b []SessionDay) bool {
	x, _ := json.Marshal(a)
	y, _ := json.Marshal(b)
	return string(x) == string(y)
}

// macrevb-1303-5: a linked worktree whose main checkout and common git metadata are deleted, while the worktree
// itself remains, keeps the repository it was remembered under, and is never taken for a parent repository.
func TestD470ReviewWorktreeWithItsMainCheckoutDeleted(t *testing.T) {
	d470Home(t)
	outer := d470Repo(t, t.TempDir(), "") // an unrelated repository above both
	repo := d470Repo(t, filepath.Join(outer, "sample-repo"), "")
	wt := filepath.Join(outer, "sample-worktree")
	linkWorktree(t, repo, wt)
	child := filepath.Join(wt, "pkg")
	os.MkdirAll(child, 0o700)
	cache := t.TempDir()
	want := projectorInfo(cache, true)("claude-code", child, nativeProject{})
	if want.Kind != KindRepo || want.Label != "sample-repo" {
		t.Fatalf("live: %+v", want)
	}
	os.RemoveAll(repo)
	if got := projectorInfo(cache, true)("claude-code", child, nativeProject{}); got != want {
		t.Fatalf("main checkout deleted: %+v, want %+v", got, want)
	}
	// Never remembered: the broken worktree is not the outer repository.
	outerInfo := projectorInfo(t.TempDir(), true)("claude-code", outer, nativeProject{})
	if got := projectorInfo(t.TempDir(), true)("claude-code", child, nativeProject{}); got.Ref == outerInfo.Ref {
		t.Fatalf("a broken worktree was taken for the parent repository: %+v", got)
	}
}

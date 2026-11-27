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

// Owner decision D470: a project is a repository root (worktrees merged), else a workspace the tool names, else
// a bucket. These fixtures are the owner's build-6 cases.

// d470Home makes a home folder named like a person ("guanzhicheng") and points HOME at it.
func d470Home(t *testing.T) string {
	t.Helper()
	home := filepath.Join(t.TempDir(), "guanzhicheng")
	if err := os.MkdirAll(home, 0o700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("HOME", home)
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	return home
}

func d470Repo(t *testing.T, dir, remote string) string {
	t.Helper()
	if err := os.MkdirAll(filepath.Join(dir, ".git"), 0o700); err != nil {
		t.Fatal(err)
	}
	if remote != "" {
		cfg := "[core]\n\tbare = false\n[remote \"origin\"]\n\turl = " + remote + "\n\tfetch = +refs/heads/*:refs/remotes/origin/*\n"
		if err := os.WriteFile(filepath.Join(dir, ".git", "config"), []byte(cfg), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	return dir
}

// linkWorktree makes wt a linked worktree of repo the way git lays it out.
func linkWorktree(t *testing.T, repo, wt string) {
	t.Helper()
	name := filepath.Base(wt)
	gd := filepath.Join(repo, ".git", "worktrees", name)
	for _, d := range []string{gd, wt} {
		if err := os.MkdirAll(d, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	os.WriteFile(filepath.Join(gd, "commondir"), []byte("../..\n"), 0o600)
	os.WriteFile(filepath.Join(wt, ".git"), []byte("gitdir: "+gd+"\n"), 0o600)
}

func TestProjectHomeCwdIsABucketNeverTheUserName(t *testing.T) {
	home := d470Home(t)
	cache := t.TempDir()
	pr := projectorInfo(cache, true)
	for _, cwd := range []string{home, filepath.Join(home, "Documents")} {
		for _, source := range []string{"claude-code", "codex"} {
			i := pr(source, cwd, nativeProject{})
			if i.Kind != KindHome || i.Label != "" || i.Ref == "" {
				t.Fatalf("%s %s: %+v", source, cwd, i)
			}
		}
	}
	// A repository inside home is a project of its own.
	ping := d470Repo(t, filepath.Join(home, "code", "ping"), "")
	os.MkdirAll(filepath.Join(ping, "src"), 0o700)
	if i := pr("claude-code", filepath.Join(ping, "src"), nativeProject{}); i.Kind != KindRepo || i.Label != "ping" {
		t.Fatalf("a repository inside home: %+v", i)
	}
	// A dotfiles repository at home itself is still the home bucket.
	d470Repo(t, home, "")
	if i := projectorInfo(cache, true)("claude-code", home, nativeProject{}); i.Kind != KindHome {
		t.Fatalf("a repository at home: %+v", i)
	}
	// Temp folders and an unknown directory: no project.
	if i := pr("claude-code", "/", nativeProject{}); i.Kind != KindNone || i.Label != "" {
		t.Fatalf("root: %+v", i)
	}
	if i := pr("claude-code", "", nativeProject{}); i.Ref != "" {
		t.Fatalf("no directory at all has no reference: %+v", i)
	}
}

func TestProjectCodexScratchChatsAreIndependentNotProjects(t *testing.T) {
	home := d470Home(t)
	scratch := filepath.Join(home, "Documents", "Codex", "2026-11-26", "yes-mostly-you-ve-seen-me")
	os.MkdirAll(scratch, 0o700)
	state := fmt.Sprintf(`{"electron-saved-workspace-roots":[%q,%q],"projectless-thread-ids":["chat-1","chat-2"],"thread-project-assignments":{"chat-2":{"projectId":"p"}}}`, home, scratch)
	os.MkdirAll(filepath.Join(home, ".codex"), 0o700)
	os.WriteFile(filepath.Join(home, ".codex", ".codex-global-state.json"), []byte(state), 0o600)
	cache := t.TempDir()
	pr := projectorInfo(cache, true)
	i := pr("codex", scratch, nativeProject{Thread: "chat-1"})
	if i.Kind != KindIndependent || i.Label != "" || i.Ref == "" {
		t.Fatalf("a listed projectless thread is an independent chat even in a saved root: %+v", i)
	}
	// A thread with a project assignment is not independent: the saved workspace (never home) names it, but a
	// chat slug is never a label.
	i = pr("codex", scratch, nativeProject{Thread: "chat-2"})
	if i.Kind == KindIndependent {
		t.Fatalf("an assigned thread: %+v", i)
	}
	// An unlisted thread in home is the home bucket, never the saved home root.
	if i := pr("codex", home, nativeProject{Thread: "other"}); i.Kind != KindHome {
		t.Fatalf("home as a saved workspace root: %+v", i)
	}
	if i := pr("codex", home, nativeProject{Thread: "chat-1"}); i.Kind != KindIndependent {
		t.Fatalf("%+v", i)
	}
}

func TestProjectCodexThreadIDComesFromTheRolloutName(t *testing.T) {
	home := d470Home(t)
	utc(t)
	const id = "019a7c3e-1111-7222-8333-444455556666"
	os.MkdirAll(filepath.Join(home, ".codex"), 0o700)
	os.WriteFile(filepath.Join(home, ".codex", ".codex-global-state.json"), []byte(`{"projectless-thread-ids":["`+id+`"]}`), 0o600)
	cache, logs := t.TempDir(), t.TempDir()
	scratch := filepath.Join(home, "Documents", "Codex", "new-chat")
	os.MkdirAll(scratch, 0o700)
	p := filepath.Join(logs, "rollout-2026-10-17T09-00-00-"+id+".jsonl")
	writeLines(t, p, cxSession(scratch, 0, 700)...)
	seedPerf(t, cache, t0.Add(-time.Minute))
	if err := ObserveCodex(cache, []string{p}, func(string) bool { return false }, Ingest{Labels: true}, t0.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	l, _ := LoadPerf(cache)
	if len(l.Sessions) != 1 || l.Sessions[0].ProjectKind != KindIndependent || l.Sessions[0].ProjectLabel != "" || l.Sessions[0].ProjectRef == "" {
		t.Fatalf("%+v", l.Sessions)
	}
	if b, _ := os.ReadFile(PerfPath(cache)); strings.Contains(string(b), "new-chat") || strings.Contains(string(b), "guanzhicheng") {
		t.Fatal("a scratch folder name or the user name is in perf.json")
	}
}

func TestProjectWorktreesMergeIntoTheirRepositoryWhateverTheirName(t *testing.T) {
	d470Home(t)
	root := t.TempDir()
	repo := d470Repo(t, filepath.Join(root, "modelplans.ai"), "")
	uuid := filepath.Join(root, "b98e560e-5c6c-4d7e-8f90-123456789abc", "modelplans.ai")
	t3 := filepath.Join(root, "t3-af920b12")
	linkWorktree(t, repo, uuid)
	linkWorktree(t, repo, t3)
	cache := t.TempDir()
	pr := projectorInfo(cache, true)
	want := pr("claude-code", repo, nativeProject{})
	if want.Kind != KindRepo || want.Label != "modelplans.ai" {
		t.Fatalf("%+v", want)
	}
	for _, cwd := range []string{uuid, filepath.Join(uuid, "src"), t3, filepath.Join(repo, "x")} {
		os.MkdirAll(cwd, 0o700)
		if i := pr("codex", cwd, nativeProject{}); i != want {
			t.Fatalf("%s: %+v, want %+v", cwd, i, want)
		}
	}
	// The worktree is deleted once its branch lands; the remembered mapping keeps its history with the repository.
	os.RemoveAll(t3)
	os.RemoveAll(filepath.Join(repo, ".git", "worktrees"))
	if i := projectorInfo(cache, true)("claude-code", filepath.Join(t3, "pkg"), nativeProject{}); i != want {
		t.Fatalf("a gone worktree: %+v", i)
	}
	// With no remembered mapping, a gone directory is never walked up to an unrelated repository.
	if i := projectorInfo(t.TempDir(), true)("claude-code", filepath.Join(repo, "gone", "deep"), nativeProject{}); i == want {
		t.Fatalf("a gone directory inside a repository was walked up: %+v", i)
	}
}

func TestProjectLabelsNeverAreIdentifiersAndGenericNamesUseTheRemote(t *testing.T) {
	d470Home(t)
	root := t.TempDir()
	cache := t.TempDir()
	pr := projectorInfo(cache, true)
	for remote, dir := range map[string]string{
		"git@github.com:modelplan/modelplan.git":     filepath.Join(root, "work", "repo"),
		"https://github.com/modelplan/modelplans.ai": filepath.Join(root, "work2", "checkout"),
		"https://github.com/modelplan/ping.git/":     filepath.Join(root, "work3", "5f0c9e1ab77d3"),
		"https://example.com/org/some-thing.git":     filepath.Join(root, "work4", "t3-0123abcd"),
	} {
		d470Repo(t, dir, remote)
		want := strings.TrimSuffix(strings.TrimRight(remote[strings.LastIndexAny(remote, "/:")+1:], "/"), ".git")
		if strings.HasSuffix(remote, ".git/") {
			want = "ping"
		}
		if i := pr("claude-code", dir, nativeProject{}); i.Label != want || i.Kind != KindRepo {
			t.Fatalf("%s: %+v, want label %q", dir, i, want)
		}
	}
	// No remote: a generic name stays; an identifier falls to the bucket.
	d470Repo(t, filepath.Join(root, "a", "repo"), "")
	if i := pr("claude-code", filepath.Join(root, "a", "repo"), nativeProject{}); i.Label != "repo" {
		t.Fatalf("%+v", i)
	}
	d470Repo(t, filepath.Join(root, "b", "b98e560e-5c6c-4d7e-8f90-123456789abc"), "")
	if i := pr("claude-code", filepath.Join(root, "b", "b98e560e-5c6c-4d7e-8f90-123456789abc"), nativeProject{}); i.Kind != KindNone || i.Label != "" {
		t.Fatalf("a UUID is never a label: %+v", i)
	}
	// A thread title (or its slug) is never a label.
	d470Repo(t, filepath.Join(root, "c", "the-worth-it-menu"), "")
	if i := pr("claude-code", filepath.Join(root, "c", "the-worth-it-menu"), nativeProject{Title: "The worth-it menu"}); i.Kind != KindNone {
		t.Fatalf("the title as a label: %+v", i)
	}
	// Labels off: kind and reference stay, the label goes.
	if i := projectorInfo(cache, false)("claude-code", filepath.Join(root, "a", "repo"), nativeProject{}); i.Label != "" || i.Kind != KindRepo || i.Ref == "" {
		t.Fatalf("%+v", i)
	}
}

func TestProjectClaudeCwdLedgerSessionAndTitle(t *testing.T) {
	home := d470Home(t)
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	repo := d470Repo(t, filepath.Join(home, "code", "ping"), "")
	os.MkdirAll(filepath.Join(repo, "src"), 0o700)
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "s.jsonl")
	prompt := strings.Replace(ccPrompt(0), `"type":"user"`, fmt.Sprintf(`"cwd":%q,"type":"user"`, filepath.Join(repo, "src")), 1)
	writeLines(t, p,
		`{"type":"ai-title","aiTitle":"Generated name","sessionId":"s"}`,
		prompt,
		ccReply(10, "r1", "claude-fixture", "high", "", 900, 0, "end_turn", false),
		`{"type":"custom-title","customTitle":"  Set by\nthe user ","sessionId":"s"}`)
	if err := ObserveClaude(cache, p, false, Ingest{Labels: true}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	l, _ := LoadPerf(cache)
	s := l.Sessions[0]
	if s.ProjectLabel != "ping" || s.ProjectKind != KindRepo || s.Title != "Set by the user" {
		t.Fatalf("%+v", s)
	}
	// Titles follow the labels switch: off, none is kept; turning labels off deletes them.
	cache2 := t.TempDir()
	seedPerf(t, cache2, t0.Add(-time.Minute))
	if err := ObserveClaude(cache2, p, false, Ingest{}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if l2, _ := LoadPerf(cache2); l2.Sessions[0].Title != "" || l2.Sessions[0].ProjectLabel != "" {
		t.Fatalf("labels off: %+v", l2.Sessions[0])
	}
	file := ProjectLabelsFile(t.TempDir())
	if err := SetProjectLabels(file, cache, false); err != nil {
		t.Fatal(err)
	}
	if l3, _ := LoadPerf(cache); l3.Sessions[0].Title != "" {
		t.Fatal("turning labels off deletes titles")
	}
}

func TestZCodeTitleIsReadOnlyWhileLabelsAreOn(t *testing.T) {
	// The ZCode fixture's session row carries the title "Secret title" (sqlite_test.go): it is read with labels
	// on and never stored with them off.
	var l PerfLedger
	l.titles = true
	if got := cleanTitle("  a \n b "); got != "a b" {
		t.Fatal(got)
	}
	long := strings.Repeat("x", 300)
	if n := len([]rune(cleanTitle(long))); n != maxTitle {
		t.Fatal(n)
	}
	if codexThreadOfPath("/x/rollout-2026-10-17T09-00-00-019A7C3E-1111-7222-8333-444455556666.jsonl") != "019a7c3e-1111-7222-8333-444455556666" || codexThreadOfPath("/x/rollout-a.jsonl") != "" {
		t.Fatal("thread id from the rollout name")
	}
	_ = l
}

func fixedPricer() Pricer { return flatPricer{} }

// flatPricer prices one cent per thousand tokens, except the model "free".
type flatPricer struct{}

func (flatPricer) Request(_, model, _ string, b tokenacct.Buckets) (float64, bool) {
	if model == "unpriced-model" {
		return 0, false
	}
	return float64(b.Sum()) / 100000, true
}
func (flatPricer) Aggregate(source, model string, b tokenacct.Buckets) (float64, bool, bool) {
	usd, ok := flatPricer{}.Request(source, model, "", b)
	return usd, ok, false
}

func usageDay(d string, model string, out, in, read, write int64) SessionDay {
	total := in + read + write + out
	return SessionDay{Day: d, Model: model, EffortStatus: "reported", Effort: "high", ObservedRequests: 1, ObservedOutputTokens: out,
		Kinds: &TokenKinds{TotalTokens: &total, InputTokens: &in, CacheReadTokens: &read, CacheWriteTokens: &write}}
}

func TestUsageRankingByTotalTokensWithSharesCostAndBackgroundReview(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	today := day(now)
	old := day(now.AddDate(0, 0, -3))
	sess := []PerfSession{
		// Output-light but cache-heavy: ranks first by total tokens, last by output.
		{Ref: "1111111111111111", Key: "k1", Source: "claude-code", ProjectRef: "pa", ProjectLabel: "alpha", ProjectKind: KindRepo, Title: "Cache heavy", LastAt: now, FirstAt: now.Add(-time.Hour),
			Days: []SessionDay{usageDay(today, "opus", 10, 100, 5000, 100)}},
		{Ref: "2222222222222222", Key: "k2", Source: "codex", ProjectRef: "pa", ProjectLabel: "alpha", ProjectKind: KindRepo, LastAt: now,
			Days: []SessionDay{usageDay(today, "sol", 900, 100, 100, 0), usageDay(old, "sol", 1000, 0, 0, 0)}},
		{Ref: "3333333333333333", Key: "k3", Source: "codex", ProjectRef: "pi", ProjectKind: KindIndependent, LastAt: now,
			Days: []SessionDay{usageDay(today, "sol", 200, 50, 50, 0)}},
		{Ref: "4444444444444444", Key: "k4", Source: "zcode", LastAt: now,
			Days: []SessionDay{{Day: today, Model: "glm", EffortStatus: "unreported", ObservedRequests: 1, ObservedOutputTokens: 77}}}, // recorded before token kinds
	}
	resp := func(source, model string, in, out int64) SessionResponse {
		return SessionResponse{Source: source, Model: model, Response: Response{At: now.Add(-time.Hour), Tier: "standard", Buckets: tokenacct.Buckets{Input: in, Output: out}}}
	}
	v := PerfView{OK: true, Recording: true, Now: now, Ledger: PerfLedger{Sessions: sess, UsageSessions: map[string][]SessionResponse{
		"k1": {resp("claude-code", "opus", 5200, 10)},
		"k3": {resp("codex", "unpriced-model", 100, 100)},
		// Two review runs, one named only by the auto-review id, one by no model.
		"rv1": {resp("codex", "codex-auto-review", 300, 100)},
		"rv2": {resp("codex", "", 100, 0)},
	}}}
	u := v.Usage(fixedPricer())
	w := u.Today
	if u.Measure != "total-tokens" || len(w.SessionRows) != 4 {
		t.Fatalf("%+v", u)
	}
	// Ranked by total tokens, not output.
	order := []string{"1111111111111111", "2222222222222222", "3333333333333333"}
	for i, ref := range order {
		if w.SessionRows[i].Ref != ref {
			t.Fatalf("row %d = %s, want %s", i, w.SessionRows[i].Ref, ref)
		}
	}
	if w.SessionRows[0].Tokens.Total != 5210 || w.SessionRows[0].Tokens.CacheRead != 5000 || w.SessionRows[0].Tokens.Output != 10 {
		t.Fatalf("%+v", w.SessionRows[0].Tokens)
	}
	if w.SessionRows[1].Tokens.Total != 1100 { // the 3-day-old day is outside today
		t.Fatalf("%+v", w.SessionRows[1].Tokens)
	}
	// A session recorded before token kinds adds nothing to the total (never its output alone) and says so.
	last := w.SessionRows[3]
	if last.Ref != "4444444444444444" || last.Tokens.Total != 0 || last.Tokens.Complete {
		t.Fatalf("%+v", last)
	}
	// The window total counts the review runs, and every share is a part of it: the shares add up to 1.
	if w.Review.Runs != 2 || w.Review.Tokens.Total != 500 || w.Review.Model != "gpt-5.6-luna" || !w.Review.ModelApprox {
		t.Fatalf("review: %+v", w.Review)
	}
	if want := int64(5210 + 1100 + 300 + 500); w.Total.Tokens() != want {
		t.Fatalf("total %d, want %d", w.Total.Total, want)
	}
	sum := w.Review.Share
	for _, r := range w.SessionRows {
		sum += r.Share
	}
	if sum < 0.999999 || sum > 1.000001 {
		t.Fatalf("shares add up to %v", sum)
	}
	psum := w.Review.Share
	for _, r := range w.ProjectRows {
		psum += r.Share
	}
	if psum < 0.999999 || psum > 1.000001 || w.Projects != 3 {
		t.Fatalf("project shares add up to %v over %d projects", psum, w.Projects)
	}
	// Projects: alpha merges its two sessions across tools; the unattributed session is the no-project bucket.
	if a := w.ProjectRows[0]; a.Ref != "pa" || a.Sessions != 2 || a.Tokens.Total != 6310 || len(a.Sources) != 2 || a.Label == nil || *a.Label != "alpha" {
		t.Fatalf("%+v", a)
	}
	var none UsageRow
	for _, r := range w.ProjectRows {
		if r.Ref == unattributedRef {
			none = r
		}
	}
	if none.ProjectKind != KindNone || none.Sessions != 1 {
		t.Fatalf("%+v", none)
	}
	// ≈$: priced per recorded response; an unpriced session has no cost, never $0.
	c0 := w.SessionRows[0].Cost
	if c0.State != CostPriced || c0.USD == nil || *c0.USD < 0.0521 || *c0.USD > 0.0523 {
		t.Fatalf("%+v", c0)
	}
	if c := w.SessionRows[2].Cost; c.State != CostUnpriced || c.USD != nil {
		t.Fatalf("%+v", c)
	}
	if w.Review.Cost.State != CostPriced || w.Cost.State != CostPartial {
		t.Fatalf("review cost %+v, total cost %+v", w.Review.Cost, w.Cost)
	}
	// The 7-day window adds the older day.
	if got := u.Recent7d.SessionRows[1].Tokens.Total; got != 2100 {
		t.Fatalf("7d total of the codex session: %d", got)
	}
	// Auto Review is never a model: no row carries its id.
	b, _ := json.Marshal(u)
	if strings.Contains(string(b), "codex-auto-review") {
		t.Fatal("the review id is in the usage view")
	}
}

func (t TokenSums) Tokens() int64 { return t.Total }

func TestUsageRowCapSumsTheRestIntoOther(t *testing.T) {
	utc(t)
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	var sess []PerfSession
	for i := 0; i < RankCap+5; i++ {
		sess = append(sess, PerfSession{Ref: fmt.Sprintf("%016x", i+1), Key: fmt.Sprint(i), Source: "codex", ProjectRef: fmt.Sprintf("p%d", i), ProjectKind: KindRepo, LastAt: now,
			Days: []SessionDay{usageDay(day(now), "sol", int64(10+i), 0, 0, 0)}})
	}
	w := PerfView{OK: true, Recording: true, Now: now, Ledger: PerfLedger{Sessions: sess}}.Usage(nil).Today
	if len(w.SessionRows) != RankCap || w.OtherSessions.Count != 5 || w.Sessions != RankCap+5 || len(w.ProjectRows) != RankCap || w.OtherProjects.Count != 5 {
		t.Fatalf("%d rows, other %d", len(w.SessionRows), w.OtherSessions.Count)
	}
	sum := w.OtherSessions.Share
	for _, r := range w.SessionRows {
		sum += r.Share
	}
	if sum < 0.999999 || sum > 1.000001 || w.SessionRows[0].Tokens.Total < w.SessionRows[1].Tokens.Total {
		t.Fatalf("shares %v", sum)
	}
	// No prices at all: unpriced, never $0.
	if w.Cost.State != CostUnpriced || w.Cost.USD != nil {
		t.Fatalf("%+v", w.Cost)
	}
}

func TestFallbackModelByDate(t *testing.T) {
	for d, want := range map[string]string{"2026-11-26": "gpt-5.6-luna", "2026-07-29": "gpt-5.4", "2026-03-05": "gpt-5.4", "2026-02-06": "gpt-5.3-codex", "2025-08-08": "gpt-5", "2024-01-01": "gpt-5"} {
		if got := FallbackModel(d); got != want {
			t.Errorf("%s: %s, want %s", d, got, want)
		}
	}
}

// Privacy: nothing a view publishes names a path or the user.
func TestUsageViewHoldsNoPathOrUserName(t *testing.T) {
	home := d470Home(t)
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "s.jsonl")
	prompt := strings.Replace(ccPrompt(0), `"type":"user"`, fmt.Sprintf(`"cwd":%q,"type":"user"`, home), 1)
	writeLines(t, p, prompt, ccReply(10, "r1", "claude-fixture", "high", "", 900, 0, "end_turn", false))
	if err := ObserveClaude(cache, p, false, Ingest{Labels: true}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	now := t0.Add(2 * time.Minute)
	u := view(t, cache, now).Usage(fixedPricer())
	b, _ := json.Marshal(u)
	for _, leak := range []string{"guanzhicheng", home, dir, "/tmp", "/home/", "/Users/"} {
		if strings.Contains(string(b), leak) {
			t.Fatalf("%q in the usage view: %s", leak, b)
		}
	}
	if pb, _ := os.ReadFile(PerfPath(cache)); strings.Contains(string(pb), "guanzhicheng") || strings.Contains(string(pb), home) {
		t.Fatal("the user name or home path is in perf.json")
	}
	if rows := u.Recent7d.ProjectRows; len(rows) != 1 || rows[0].ProjectKind != KindHome || rows[0].Label != nil {
		t.Fatalf("%+v", rows)
	}
}

// A Codex thread's title is threads.name (the app-generated or user-set name), never the first-message title.
func TestCodexTitleIsTheThreadName(t *testing.T) {
	home := d470Home(t)
	db := sqliteDB(t, filepath.Join(home, ".codex", "state_5.sqlite"), `CREATE TABLE threads (id TEXT PRIMARY KEY, name TEXT, title TEXT);`)
	exec(t, db, `INSERT INTO threads VALUES ('t-1', 'Fix the tape', 'FIRST MESSAGE SECRET'), ('t-2', '', 'FIRST MESSAGE SECRET')`)
	var l PerfLedger
	if got := l.codexTitle("t-1"); got != "Fix the tape" {
		t.Fatalf("%q", got)
	}
	if got := l.codexTitle("t-2"); got != "" {
		t.Fatalf("a thread with no name has no title, not its first message: %q", got)
	}
	if got := l.codexTitle("missing"); got != "" {
		t.Fatalf("%q", got)
	}
}

package speed

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// gitRepo makes <root>/acme as a checkout with a .git directory and <root>/acme-wt as one of its
// worktrees (a .git file and a commondir), the way git lays them out.
func gitRepo(t *testing.T, root string) (repo, worktree string) {
	t.Helper()
	repo, worktree = filepath.Join(root, "acme"), filepath.Join(root, "acme-wt")
	wt := filepath.Join(repo, ".git", "worktrees", "acme-wt")
	for _, d := range []string{filepath.Join(repo, "src"), wt, worktree} {
		if err := os.MkdirAll(d, 0o700); err != nil {
			t.Fatal(err)
		}
	}
	os.WriteFile(filepath.Join(wt, "commondir"), []byte("../..\n"), 0o600)
	os.WriteFile(filepath.Join(worktree, ".git"), []byte("gitdir: "+wt+"\n"), 0o600)
	return repo, worktree
}

func cxSession(cwd string, s float64, out float64) []string {
	meta := fmt.Sprintf(`{"id":"x","source":"cli","cwd":%q}`, cwd)
	ctx := fmt.Sprintf(`{"model":"fixture-model","effort":"high","cwd":%q}`, cwd)
	return append([]string{cx(s, "session_meta", meta)}, cxTurnLines(s+1, ctx, 30, req{out, 20, 1})...)
}

// codexHome points Codex's home at a temp dir whose config.toml lists the given project folders.
func codexHome(t *testing.T, projects ...string) {
	t.Helper()
	home := t.TempDir()
	var b strings.Builder
	b.WriteString("model = \"fixture\"\n")
	for _, p := range projects {
		fmt.Fprintf(&b, "\n[projects.%q]\ntrust_level = \"trusted\"\n", p)
	}
	if err := os.WriteFile(filepath.Join(home, "config.toml"), []byte(b.String()), 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("CODEX_HOME", home)
}

// Codex's project is the folder Codex lists that holds the session; a session outside every
// listed folder, or without a working directory, has no project (it is not guessed).
func TestProjectRanking(t *testing.T) {
	utc(t)
	cache, logs, root := t.TempDir(), t.TempDir(), t.TempDir()
	repo, worktree := gitRepo(t, root)
	codexHome(t, repo)
	gone := filepath.Join(root, "scratch")
	os.MkdirAll(gone, 0o700)
	files := map[string][]string{
		"a": cxSession(filepath.Join(repo, "src"), 0, 3000),
		"b": cxSession(worktree, 2, 1000), // a worktree of the listed repository
		"c": cxSession(gone, 4, 500),      // in no listed folder
		"d": append([]string{cx(6, "session_meta", `{"id":"d","source":"cli"}`)}, cxTurnLines(7, high, 30, req{500, 20, 1})...),
	}
	var rollouts []string
	for _, k := range []string{"a", "b", "c", "d"} {
		p := filepath.Join(logs, "rollout-"+k+".jsonl")
		writeLines(t, p, files[k]...)
		rollouts = append(rollouts, p)
	}
	seedPerf(t, cache, t0.Add(-time.Minute))
	now := t0.Add(5 * time.Minute)
	if err := ObserveCodex(cache, rollouts, func(string) bool { return false }, Ingest{}, now); err != nil {
		t.Fatal(err)
	}
	v := view(t, cache, now)
	w := v.Projects().Recent7d
	if w.Projects != 1 || w.TotalObservedOutputTokens != 5000 || w.UnattributedOutputTokens != 1000 {
		t.Fatalf("projects = %+v", w)
	}
	top := w.Top[0]
	if top.Sessions != 2 || top.ObservedOutputTokens != 4000 || top.Share != 0.8 || top.Label != nil || len(top.Ref) != 32 ||
		len(top.Configs) != 1 || top.Configs[0].Share != 1 || top.Configs[0].Effort != "high" {
		t.Fatalf("top = %+v", top)
	}
	rs := v.Ranking().Recent7d.Top
	refs := map[int64]*string{}
	for _, r := range rs {
		refs[r.ObservedOutputTokens] = r.ProjectRef
	}
	if refs[3000] == nil || *refs[3000] != top.Ref || refs[1000] == nil || *refs[1000] != top.Ref || refs[500] != nil {
		t.Fatalf("session refs = %+v", refs)
	}

	// Without the opt-in no label reaches the file, even when the ledger was given one.
	b, _ := os.ReadFile(PerfPath(cache))
	for _, leak := range []string{"acme", root, "scratch"} {
		if bytes.Contains(b, []byte(leak)) {
			t.Fatalf("%q in perf.json", leak)
		}
	}
	l, _ := LoadPerf(cache)
	l.Sessions[0].ProjectLabel = "planted"
	j, _ := json.Marshal(l)
	os.WriteFile(PerfPath(cache), j, 0o600)
	observeCx(t, cache, now.Add(time.Minute), rollouts...)
	if b, _ := os.ReadFile(PerfPath(cache)); bytes.Contains(b, []byte("planted")) {
		t.Fatal("a label without the opt-in is dropped")
	}

	// With labels on, a new turn names the project by the Codex project's folder; turning them off deletes them.
	home := t.TempDir()
	file := ProjectLabelsFile(home)
	if err := SetProjectLabels(file, cache, true); err != nil || !ProjectLabels(file) {
		t.Fatal("labels on", err)
	}
	writeLines(t, rollouts[1], cxTurnLines(100, fmt.Sprintf(`{"model":"fixture-model","effort":"high","cwd":%q}`, worktree), 30, req{200, 20, 1})...)
	if err := ObserveCodex(cache, rollouts, func(string) bool { return false }, Ingest{Labels: true}, now.Add(10*time.Minute)); err != nil {
		t.Fatal(err)
	}
	if l := view(t, cache, now.Add(10*time.Minute)).Projects().Recent7d.Top[0].Label; l == nil || *l != "acme" {
		t.Fatalf("label = %v", l)
	}
	if err := SetProjectLabels(file, cache, false); err != nil || ProjectLabels(file) {
		t.Fatal("labels off", err)
	}
	if b, _ := os.ReadFile(PerfPath(cache)); bytes.Contains(b, []byte("acme")) || !bytes.Contains(b, []byte(top.Ref)) {
		t.Fatal("turning labels off deletes the labels and keeps the references")
	}

	// The key stays, so the references do; another key gives other references.
	k1, _ := os.ReadFile(projectKeyPath(cache))
	if r, _ := projector(cache, false)("codex", worktree, nativeProject{}); r != top.Ref || len(strings.TrimSpace(string(k1))) != 64 {
		t.Fatal("the reference follows the stored key")
	}
	if r, _ := projector(t.TempDir(), false)("codex", worktree, nativeProject{}); r == top.Ref {
		t.Fatal("a new key gives new references")
	}
}

// Codex with no listed project folders (or no config at all) gives no project; the deepest listed
// folder wins; the desktop app's saved workspace roots count too.
func TestCodexProjectDefinition(t *testing.T) {
	cache, root := t.TempDir(), t.TempDir()
	repo, _ := gitRepo(t, root)
	sub := filepath.Join(repo, "src")
	t.Setenv("CODEX_HOME", t.TempDir()) // no config.toml
	if r, _ := projector(cache, true)("codex", sub, nativeProject{}); r != "" {
		t.Fatal("no Codex project: no project, not the git root")
	}
	codexHome(t, root, repo)
	_, label := projector(cache, true)("codex", sub, nativeProject{})
	if label != "acme" {
		t.Fatalf("the deepest listed folder wins: %q", label)
	}
	if r, _ := projector(cache, true)("codex", t.TempDir(), nativeProject{}); r != "" {
		t.Fatal("a folder outside every project has none")
	}
	home := t.TempDir()
	t.Setenv("CODEX_HOME", home)
	os.WriteFile(filepath.Join(home, ".codex-global-state.json"), []byte(fmt.Sprintf(`{"electron-saved-workspace-roots":[%q]}`, repo)), 0o600)
	if _, label := projector(cache, true)("codex", sub, nativeProject{}); label != "acme" {
		t.Fatalf("saved workspace root: %q", label)
	}
}

// Claude Code's project is the session's working directory: worktrees and subfolders are their own.
func TestClaudeSessionProject(t *testing.T) {
	utc(t)
	cache, dir, root := t.TempDir(), t.TempDir(), t.TempDir()
	repo, _ := gitRepo(t, root)
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "s.jsonl")
	prompt := strings.Replace(ccPrompt(0), `"type":"user"`, fmt.Sprintf(`"cwd":%q,"type":"user"`, filepath.Join(repo, "src")), 1)
	writeLines(t, p, prompt, ccReply(10, "r1", "claude-fixture", "high", "", 900, 0, "end_turn", false))
	if err := ObserveClaude(cache, p, false, Ingest{}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	w := view(t, cache, t0.Add(time.Minute)).Projects().Recent7d
	if w.Projects != 1 || w.Top[0].ObservedOutputTokens != 900 {
		t.Fatalf("projects = %+v", w)
	}
	pr := projector(cache, true)
	if r, label := pr("claude-code", filepath.Join(repo, "src"), nativeProject{}); r != w.Top[0].Ref || label != "src" {
		t.Fatalf("the session's directory is its project: %q", label)
	}
	if r, _ := pr("claude-code", repo, nativeProject{}); r == w.Top[0].Ref {
		t.Fatal("a repository's root is another project than its subfolder")
	}
	if r, _ := pr("gemini", repo, nativeProject{}); r != "" {
		t.Fatal("a tool without a project notion has none")
	}
}

func TestProjectCap(t *testing.T) {
	l := PerfLedger{SchemaVersion: 1, Since: t0}
	day := t0.Format("2006-01-02")
	for i := 0; i < maxProjects+3; i++ {
		l.Sessions = append(l.Sessions, PerfSession{Ref: fmt.Sprint(i), Key: fmt.Sprint(i), Source: "codex", ProjectRef: fmt.Sprintf("p%d", i),
			LastAt: t0.Add(time.Duration(i) * time.Minute), Days: []SessionDay{{Day: day, Model: "m", EffortStatus: "unreported", ObservedRequests: 1, ObservedOutputTokens: 1}}})
	}
	l.prune(t0)
	n := 0
	for _, s := range l.Sessions {
		if s.ProjectRef != "" {
			n++
		}
	}
	if n != maxProjects || len(l.Sessions) != maxProjects+3 || l.Sessions[0].ProjectRef != "" || l.Sessions[len(l.Sessions)-1].ProjectRef == "" {
		t.Fatalf("projects kept = %d of %d", n, len(l.Sessions))
	}
}

func TestSessionSubscription(t *testing.T) {
	utc(t)
	cache, dir := t.TempDir(), t.TempDir()
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "rollout-s.jsonl")
	writeLines(t, p, cxTurnLines(0, high, 30, req{500, 20, 1})...)
	if err := ObserveCodex(cache, []string{p}, func(string) bool { return false }, Ingest{Subscription: "1111aaaa2222bbbb"}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	// A later turn read under another account keeps the session's first subscription.
	writeLines(t, p, cxTurnLines(100, high, 30, req{500, 20, 1})...)
	if err := ObserveCodex(cache, []string{p}, func(string) bool { return false }, Ingest{Subscription: "3333cccc4444dddd"}, t0.Add(5*time.Minute)); err != nil {
		t.Fatal(err)
	}
	top := view(t, cache, t0.Add(5*time.Minute)).Ranking().Recent7d.Top
	if len(top) != 1 || top[0].SubscriptionRef == nil || *top[0].SubscriptionRef != "1111aaaa2222bbbb" || top[0].ObservedOutputTokens != 1000 {
		t.Fatalf("top = %+v", top)
	}
}

// Labels are on unless the user turned them off; turning them off deletes the stored ones.
func TestProjectLabelsDefault(t *testing.T) {
	cache, home := t.TempDir(), t.TempDir()
	file := ProjectLabelsFile(home)
	if !ProjectLabels(file) {
		t.Fatal("no choice made: on")
	}
	os.MkdirAll(filepath.Dir(file), 0o700)
	for content, want := range map[string]bool{`{"schemaVersion":1}`: true, `{"projectLabels":false}`: false, `{"projectLabels":true}`: true, `not json`: false, `{"projectLabels":"no"}`: false} {
		os.WriteFile(file, []byte(content), 0o600)
		if ProjectLabels(file) != want {
			t.Errorf("%s: labels on = %v", content, !want)
		}
	}
	os.Remove(file)
	os.Mkdir(file, 0o700) // not a file: the choice is unknown, so off
	if ProjectLabels(file) {
		t.Error("an unreadable choice is off")
	}
	os.Remove(file)

	seedPerf(t, cache, t0)
	l, _ := LoadPerf(cache)
	l.Sessions = []PerfSession{{Ref: "r", Key: "k", Source: "codex", ProjectRef: "p", ProjectLabel: "acme", FirstAt: t0, LastAt: t0,
		Days: []SessionDay{{Day: "2026-10-17", Model: "m", EffortStatus: "unreported", ObservedRequests: 1, ObservedOutputTokens: 1}}}}
	b, _ := json.Marshal(l)
	os.WriteFile(PerfPath(cache), b, 0o600)
	if err := SetProjectLabels(file, cache, false); err != nil || ProjectLabels(file) {
		t.Fatal("turned off", err)
	}
	if b, _ := os.ReadFile(PerfPath(cache)); bytes.Contains(b, []byte("acme")) || !bytes.Contains(b, []byte(`"projectRef":"p"`)) {
		t.Fatalf("turning labels off deletes the labels and keeps the references: %s", b)
	}
	if b, _ := os.ReadFile(file); !bytes.Contains(b, []byte(`"projectLabels": false`)) {
		t.Fatalf("the choice is stored: %s", b)
	}
	if !ProjectLabels(ProjectLabelsFile(t.TempDir())) || ProjectLabels(file) {
		t.Fatal("the stored off stays off; another user without a choice is on")
	}
	if err := SetProjectLabels(file, cache, true); err != nil || !ProjectLabels(file) {
		t.Fatal("turned on again", err)
	}
}

// Turning project labels off also removes them from the live records.
func TestClearProjectLabelsCoversLiveRecords(t *testing.T) {
	cache := t.TempDir()
	if err := os.MkdirAll(filepath.Join(cache, "observed"), 0o700); err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(PerfLedger{SchemaVersion: 1, Since: time.Now(), Live: []LiveRecord{{Key: "k", Ref: "r", Source: "codex", ProjectRef: "p", ProjectLabel: "alpha"}}})
	if err := os.WriteFile(PerfPath(cache), raw, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := ClearProjectLabels(cache); err != nil {
		t.Fatal(err)
	}
	l, ok := LoadPerf(cache)
	if !ok || len(l.Live) != 1 || l.Live[0].ProjectLabel != "" || l.Live[0].ProjectRef != "p" {
		t.Fatalf("live = %+v", l.Live)
	}
}

// G3-100 upgrade: a session recorded under the old git-root grouping is re-attributed once on its next
// observation, so the guessed name does not outlive the fix. Counts are kept.
func TestOldGuessedProjectIsReplacedOnNextObservation(t *testing.T) {
	utc(t)
	cache, dir, root := t.TempDir(), t.TempDir(), t.TempDir()
	repo, _ := gitRepo(t, root)
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "s.jsonl")
	prompt := strings.Replace(ccPrompt(0), `"type":"user"`, fmt.Sprintf(`"cwd":%q,"type":"user"`, filepath.Join(repo, "src")), 1)
	writeLines(t, p, prompt, ccReply(10, "r1", "claude-fixture", "high", "", 900, 0, "end_turn", false))
	if err := ObserveClaude(cache, p, false, Ingest{Labels: true}, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	l, _ := LoadPerf(cache)
	if len(l.Sessions) != 1 || l.Sessions[0].ProjectRule != projectRule {
		t.Fatalf("a new session is recorded under the current rule: %+v", l.Sessions)
	}
	l.Sessions[0].ProjectRef, l.Sessions[0].ProjectLabel, l.Sessions[0].ProjectRule = "oldref", "old-guess", 0
	b, _ := json.Marshal(l)
	os.WriteFile(PerfPath(cache), b, 0o600)
	writeLines(t, p, strings.Replace(ccPrompt(15), `"type":"user"`, fmt.Sprintf(`"cwd":%q,"type":"user"`, filepath.Join(repo, "src")), 1), ccReply(20, "r2", "claude-fixture", "high", "", 100, 0, "end_turn", false))
	if err := ObserveClaude(cache, p, false, Ingest{Labels: true}, t0.Add(2*time.Minute)); err != nil {
		t.Fatal(err)
	}
	l, _ = LoadPerf(cache)
	s := l.Sessions[0]
	if s.ProjectRef == "oldref" || s.ProjectLabel != "src" || s.ProjectRule != projectRule {
		t.Fatalf("old guess remains: %+v", s)
	}
}

// macrevb-909-1: after the tool's own rule moves a recorded session to no project, a later live observation
// must not bring back the old live record's guessed project.
func TestUpgradeClearsTheOldLiveProject(t *testing.T) {
	utc(t)
	cache, logs, cwd := t.TempDir(), t.TempDir(), t.TempDir()
	codexHome(t)
	p := filepath.Join(logs, "rollout-synthetic.jsonl")
	writeLines(t, p, cxSession(cwd, 0, 300)...)
	seedPerf(t, cache, t0.Add(-time.Minute))
	now := t0.Add(time.Minute)
	observe := func() {
		if err := ObserveCodex(cache, []string{p}, func(string) bool { return false }, Ingest{Labels: true}, now); err != nil {
			t.Fatal(err)
		}
		if err := ObserveLive(cache, []LiveLog{{Path: p, Source: "codex"}}, true, nil, now); err != nil {
			t.Fatal(err)
		}
	}
	observe()
	l, _ := LoadPerf(cache)
	if len(l.Live) != 1 || len(l.Sessions) != 1 {
		t.Fatalf("precondition: live %d sessions %d", len(l.Live), len(l.Sessions))
	}
	l.Sessions[0].ProjectRef, l.Sessions[0].ProjectLabel, l.Sessions[0].ProjectRule = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "synthetic-old-guess", 0
	l.Live[0].ProjectRef, l.Live[0].ProjectLabel = l.Sessions[0].ProjectRef, l.Sessions[0].ProjectLabel
	b, _ := json.Marshal(l)
	if err := os.WriteFile(PerfPath(cache), b, 0o600); err != nil {
		t.Fatal(err)
	}
	writeLines(t, p, cxTurnLines(100, fmt.Sprintf(`{"model":"fixture-model","effort":"high","cwd":%q}`, cwd), 30, req{200, 20, 1})...)
	now = t0.Add(2 * time.Minute)
	observe()
	l, _ = LoadPerf(cache)
	if l.Sessions[0].ProjectRule != projectRule || l.Sessions[0].ProjectRef != "" {
		t.Fatalf("precondition: session not migrated: %+v", l.Sessions[0])
	}
	if l.Live[0].ProjectRef != "" || l.Live[0].ProjectLabel != "" {
		t.Fatalf("old live project survived the new observation: %q %q", l.Live[0].ProjectRef, l.Live[0].ProjectLabel)
	}
}

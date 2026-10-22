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

func TestProjectRanking(t *testing.T) {
	utc(t)
	cache, logs, root := t.TempDir(), t.TempDir(), t.TempDir()
	repo, worktree := gitRepo(t, root)
	gone := filepath.Join(root, "scratch")
	os.MkdirAll(gone, 0o700)
	files := map[string][]string{
		"a": cxSession(filepath.Join(repo, "src"), 0, 3000),
		"b": cxSession(worktree, 2, 1000), // another worktree of the same repository
		"c": cxSession(gone, 4, 500),      // removed before it is read
		"d": append([]string{cx(6, "session_meta", `{"id":"d","source":"cli"}`)}, cxTurnLines(7, high, 30, req{500, 20, 1})...),
	}
	var rollouts []string
	for _, k := range []string{"a", "b", "c", "d"} {
		p := filepath.Join(logs, "rollout-"+k+".jsonl")
		writeLines(t, p, files[k]...)
		rollouts = append(rollouts, p)
	}
	os.RemoveAll(gone)
	seedPerf(t, cache, t0.Add(-time.Minute))
	now := t0.Add(5 * time.Minute)
	if err := ObserveCodex(cache, rollouts, func(string) bool { return false }, false, now); err != nil {
		t.Fatal(err)
	}
	v := view(t, cache, now)
	w := v.Projects().Recent7d
	if w.Projects != 2 || w.TotalObservedOutputTokens != 5000 || w.UnattributedOutputTokens != 500 {
		t.Fatalf("projects = %+v", w)
	}
	top := w.Top[0]
	if top.Sessions != 2 || top.ObservedOutputTokens != 4000 || top.Share != 0.8 || top.Label != nil || len(top.Ref) != 32 ||
		len(top.Configs) != 1 || top.Configs[0].Share != 1 || top.Configs[0].Effort != "high" {
		t.Fatalf("top = %+v", top)
	}
	if w.Top[1].ObservedOutputTokens != 500 || w.Top[1].Ref == top.Ref {
		t.Fatalf("the removed directory is a project of its own: %+v", w.Top[1])
	}
	rs := v.Ranking().Recent7d.Top
	refs := map[int64]*string{}
	for _, r := range rs {
		refs[r.ObservedOutputTokens] = r.ProjectRef
	}
	if refs[3000] == nil || *refs[3000] != top.Ref || *refs[1000] != top.Ref || refs[500] != nil && *refs[500] == top.Ref {
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

	// With labels on, a new turn names the project by its folder; turning them off deletes them.
	home := t.TempDir()
	file := ProjectLabelsFile(home)
	if err := SetProjectLabels(file, cache, true); err != nil || !ProjectLabels(file) {
		t.Fatal("labels on", err)
	}
	writeLines(t, rollouts[1], cxTurnLines(100, fmt.Sprintf(`{"model":"fixture-model","effort":"high","cwd":%q}`, worktree), 30, req{200, 20, 1})...)
	if err := ObserveCodex(cache, rollouts, func(string) bool { return false }, true, now.Add(10*time.Minute)); err != nil {
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
	if r, _ := projector(cache, false)(worktree); r != top.Ref || len(strings.TrimSpace(string(k1))) != 64 {
		t.Fatal("the reference follows the stored key")
	}
	if r, _ := projector(t.TempDir(), false)(worktree); r == top.Ref {
		t.Fatal("a new key gives new references")
	}
}

func TestClaudeSessionProject(t *testing.T) {
	utc(t)
	cache, dir, root := t.TempDir(), t.TempDir(), t.TempDir()
	repo, _ := gitRepo(t, root)
	seedPerf(t, cache, t0.Add(-time.Minute))
	p := filepath.Join(dir, "s.jsonl")
	prompt := strings.Replace(ccPrompt(0), `"type":"user"`, fmt.Sprintf(`"cwd":%q,"type":"user"`, filepath.Join(repo, "src")), 1)
	writeLines(t, p, prompt, ccReply(10, "r1", "claude-fixture", "high", "", 900, 0, "end_turn", false))
	if err := ObserveClaude(cache, p, false, false, t0.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	w := view(t, cache, t0.Add(time.Minute)).Projects().Recent7d
	if w.Projects != 1 || w.Top[0].ObservedOutputTokens != 900 {
		t.Fatalf("projects = %+v", w)
	}
	if r, _ := projector(cache, false)(repo); r != w.Top[0].Ref {
		t.Fatal("a subdirectory belongs to its repository's project")
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

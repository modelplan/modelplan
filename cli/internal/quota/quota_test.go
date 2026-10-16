package quota

import (
	"bytes"
	"encoding/json"
	"flag"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var update = flag.Bool("update", false, "rewrite testdata/expected.json")

var now = time.Date(2026, 10, 14, 10, 0, 0, 0, time.UTC)

// fixture copies testdata/home into a temp dir and gives the rollouts deterministic mtimes.
func fixture(t *testing.T) Paths {
	t.Helper()
	dir := t.TempDir()
	err := filepath.WalkDir("testdata/home", func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, _ := filepath.Rel("testdata/home", p)
		dst := filepath.Join(dir, "home", rel)
		if d.IsDir() {
			return os.MkdirAll(dst, 0o755)
		}
		b, err := os.ReadFile(p)
		if err != nil {
			return err
		}
		return os.WriteFile(dst, b, 0o644)
	})
	if err != nil {
		t.Fatal(err)
	}
	sessions := filepath.Join(dir, "home/.codex/sessions")
	os.Chtimes(filepath.Join(sessions, "2026/10/13/rollout-2026-10-13T09-00-00-old.jsonl"), now.Add(-24*time.Hour), now.Add(-24*time.Hour))
	os.Chtimes(filepath.Join(sessions, "2026/10/14/rollout-2026-10-14T09-30-00-new.jsonl"), now.Add(-5*time.Minute), now.Add(-5*time.Minute))
	p := Paths{Cache: filepath.Join(dir, "cache"), CodexHome: filepath.Join(dir, "home/.codex"), LocalFile: filepath.Join(dir, "home/.config/modelplan/local.json")}
	b, err := os.ReadFile("testdata/claude-code-statusline.json")
	if err != nil {
		t.Fatal(err)
	}
	var in StatuslineInput
	if err := json.Unmarshal(b, &in); err != nil {
		t.Fatal(err)
	}
	if err := RecordClaudeCode(p.Cache, in, now.Add(-2*time.Minute)); err != nil {
		t.Fatal(err)
	}
	return p
}

func TestReadMatchesSharedExpectation(t *testing.T) {
	p := fixture(t)
	got := marshal(Read(p, now))
	if *update {
		os.WriteFile("testdata/expected.json", got, 0o644)
	}
	want, err := os.ReadFile("testdata/expected.json")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("quota report drifted from testdata/expected.json (run go test -update and review):\n%s", got)
	}
	snap, _ := os.ReadFile(snapshotPath(p.Cache))
	if *update {
		os.WriteFile("testdata/claude-code-snapshot.json", snap, 0o644)
	}
	if fixed, _ := os.ReadFile("testdata/claude-code-snapshot.json"); !bytes.Equal(snap, fixed) {
		t.Fatalf("recorded snapshot drifted from testdata/claude-code-snapshot.json:\n%s", snap)
	}
	// The session id itself never lands; only its one-way sessionKey does.
	for _, leak := range []string{"secret", "/home/u", "transcript", "session_id", "sk-should", "ignore previous", "please do not"} {
		if bytes.Contains(got, []byte(leak)) || bytes.Contains(snap, []byte(leak)) {
			t.Fatalf("private field %q leaked", leak)
		}
	}
}

func TestSnapshotIsRewrittenOnlyWhenItChanges(t *testing.T) {
	p := fixture(t)
	before, _ := os.ReadFile(snapshotPath(p.Cache))
	b, _ := os.ReadFile("testdata/claude-code-statusline.json")
	var in StatuslineInput
	json.Unmarshal(b, &in)
	RecordClaudeCode(p.Cache, in, now.Add(-90*time.Second))
	same, _ := os.ReadFile(snapshotPath(p.Cache))
	if !bytes.Equal(before, same) {
		t.Fatal("unchanged snapshot rewritten within a minute")
	}
	in.Effort.Level = "max"
	RecordClaudeCode(p.Cache, in, now.Add(-90*time.Second))
	changed, _ := os.ReadFile(snapshotPath(p.Cache))
	if !strings.Contains(string(changed), `"effort": "max"`) {
		t.Fatalf("changed snapshot not recorded:\n%s", changed)
	}
}

func TestClaudeCodeSnapshotNamesWhoseSessionItIs(t *testing.T) {
	p := fixture(t)
	attr := func(session string) string {
		p.ClaudeSession = session
		for _, a := range Read(p, now).Accounts {
			if a.Source == "claude-code" {
				return a.Harness.Attribution
			}
		}
		return "no account"
	}
	if got := []string{attr("secret-session"), attr("another"), attr("")}; got[0] != "current-thread" || got[1] != "recent-thread" || got[2] != "" {
		t.Fatalf("attribution = %q", got)
	}
}

func TestMissingSourcesAreReportedNotInvented(t *testing.T) {
	dir := t.TempDir()
	r := Read(Paths{Cache: dir, CodexHome: filepath.Join(dir, "codex"), LocalFile: filepath.Join(dir, "local.json")}, now)
	if len(r.Accounts) != 0 {
		t.Fatalf("accounts from nothing: %+v", r.Accounts)
	}
	for _, s := range r.Sources {
		if s.Status != "missing" {
			t.Fatalf("%s: %s", s.Source, s.Status)
		}
	}
	link := filepath.Join(dir, "link.json")
	os.Symlink("/etc/hostname", link)
	if _, st := readLocal(link, now); st.Status != "unsafe_path" {
		t.Fatalf("symlink accepted: %s", st.Status)
	}
}

func TestHeadroom(t *testing.T) {
	f := func(v float64) *float64 { return &v }
	at := func(m int) *time.Time { x := now.Add(time.Duration(m) * time.Minute); return &x }
	for _, tc := range []struct {
		name string
		ws   []Window
		want string
	}{
		{"exhausted wins", []Window{{Kind: "five_hour", UsedPercent: f(100), ResetsAt: at(30)}, {Kind: "weekly", UsedPercent: f(10), ResetsAt: at(600)}}, "exhausted"},
		{"weekly too fast", []Window{{Kind: "five_hour", UsedPercent: f(10), ResetsAt: at(20)}, {Kind: "weekly", UsedPercent: f(60), ResetsAt: at(10080 / 2)}}, "conserve"},
		{"use it before reset", []Window{{Kind: "five_hour", UsedPercent: f(20), ResetsAt: at(30)}, {Kind: "weekly", UsedPercent: f(30), ResetsAt: at(10080 / 2)}}, "spend"},
		{"weekly near limit pace", []Window{{Kind: "five_hour", UsedPercent: f(20), ResetsAt: at(30)}, {Kind: "weekly", UsedPercent: f(42), ResetsAt: at(10080 / 2)}}, "normal"},
		{"mid window", []Window{{Kind: "five_hour", UsedPercent: f(30), ResetsAt: at(180)}}, "normal"},
		{"no data", []Window{{Kind: "weekly"}}, "unknown"},
		{"reset passed", []Window{{Kind: "weekly", UsedPercent: f(95), ResetsAt: at(-5)}}, "unknown"},
	} {
		a := Account{Windows: tc.ws}
		Evaluate(&a, now)
		if a.Headroom != tc.want {
			t.Errorf("%s: got %s (%s), want %s", tc.name, a.Headroom, a.Deciding, tc.want)
		}
	}
}

// threadsFixture: an interactive desktop thread (pro, both windows), a newer CLI thread on a
// separate limit id, and the newest one, a background review on codex-auto-review that reports
// only the five-hour window. Mtimes follow the timestamps.
func threadsFixture(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	src := "testdata/threads/.codex/sessions/2026/10/14"
	dst := filepath.Join(dir, ".codex/sessions/2026/10/14")
	os.MkdirAll(dst, 0o755)
	es, _ := os.ReadDir(src)
	for i, e := range es {
		b, _ := os.ReadFile(filepath.Join(src, e.Name()))
		os.WriteFile(filepath.Join(dst, e.Name()), b, 0o644)
		at := now.Add(time.Duration(i-len(es)) * 10 * time.Minute)
		os.Chtimes(filepath.Join(dst, e.Name()), at, at)
	}
	return filepath.Join(dir, ".codex")
}

func TestCodexThreadsKeepTheirOwnModel(t *testing.T) {
	home := threadsFixture(t)
	got := marshal(Read(Paths{CodexHome: home}, now))
	if *update {
		os.WriteFile("testdata/expected-threads.json", got, 0o644)
	}
	want, _ := os.ReadFile("testdata/expected-threads.json")
	if !bytes.Equal(got, want) {
		t.Fatalf("drifted from testdata/expected-threads.json:\n%s", got)
	}
	r := Read(Paths{CodexHome: home}, now)
	a := r.Accounts[0]
	if a.Harness.Model != "gpt-6-sol" || a.Harness.Effort != "medium" || a.Harness.Attribution != "recent-thread" || a.Harness.Origin != "cli" {
		t.Fatalf("background review must not become the chat's model: %+v", a.Harness)
	}
	byKey := map[string]Window{}
	for _, w := range a.Windows {
		byKey[w.Limit+"/"+w.Kind] = w
	}
	if w := byKey["/five_hour"]; *w.UsedPercent != 45 || !w.ObservedAt.Equal(time.Date(2026, 10, 14, 9, 51, 0, 0, time.UTC)) {
		t.Fatalf("account five-hour window should be the newest reading: %+v", w)
	}
	if w, ok := byKey["/weekly"]; !ok || *w.UsedPercent != 20 || *w.AgeMinutes != 59 {
		t.Fatalf("a window missing from the newest log is kept with its own age: %+v", byKey)
	}
	if w := byKey["codex_sol/five_hour"]; w.UsedPercent == nil || *w.UsedPercent != 10 {
		t.Fatalf("limit ids stay separate: %+v", byKey)
	}
	cur := Read(Paths{CodexHome: home, CodexThread: "01a14000-aaaa-7000-8000-00000000000a"}, now).Accounts[0].Harness
	if cur.Model != "gpt-6-astra" || cur.Effort != "high" || cur.ServiceTier != "fast" || cur.Attribution != "current-thread" {
		t.Fatalf("named thread: %+v", cur)
	}
	if h := Read(Paths{CodexHome: home, CodexThread: "not-a-thread"}, now).Accounts[0].Harness; h.Attribution != "recent-thread" {
		t.Fatalf("unknown thread falls back to the recent one: %+v", h)
	}
	if bytes.Contains(got, []byte("secret")) || bytes.Contains(got, []byte("/home/u")) {
		t.Fatal("instructions or paths leaked")
	}
}

// The pace rules are shared with the Skill's Python reader; testdata/pace-cases.json is the
// contract both run (skills/model-plan/evals/test_quota.py).
func TestPaceCasesSharedWithThePythonReader(t *testing.T) {
	b, err := os.ReadFile("testdata/pace-cases.json")
	if err != nil {
		t.Fatal(err)
	}
	var f struct {
		Cases []struct {
			Name, Kind, ResetMode, Pace string
			Used                        float64
			ResetsInMinutes             *int
		}
	}
	if err := json.Unmarshal(b, &f); err != nil || len(f.Cases) == 0 {
		t.Fatalf("cases: %v", err)
	}
	for _, c := range f.Cases {
		mode := c.ResetMode
		if mode == "" {
			mode = "fixed"
		}
		used := c.Used
		w := Window{Kind: c.Kind, UsedPercent: &used, ResetMode: mode, ObservedAt: now}
		if c.ResetsInMinutes != nil {
			r := now.Add(time.Duration(*c.ResetsInMinutes) * time.Minute)
			w.ResetsAt = &r
		}
		evalWindow(&w, now)
		if w.Pace != c.Pace {
			t.Errorf("%s: pace %s, want %s", c.Name, w.Pace, c.Pace)
		}
	}
}

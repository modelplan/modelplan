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
	for _, leak := range []string{"secret", "/home/u", "transcript", "session", "sk-should", "ignore previous", "please do not"} {
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

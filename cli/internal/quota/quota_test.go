package quota

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
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
			ObservedMinutesAgo          int
			Recent                      [][]float64
			Rate                        *float64
			RunsOut                     *int
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
		obs := now.Add(-time.Duration(c.ObservedMinutesAgo) * time.Minute)
		w := Window{Kind: c.Kind, UsedPercent: &used, ResetMode: mode, ObservedAt: obs}
		if c.ResetsInMinutes != nil {
			r := now.Add(time.Duration(*c.ResetsInMinutes) * time.Minute)
			w.ResetsAt = &r
		}
		for _, x := range c.Recent {
			s := Sample{At: obs.Add(-time.Duration(x[0]) * time.Minute), Used: x[1]}
			if w.ResetsAt != nil {
				r := *w.ResetsAt
				if len(x) > 2 {
					r = r.Add(time.Duration(x[2]) * time.Minute)
				}
				s.ResetsAt = &r
			}
			w.addSample(s)
		}
		evalWindow(&w, now)
		if w.Pace != c.Pace {
			t.Errorf("%s: pace %s, want %s", c.Name, w.Pace, c.Pace)
		}
		if c.Recent != nil && (fmt.Sprint(deref(w.RecentPercentPerHour)) != fmt.Sprint(deref(c.Rate)) || fmt.Sprint(deref(w.RunsOutInMinutes)) != fmt.Sprint(deref(c.RunsOut))) {
			t.Errorf("%s: rate %v runs out %v, want %v %v", c.Name, deref(w.RecentPercentPerHour), deref(w.RunsOutInMinutes), deref(c.Rate), deref(c.RunsOut))
		}
	}
}

func TestDeclaredGenerationAndRecordedEndpoint(t *testing.T) {
	dir := t.TempDir()
	local := filepath.Join(dir, "local.json")
	os.WriteFile(local, []byte(`{"schemaVersion":1,"plans":[{"planId":"zhipu-global-pro","generation":"legacy-v2"},{"planId":"kiro-pro"}]}`), 0o600)
	as, st := readLocal(local, now)
	if st.Status != "ok" || len(as) != 2 || as[0].Generation != "legacy-v2" || as[1].Generation != "" {
		t.Fatalf("%s %+v", st.Status, as)
	}
	os.WriteFile(local, []byte(`{"schemaVersion":1,"plans":[{"planId":"zhipu-global-pro","generation":"legacy v2!"}]}`), 0o600)
	if _, st := readLocal(local, now); st.Status != "invalid" {
		t.Fatalf("bad generation: %s", st.Status)
	}
	in := StatuslineInput{Endpoint: "https://api.z.ai/api/anthropic"}
	in.Model.ID = "glm-5.3[1m]"
	if a := in.Account(now); a.Harness.Endpoint != "https://api.z.ai/api/anthropic" || a.Harness.Model != "glm-5.3[1m]" {
		t.Fatalf("endpoint = %q", a.Harness.Endpoint)
	}
	in.Endpoint = "https://api.z.ai/x?token=secret"
	if a := in.Account(now); a.Harness.Endpoint != "" {
		t.Fatalf("an unreduced URL was kept: %q", a.Harness.Endpoint)
	}
}

func TestDeclarePlanKeepsTheRestOfLocalJSON(t *testing.T) {
	dir := t.TempDir()
	local := filepath.Join(dir, "cfg", "local.json")
	if err := DeclarePlan(local, "zhipu-global-pro", "legacy-v2", false); err != nil {
		t.Fatal(err)
	}
	as, st := readLocal(local, now)
	if st.Status != "ok" || len(as) != 1 || as[0].Generation != "legacy-v2" {
		t.Fatalf("%s %+v", st.Status, as)
	}
	os.WriteFile(local, []byte(`{"schemaVersion":1,"plans":[{"planId":"zhipu-global-pro","generation":"legacy-v2","harnesses":["claude-code"]}],"resetCards":[{"planId":"kiro-pro","kind":"weekly","count":2}],"note":12.50}`), 0o600)
	if err := DeclarePlan(local, "zhipu-global-pro", "credits-2026", false); err != nil {
		t.Fatal(err)
	}
	b, _ := os.ReadFile(local)
	for _, want := range []string{`"generation": "credits-2026"`, `"harnesses": [`, `"resetCards": [`, `"note": 12.50`} {
		if !strings.Contains(string(b), want) {
			t.Fatalf("missing %s in %s", want, b)
		}
	}
	if err := DeclarePlan(local, "zhipu-global-pro", "", true); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(local); strings.Contains(string(b), "zhipu-global-pro") || !strings.Contains(string(b), "kiro-pro") {
		t.Fatalf("after remove: %s", b)
	}
	os.WriteFile(local, []byte(`{not json`), 0o600)
	if err := DeclarePlan(local, "zhipu-global-pro", "", false); err == nil {
		t.Fatal("overwrote a file it could not read")
	}
	if err := DeclarePlan(local, "../etc", "", false); err == nil {
		t.Fatal("accepted a bad plan id")
	}
}

func deref[T any](p *T) any {
	if p == nil {
		return nil
	}
	return *p
}

// The status line keeps the last hour of readings in the snapshot, so a burst shows as a recent
// rate and a run-out time; a new cycle starts the history again.
func TestClaudeCodeSnapshotKeepsTheRecentRate(t *testing.T) {
	cache := t.TempDir()
	reset := now.Add(200 * time.Minute).Unix()
	rec := func(used float64, at time.Time, resetAt int64) {
		var in StatuslineInput
		in.Model.ID = "claude-opus-5-5"
		json.Unmarshal([]byte(`{"rate_limits":{"five_hour":{"used_percentage":`+fmt.Sprint(used)+`,"resets_at":`+fmt.Sprint(resetAt)+`}}}`), &in)
		if err := RecordClaudeCode(cache, in, at); err != nil {
			t.Fatal(err)
		}
	}
	read := func(at time.Time) Window {
		as, _ := readClaudeCode(cache, "")
		Evaluate(&as[0], at)
		return as[0].Windows[0]
	}
	for i, used := range []float64{20, 21, 23, 24, 26, 27, 29, 30} {
		rec(used, now.Add(time.Duration(i*3-21)*time.Minute), reset) // every 3 minutes, up to now
	}
	w := read(now)
	if w.RecentPercentPerHour == nil || *w.RecentPercentPerHour != 28.6 || w.RunsOutInMinutes == nil || *w.RunsOutInMinutes != 147 || w.Pace != "tight" {
		t.Fatalf("burst = rate %v, out %v, pace %s", deref(w.RecentPercentPerHour), deref(w.RunsOutInMinutes), w.Pace)
	}
	// The window restarted: earlier readings belong to the previous cycle.
	rec(2, now.Add(time.Minute), now.Add(300*time.Minute).Unix())
	if w := read(now.Add(time.Minute)); w.RecentPercentPerHour != nil {
		t.Fatalf("after a reset = %v", deref(w.RecentPercentPerHour))
	}
	snap, _ := os.ReadFile(snapshotPath(cache))
	if strings.Contains(string(snap), `"used": 20`) {
		t.Fatalf("previous cycle kept:\n%s", snap)
	}
}

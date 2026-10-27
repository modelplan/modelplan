package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// tree records every file and directory under root with its content and modification time.
func tree(t *testing.T, root string) map[string]string {
	t.Helper()
	out := map[string]string{}
	err := filepath.WalkDir(root, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		fi, err := d.Info()
		if err != nil {
			return err
		}
		v := fmt.Sprintf("%v %d", fi.Mode(), fi.ModTime().UnixNano())
		if !d.IsDir() {
			b, err := os.ReadFile(p)
			if err != nil {
				return err
			}
			v += fmt.Sprintf(" %x", sha256.Sum256(b))
		}
		out[p] = v
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	return out
}

func TestDesktopReadOnlyWritesNothing(t *testing.T) {
	isolateHome(t)
	root := t.TempDir()
	codex := filepath.Join(root, "codex")
	t.Setenv("MODELPLAN_CACHE", filepath.Join(root, "cache"))
	t.Setenv("HOME", filepath.Join(root, "home"))
	t.Setenv("CODEX_HOME", codex)
	for _, k := range []string{"CODEX_THREAD_ID", "CLAUDE_CODE_SESSION_ID", "MODELPLAN_HISTORY", "MODELPLAN_CODEXBAR", "MODELPLAN_CODEX_ACCOUNT", "ANTHROPIC_BASE_URL"} {
		t.Setenv(k, "")
	}
	var started []string
	defer func(f func(...string) error) { startDetached = f }(startDetached)
	startDetached = func(args ...string) error { started = append(started, strings.Join(args, " ")); return nil }

	now := time.Now().UTC()
	// A Codex thread and a Claude Code status line, neither reporting an effort.
	day := now.Format("2006/01/02")
	if err := os.MkdirAll(filepath.Join(codex, "sessions", day), 0o755); err != nil {
		t.Fatal(err)
	}
	ts := func(m int) string { return now.Add(time.Duration(m) * time.Minute).Format(time.RFC3339) }
	rollout := strings.Join([]string{
		`{"timestamp":"` + ts(-20) + `","type":"session_meta","payload":{"id":"t","originator":"codex_cli_rs"}}`,
		`{"timestamp":"` + ts(-19) + `","type":"turn_context","payload":{"model":"gpt-6-sol"}}`,
		`{"timestamp":"` + ts(-18) + `","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"limit_id":"codex","primary":{"used_percent":20,"window_minutes":300,"resets_at":` +
			fmt.Sprint(now.Add(2*time.Hour).Unix()) + `},"plan_type":"plus"}}}`,
	}, "\n") + "\n"
	if err := os.WriteFile(filepath.Join(codex, "sessions", day, "rollout-"+now.Format("2006-01-02T15-04-05")+"-t.jsonl"), []byte(rollout), 0o644); err != nil {
		t.Fatal(err)
	}
	line := `{"session_id":"s","model":{"id":"claude-opus-5-5"},"rate_limits":{"five_hour":{"used_percentage":30,"resets_at":` + fmt.Sprint(now.Add(time.Hour).Unix()) + `}}}`
	if code := run([]string{"statusline", "--record-only", "--offline"}, strings.NewReader(line), io.Discard, io.Discard); code != 0 {
		t.Fatalf("statusline exit %d", code)
	}

	before, started := tree(t, root), nil
	var outs []map[string]any
	for i := 0; i < 2; i++ {
		var out bytes.Buffer
		if code := run([]string{"desktop", "--json", "--read-only"}, nil, &out, io.Discard); code != 0 {
			t.Fatalf("desktop --read-only exit %d", code)
		}
		var s map[string]any
		if err := json.Unmarshal(out.Bytes(), &s); err != nil {
			t.Fatal(err)
		}
		outs = append(outs, s)
	}
	after := tree(t, root)
	for p, v := range after {
		if before[p] != v {
			t.Errorf("read-only changed %s", p)
		}
	}
	for p := range before {
		if _, ok := after[p]; !ok {
			t.Errorf("read-only removed %s", p)
		}
	}
	if len(started) != 0 {
		t.Errorf("read-only started %v", started)
	}
	if outs[0]["dataRevision"] == "" || outs[0]["dataRevision"] != outs[1]["dataRevision"] {
		t.Errorf("dataRevision %v then %v", outs[0]["dataRevision"], outs[1]["dataRevision"])
	}
	sessions, _ := outs[0]["sessions"].([]any)
	if len(sessions) != 2 {
		t.Fatalf("sessions = %v", sessions)
	}
	for _, x := range sessions {
		s := x.(map[string]any)
		if s["effortStatus"] != "unreported" {
			t.Errorf("%v: effortStatus = %v", s["source"], s["effortStatus"])
		}
	}

	// The collecting form still refreshes, through the same seam.
	if code := run([]string{"desktop", "--json"}, nil, io.Discard, io.Discard); code != 0 {
		t.Fatalf("desktop exit %d", code)
	}
	if len(started) == 0 {
		t.Error("the default desktop starts its background sync")
	}
	// It also starts both ledgers behind daily[] and dailyLong[], which the snapshot then covers.
	for _, f := range []string{"perf.json", "daily-long.json"} {
		if _, err := os.Stat(filepath.Join(root, "cache", "observed", f)); err != nil {
			t.Errorf("%s: %v", f, err)
		}
	}
	var out bytes.Buffer
	run([]string{"desktop", "--json", "--read-only"}, nil, &out, io.Discard)
	var s map[string]any
	_ = json.Unmarshal(out.Bytes(), &s)
	c, _ := s["dailyLongCoverage"].(map[string]any)
	if _, ok := s["dailyLong"].([]any); !ok || c["from"] != now.Local().Format("2006-01-02") || c["recording"] != true {
		t.Errorf("dailyLong = %v, coverage = %v", s["dailyLong"], c)
	}
}

func TestDesktopReadOnlyCreatesNoCache(t *testing.T) {
	isolateHome(t)
	root := t.TempDir()
	cache := filepath.Join(root, "cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	t.Setenv("HOME", filepath.Join(root, "home"))
	t.Setenv("CODEX_HOME", filepath.Join(root, "codex"))
	if code := run([]string{"desktop", "--json", "--read-only"}, nil, io.Discard, io.Discard); code != 0 {
		t.Fatalf("exit %d", code)
	}
	if _, err := os.Stat(root + "/cache"); !os.IsNotExist(err) {
		t.Errorf("read-only created the cache: %v", err)
	}
}

func TestProjectLabelsCommand(t *testing.T) {
	isolateHome(t)
	root := t.TempDir()
	t.Setenv("MODELPLAN_CACHE", filepath.Join(root, "cache"))
	t.Setenv("HOME", filepath.Join(root, "home"))
	t.Setenv("CODEX_HOME", filepath.Join(root, "codex"))
	state := func(args ...string) any {
		var out bytes.Buffer
		if code := run(append([]string{"project-labels", "--json"}, args...), nil, &out, io.Discard); code != 0 {
			t.Fatalf("project-labels %v: exit %d", args, code)
		}
		var v map[string]any
		_ = json.Unmarshal(out.Bytes(), &v)
		return v["projectLabels"]
	}
	snapshot := func() map[string]any {
		var out bytes.Buffer
		run([]string{"desktop", "--json", "--read-only"}, nil, &out, io.Discard)
		var s map[string]any
		_ = json.Unmarshal(out.Bytes(), &s)
		return s
	}
	// On by default: no choice is stored, and asking does not store one.
	if s := snapshot(); s["projectLabels"] != true || s["projectRanking"] == nil || state() != true {
		t.Fatalf("default: snapshot projectLabels = %v", s["projectLabels"])
	}
	if _, err := os.Stat(filepath.Join(root, "home", ".config", "modelplan", "project-labels.json")); !os.IsNotExist(err) {
		t.Fatalf("status stored a choice: %v", err)
	}
	// An explicit off is kept.
	if state("off") != false || state() != false || snapshot()["projectLabels"] != false {
		t.Fatal("off is remembered")
	}
	if state("on") != true || state() != true || snapshot()["projectLabels"] != true {
		t.Fatal("on is remembered")
	}
	var text bytes.Buffer
	run([]string{"project-labels", "--lang", "en"}, nil, &text, io.Discard)
	if !strings.Contains(text.String(), "stay on this machine") {
		t.Errorf("status = %q", text.String())
	}
	if code := run([]string{"project-labels", "maybe"}, nil, io.Discard, io.Discard); code != exitUsage {
		t.Fatal("unknown subcommand is a usage error")
	}
}

func TestConnectCommands(t *testing.T) {
	isolateHome(t)
	root := t.TempDir()
	t.Setenv("MODELPLAN_CACHE", filepath.Join(root, "cache"))
	t.Setenv("HOME", filepath.Join(root, "home"))
	t.Setenv("CODEX_HOME", filepath.Join(root, "codex"))
	t.Setenv("Z_AI_API_KEY", "")
	var started [][]string
	old := startDetached
	startDetached = func(args ...string) error { started = append(started, args); return nil }
	t.Cleanup(func() { startDetached = old })
	list := func() []map[string]any {
		var out bytes.Buffer
		if code := run([]string{"connections", "--json"}, nil, &out, io.Discard); code != 0 {
			t.Fatalf("connections exit %d", code)
		}
		var v struct{ Connections []map[string]any }
		_ = json.Unmarshal(out.Bytes(), &v)
		return v.Connections
	}
	if len(list()) != 0 {
		t.Fatal("nothing connected yet")
	}
	if code := run([]string{"connect", "zai", "--region", "bigmodel-cn"}, strings.NewReader("yes\n"), io.Discard, io.Discard); code != 0 {
		t.Fatalf("connect exit %d", code)
	}
	c := list()
	if len(c) != 1 || c[0]["backend"] != "native" || c[0]["region"] != "bigmodel-cn" || c[0]["keyEnv"] != "Z_AI_API_KEY" || c[0]["blocked"] != "no-key" {
		t.Fatalf("connections = %v", c)
	}
	if len(started) != 0 {
		t.Fatalf("started = %v", started)
	}
	if code := run([]string{"connect", "cursor"}, strings.NewReader("yes\n"), io.Discard, io.Discard); code != 0 {
		t.Fatal("cursor native connect failed")
	}
	if code := run([]string{"connect", "cursor", "--backend", "codexbar"}, strings.NewReader("yes\n"), io.Discard, io.Discard); code != exitUsage {
		t.Fatal("unaudited cursor helper accepted")
	}
	if code := run([]string{"disconnect", "zai"}, nil, io.Discard, io.Discard); code != 0 {
		t.Fatal("disconnect")
	}
	got := map[string]any{}
	for _, x := range list() {
		got[x["provider"].(string)] = x["backend"]
	}
	if got["zai"] != "off" || got["cursor"] != "native" {
		t.Fatalf("after disconnect = %v", got)
	}
	// codexbar enable cannot quietly override an explicit entry: it says which one decides.
	var errOut bytes.Buffer
	run([]string{"codexbar", "enable", "zai"}, nil, io.Discard, &errOut)
	if !strings.Contains(errOut.String(), "zai is set to off in connections.json") {
		t.Fatalf("stderr = %q", errOut.String())
	}
}

package main

import (
	"bytes"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/localusage"
)

func TestGeminiUsageAndReadOnlySnapshot(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "cache"))
	t.Setenv("CODEX_HOME", filepath.Join(home, "codex"))
	t.Setenv("MODELPLAN_GEMINI_HOME", "")
	t.Setenv("MODELPLAN_GEMINI", "")
	t.Setenv("MODELPLAN_HISTORY", "")
	old := startDetached
	defer func() { startDetached = old }()
	startDetached = func(...string) error { t.Fatal("local usage started a process"); return nil }
	read := func(args ...string) map[string]any {
		t.Helper()
		var out bytes.Buffer
		if code := run(args, nil, &out, io.Discard); code != 0 {
			t.Fatalf("%v: %d %s", args, code, out.String())
		}
		var m map[string]any
		if json.Unmarshal(out.Bytes(), &m) != nil {
			t.Fatal(out.String())
		}
		return m
	}
	if r := read("usage", "gemini", "--json"); r["status"] != "off" {
		t.Fatal(r)
	}
	read("usage", "gemini", "enable", "--json")
	chats := filepath.Join(home, ".gemini", "tmp", "project-private", "chats")
	if err := os.MkdirAll(chats, 0700); err != nil {
		t.Fatal(err)
	}
	body := `{"sessionId":"private-session","projectHash":"private-project","messages":[{"id":"private-message","type":"gemini","timestamp":"` + time.Now().UTC().Add(-time.Minute).Format(time.RFC3339) + `","model":"gemini-test","tokens":{"output":123},"content":"private response"}]}`
	if err := os.WriteFile(filepath.Join(chats, "session-synthetic.json"), []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	r := read("usage", "gemini", "--json")
	if r["status"] != "ok" || len(r["rows"].([]any)) != 1 {
		t.Fatal(r)
	}
	var out bytes.Buffer
	if run([]string{"usage", "gemini", "--lang", "en"}, nil, &out, io.Discard) != 0 || !strings.Contains(out.String(), "--") || !strings.Contains(out.String(), "123") {
		t.Fatal(out.String())
	}
	cfg := read("connections", "--json")
	if len(cfg["localUsage"].([]any)) != 1 {
		t.Fatal(cfg)
	}
	before := tree(t, home)
	s := read("desktop", "--read-only", "--json")
	if len(s["localUsage"].([]any)) != 1 || len(s["accounts"].([]any)) != 0 {
		t.Fatal("local history turned into quota")
	}
	if !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("read-only local usage wrote files")
	}
	read("usage", "gemini", "disable", "--json")
	if r := read("usage", "gemini", "--json"); r["status"] != "off" {
		t.Fatal(r)
	}
	if _, err := os.Stat(localusage.SettingsPath(home)); err != nil {
		t.Fatal(err)
	}
}

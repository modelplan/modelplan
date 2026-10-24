package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestQwenUsageCLI(t *testing.T) {
	isolateHome(t)
	root := t.TempDir()
	t.Setenv("MODELPLAN_CACHE", filepath.Join(root, "cache"))
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(root, "config"))
	t.Setenv("MODELPLAN_QWEN_USAGE_EXPORT", "")
	file := filepath.Join(root, "export.json")
	b := `{"period":"day","value":"2026-01-02","generatedAt":"2026-01-03T10:00:00Z","totals":{"outputTokens":0},"byModel":[{"key":"qwen3-coder","outputTokens":0}]}`
	if e := os.WriteFile(file, []byte(b), 0600); e != nil {
		t.Fatal(e)
	}
	var out bytes.Buffer
	if code := run([]string{"qwen-usage", "--export", file, "--json"}, nil, &out, &out); code != 0 {
		t.Fatal(code, out.String())
	}
	var r map[string]any
	if json.Unmarshal(out.Bytes(), &r) != nil || r["status"] != "ok" {
		t.Fatal(out.String())
	}
	out.Reset()
	run([]string{"qwen-usage", "--lang", "en"}, nil, &out, &out)
	if !strings.Contains(out.String(), "off") {
		t.Fatal(out.String())
	}
	t.Setenv("MODELPLAN_QWEN_USAGE_EXPORT", file)
	out.Reset()
	run([]string{"connections", "--offline", "--json"}, nil, &out, &out)
	if !strings.Contains(out.String(), file) || !strings.Contains(out.String(), `"network": "none"`) {
		t.Fatal(out.String())
	}
	// Read-only desktop adds usage without recording or inventing quota accounts.
	out.Reset()
	if code := run([]string{"desktop", "--read-only", "--offline"}, nil, &out, &out); code != 0 {
		t.Fatal(code, out.String())
	}
	if json.Unmarshal(out.Bytes(), &r) != nil || r["qwenUsage"] == nil || r["schemaVersion"] != float64(1) {
		t.Fatal(out.String())
	}
	if strings.Contains(out.String(), `"source": "qwen-code"`) {
		t.Fatal("invented a Qwen quota account")
	}
	after, _ := os.ReadFile(file)
	if string(after) != b {
		t.Fatal("export changed")
	}
}

func TestQwenAutomaticLocalUsage(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	t.Setenv("MODELPLAN_QWEN_HOME", "")
	t.Setenv("MODELPLAN_QWEN", "")
	t.Setenv("MODELPLAN_HISTORY", "")
	t.Setenv("MODELPLAN_QWEN_USAGE_EXPORT", "")
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "cache"))
	old := startDetached
	defer func() { startDetached = old }()
	startDetached = func(...string) error { t.Fatal("Qwen local reader launched a process"); return nil }
	read := func(args ...string) map[string]any {
		t.Helper()
		var out bytes.Buffer
		if code := run(args, nil, &out, &out); code != 0 {
			t.Fatal(code, out.String())
		}
		var r map[string]any
		if e := json.Unmarshal(out.Bytes(), &r); e != nil {
			t.Fatal(e, out.String())
		}
		return r
	}
	if r := read("usage", "qwen", "--json"); r["status"] != "off" {
		t.Fatal(r)
	}
	read("usage", "qwen", "enable", "--json")
	chats := filepath.Join(home, ".qwen", "projects", "synthetic-project", "chats")
	if e := os.MkdirAll(chats, 0700); e != nil {
		t.Fatal(e)
	}
	b := `{"uuid":"private-message","sessionId":"private-session","cwd":"/private/project","timestamp":"` + time.Now().Add(-time.Minute).UTC().Format(time.RFC3339) + `","type":"assistant","model":"qwen-synthetic","usageMetadata":{"candidatesTokenCount":42},"message":{"parts":[{"text":"PRIVATE"}]}}` + "\n"
	file := filepath.Join(chats, "synthetic.jsonl")
	if e := os.WriteFile(file, []byte(b), 0600); e != nil {
		t.Fatal(e)
	}
	r := read("usage", "qwen", "--json")
	if r["status"] != "ok" || len(r["rows"].([]any)) != 1 {
		t.Fatal(r)
	}
	before := tree(t, home)
	snapshot := read("desktop", "--read-only", "--offline", "--json")
	if len(snapshot["localUsage"].([]any)) != 2 || len(snapshot["accounts"].([]any)) != 0 || snapshot["qwenUsage"] != nil {
		t.Fatal("local Qwen became quota/export", snapshot)
	}
	if !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("read-only Qwen wrote files")
	}
	cfg := read("connections", "--json")
	if len(cfg["localUsage"].([]any)) != 2 {
		t.Fatal(cfg)
	}
	after, _ := os.ReadFile(file)
	if string(after) != b {
		t.Fatal("rewrote Qwen history")
	}
	read("usage", "qwen", "disable", "--json")
	if r := read("usage", "qwen", "--json"); r["status"] != "off" {
		t.Fatal(r)
	}
}

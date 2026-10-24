package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
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

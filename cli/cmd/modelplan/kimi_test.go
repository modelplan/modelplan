package main

import (
	"bytes"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestKimiDocumentedOnlyBoundary(t *testing.T) {
	root := t.TempDir()
	t.Setenv("HOME", root)
	t.Setenv("MODELPLAN_CACHE", filepath.Join(root, "cache"))
	t.Setenv("KIMI_API_KEY", "synthetic-key-must-not-be-printed")
	old := startDetached
	defer func() { startDetached = old }()
	startDetached = func(...string) error { t.Fatal("unsupported connection started a process"); return nil }
	for _, args := range [][]string{
		{"connect", "kimi", "--lang", "en"},
		{"connect", "kimi", "--backend", "codexbar", "--lang", "en"},
		{"connect", "kimi", "--region", "global", "--key-env", "KIMI_API_KEY", "--lang", "en"},
		{"connect", "kimi", "--region", "china", "--lang", "zh"},
	} {
		var errOut bytes.Buffer
		code := run(args, nil, io.Discard, &errOut)
		if code != exitUsage || !strings.Contains(errOut.String(), "docs/kimi-code-quota.md") || strings.Contains(errOut.String(), "synthetic-key") {
			t.Fatalf("%v: %d %s", args, code, errOut.String())
		}
	}
	// No enabled provider/secret is persisted, even when the supplied variable exists.
	if _, err := os.Stat(filepath.Join(root, ".config", "modelplan", "connections.json")); !os.IsNotExist(err) {
		t.Fatalf("created a connection: %v", err)
	}
}

// SPDX-License-Identifier: MIT
package toolcli

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func putExecutable(t *testing.T, path, body string) {
	t.Helper()
	if e := os.MkdirAll(filepath.Dir(path), 0700); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(path, []byte(body), 0700); e != nil {
		t.Fatal(e)
	}
}

func TestNodeScriptUnderMinimalGUIPath(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
	bin := filepath.Join(home, ".npm-global", "bin", "fake tool")
	putExecutable(t, bin, "#!/usr/bin/env node\nprintf '%s\\n' \"$1\" \"$2\"\n")
	marker := filepath.Join(home, "node-called")
	t.Setenv("GUI_RUNTIME_MARKER", marker)
	putExecutable(t, filepath.Join(filepath.Dir(bin), "node"), "#!/bin/sh\nprintf called > \"$GUI_RUNTIME_MARKER\"\nexec /bin/sh \"$@\"\n")
	cmd, err := CommandContext(context.Background(), bin, "argument with spaces", "$(must-stay-literal)")
	if err != nil {
		t.Fatal(err)
	}
	out, err := cmd.Output()
	if err != nil || string(out) != "argument with spaces\n$(must-stay-literal)\n" {
		t.Fatalf("output=%s err=%v", out, err)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatal("runtime was not invoked", err)
	}
}

func TestRuntimeMissingIsDistinctAndDoesNotStartScript(t *testing.T) {
	bin := filepath.Join(t.TempDir(), "cli")
	putExecutable(t, bin, "#!/usr/bin/env node\nexit 1\n")
	old := resolveNode
	resolveNode = func(string, string) string { return "" }
	t.Cleanup(func() { resolveNode = old })
	cmd, err := CommandContext(context.Background(), bin, "app-server")
	if cmd != nil || !errors.Is(err, ErrRuntimeMissing) || !strings.Contains(err.Error(), RuntimeMissing) || !strings.Contains(err.Error(), "Install Node.js") {
		t.Fatal(cmd, err)
	}
}

func TestNodeLocationsAndNumericNVMOrdering(t *testing.T) {
	home := t.TempDir()
	script := filepath.Join(home, ".npm-global", "bin", "codex")
	dirs := []string{filepath.Dir(script), "/opt/homebrew/bin", "/usr/local/bin", filepath.Join(home, ".nvm", "versions", "node", "v22.10.0", "bin"), filepath.Join(home, ".nvm", "versions", "node", "v22.9.0", "bin"), filepath.Join(home, ".volta", "bin"), filepath.Join(home, ".local", "bin"), filepath.Join(home, ".bun", "bin")}
	for _, d := range dirs[3:5] {
		if err := os.MkdirAll(d, 0700); err != nil {
			t.Fatal(err)
		}
	}
	noPath := func(string) (string, error) { return "", os.ErrNotExist }
	for i, wantDir := range dirs {
		have := map[string]bool{}
		for _, d := range dirs[i:] {
			have[filepath.Join(d, "node")] = true
		}
		got := locateNode(home, script, noPath, func(p string) bool { return have[p] })
		if want := filepath.Join(wantDir, "node"); got != want {
			t.Fatalf("candidate %d: got %s want %s", i, got, want)
		}
	}
	bun := filepath.Join(home, ".bun", "bin", "bun")
	if got := locateNode(home, script, noPath, func(p string) bool { return p == bun }); got != bun {
		t.Fatalf("bun fallback=%s", got)
	}
	if got := locateNode(home, script, noPath, func(string) bool { return false }); got != "" {
		t.Fatalf("missing=%s", got)
	}
}

func TestFinderIncludesUserPackageBins(t *testing.T) {
	t.Setenv("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
	for _, dir := range []string{".npm-global/bin", ".volta/bin", ".bun/bin"} {
		t.Run(dir, func(t *testing.T) {
			home := t.TempDir()
			bin := filepath.Join(home, dir, "synthetic-gui-tool")
			putExecutable(t, bin, "#!/bin/sh\nexit 0\n")
			if got := Find(home, "synthetic-gui-tool"); got != bin {
				t.Fatalf("got=%s want=%s", got, bin)
			}
		})
	}
}

func TestShebangRecognitionAndNativeLaunch(t *testing.T) {
	for _, tc := range []struct {
		line string
		want bool
	}{{"#!/usr/bin/env node\n", true}, {"#!/usr/bin/env -S node\r\n", true}, {"#!/bin/sh\n", false}, {"#!/usr/bin/env node-bogus\n", false}, {"#!/usr/bin/env FOO=bar node\n", false}} {
		if got := EnvNode(strings.NewReader(tc.line)); got != tc.want {
			t.Fatalf("%q=%t", tc.line, got)
		}
	}
	old := resolveNode
	resolveNode = func(string, string) string { t.Fatal("looked up node for a native/shell binary"); return "" }
	t.Cleanup(func() { resolveNode = old })
	bin := filepath.Join(t.TempDir(), "native")
	putExecutable(t, bin, "#!/bin/sh\nprintf unchanged\n")
	cmd, err := CommandContext(context.Background(), bin)
	if err != nil {
		t.Fatal(err)
	}
	out, err := cmd.Output()
	if err != nil || string(out) != "unchanged" {
		t.Fatal(string(out), err)
	}
}

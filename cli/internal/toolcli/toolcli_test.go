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
	noPath := ""
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

// G3 owner report 2026-11-26: the ChatGPT app's private node was first on the
// login PATH. It is skipped, and the user's own ~/.local/bin/node later on PATH wins.
func TestNodeOnPathSkipsOtherAppsBundledRuntime(t *testing.T) {
	home := t.TempDir()
	bundled := "/Applications/ChatGPT.app/Contents/Resources"
	local := filepath.Join(home, ".local", "bin")
	script := filepath.Join(home, "tools", "codex")
	have := map[string]bool{filepath.Join(bundled, "node"): true, filepath.Join(local, "node"): true}
	exists := func(p string) bool { return have[p] }
	path := strings.Join([]string{bundled, "/usr/bin", local}, string(os.PathListSeparator))
	if got, want := locateNode(home, script, path, exists), filepath.Join(local, "node"); got != want {
		t.Fatalf("PATH walk: got %s want %s", got, want)
	}
	// Only the bundled runtime on PATH: no node at all, rather than borrowing it.
	delete(have, filepath.Join(local, "node"))
	if got := locateNode(home, script, bundled, exists); got != "" {
		t.Fatalf("used another app's bundled node: %s", got)
	}
	// Launchd PATH (Mac app engine): the user-local install is still found by the fallback folders.
	have[filepath.Join(local, "node")] = true
	if got, want := locateNode(home, script, "/usr/bin:/bin:/usr/sbin:/sbin", exists), filepath.Join(local, "node"); got != want {
		t.Fatalf("fallback: got %s want %s", got, want)
	}
	// Version managers and pnpm are fallback folders too.
	for _, d := range []string{filepath.Join(home, ".asdf", "shims"), filepath.Join(home, "Library", "pnpm"), filepath.Join(home, ".local", "share", "fnm", "aliases", "default", "bin")} {
		if got := locateNode(home, script, "", func(p string) bool { return p == filepath.Join(d, "node") }); got != filepath.Join(d, "node") {
			t.Fatalf("fallback %s: got %s", d, got)
		}
	}
}

// macrev2-1272-1: a dotted spelling of a bundle folder on PATH, or a symlink in an
// ordinary bin folder (on PATH or a fallback) to another app's node or bun, is
// still that app's runtime and is skipped; the tool's own adjacent runtime stays.
func TestForeignBundledRuntimeSkippedWhateverItsSpelling(t *testing.T) {
	root := t.TempDir()
	home := filepath.Join(root, "home")
	res := filepath.Join(root, "Synthetic.app", "Contents", "Resources")
	alias := filepath.Join(root, "alias")
	local := filepath.Join(home, ".local", "bin")
	for _, d := range []string{res, alias, local, filepath.Join(home, ".bun", "bin")} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	file := func(p string) {
		if err := os.WriteFile(p, []byte("#!/bin/sh\n"), 0o755); err != nil {
			t.Fatal(err)
		}
	}
	link := func(target, p string) {
		if err := os.Symlink(target, p); err != nil {
			t.Fatal(err)
		}
	}
	file(filepath.Join(res, "node"))
	file(filepath.Join(res, "bun"))
	link(filepath.Join(res, "node"), filepath.Join(alias, "node"))
	link(filepath.Join(res, "bun"), filepath.Join(alias, "bun"))
	// macrev2-1272-2: discovery sees only the fixture, so a host node or bun in
	// /usr/local/bin or /opt/homebrew/bin cannot answer; the bundle check itself
	// still runs Clean and EvalSymlinks on the real files.
	fixture := func(p string) bool { return strings.HasPrefix(p, root+string(filepath.Separator)) && executable(p) }
	script := filepath.Join(root, "tools", "codex")
	sep := string(os.PathListSeparator)
	dotted := filepath.Join(root, "Synthetic.app") + "/./Contents/Resources"
	for name, path := range map[string]string{"direct": res, "dotted": dotted, "symlink": alias, "all": res + sep + dotted + sep + alias} {
		if got := locateNode(home, script, path, fixture); got != "" {
			t.Fatalf("%s: selected foreign runtime %s", name, got)
		}
	}
	// A fallback folder holding a symlink to the foreign runtime is skipped too; the real user node wins.
	link(filepath.Join(res, "node"), filepath.Join(home, ".bun", "bin", "node"))
	link(filepath.Join(res, "bun"), filepath.Join(home, ".bun", "bin", "bun"))
	if got := locateNode(home, script, alias, fixture); got != "" {
		t.Fatalf("fallback symlink: selected %s", got)
	}
	file(filepath.Join(local, "node"))
	if got, want := locateNode(home, script, dotted+sep+alias, fixture), filepath.Join(local, "node"); got != want {
		t.Fatalf("user node: got %s want %s", got, want)
	}
	// The tool's own adjacent runtime is still used, even inside an app bundle.
	own := filepath.Join(res, "codex")
	file(own)
	if got, want := locateNode(home, own, alias, fixture), filepath.Join(res, "node"); got != want {
		t.Fatalf("adjacent: got %s want %s", got, want)
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

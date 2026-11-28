// SPDX-License-Identifier: MIT
package toolcli

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// fakeAppTool puts an executable kiro-cli inside a fake application bundle and returns its path.
func fakeAppTool(t *testing.T, root, bundle, inner string) string {
	t.Helper()
	p := filepath.Join(root, bundle, filepath.FromSlash(inner))
	putExecutable(t, p, "#!/bin/sh\necho ran\n")
	return p
}

// Owner build-6 #14: a tool found only inside another app's bundle is refused, on PATH, in the
// usual install folders, as an extra fallback and through a symlink, whatever its letter case.
func TestLookupRefusesToolsInsideAppBundles(t *testing.T) {
	root := t.TempDir()
	home := t.TempDir()
	t.Setenv("HOME", home)
	ide := fakeAppTool(t, root, "Kiro.app", "Contents/Resources/app/bin/kiro-cli")
	cli := fakeAppTool(t, root, "Kiro CLI.APP", "contents/MacOS/kiro-cli")
	t.Setenv("PATH", filepath.Dir(ide)+string(os.PathListSeparator)+filepath.Dir(cli))
	if p, err := Lookup(home, "kiro-cli", ide, cli); p != "" || !errors.Is(err, ErrInsideAppBundle) {
		t.Fatalf("Lookup = %q, %v; want refusal", p, err)
	}
	// A user-local link that resolves into the bundle (an installer's ~/.local/bin link).
	link := filepath.Join(home, ".local", "bin", "kiro-cli")
	if err := os.MkdirAll(filepath.Dir(link), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(cli, link); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", "/usr/bin:/bin")
	if p := Find(home, "kiro-cli"); p != "" {
		t.Fatalf("Find returned a bundle binary through a link: %q", p)
	}
	// A standalone install later in the search still wins.
	standalone := filepath.Join(home, "bin", "kiro-cli")
	putExecutable(t, standalone, "#!/bin/sh\necho ran\n")
	if p, err := Lookup(home, "kiro-cli"); p != standalone || err != nil {
		t.Fatalf("Lookup = %q, %v; want %q", p, err, standalone)
	}
	// Nothing installed at all is not a refusal.
	if p, err := Lookup(t.TempDir(), "no-such-tool"); p != "" || err != nil {
		t.Fatalf("missing tool = %q, %v", p, err)
	}
}

// Every entry point that starts a program refuses one inside another app's bundle, before
// anything runs, and a symlink outside the bundle does not hide it.
func TestCommandRefusesProgramsInsideAppBundles(t *testing.T) {
	root := t.TempDir()
	bin := fakeAppTool(t, root, "Codex.app", "Contents/Resources/codex")
	link := filepath.Join(root, "codex")
	if err := os.Symlink(bin, link); err != nil {
		t.Fatal(err)
	}
	for _, p := range []string{bin, link, filepath.Join(root, "Codex.app", "Contents", "..", "Contents", "Resources", "codex")} {
		if _, err := Command(context.Background(), p, "app-server"); !errors.Is(err, ErrInsideAppBundle) {
			t.Fatalf("Command(%s) err = %v", p, err)
		}
		if _, err := CommandContext(context.Background(), p, "app-server"); !errors.Is(err, ErrInsideAppBundle) {
			t.Fatalf("CommandContext(%s) err = %v", p, err)
		}
		if _, err := NodeCommandContext(context.Background(), p, p); !errors.Is(err, ErrInsideAppBundle) {
			t.Fatalf("NodeCommandContext(%s) err = %v", p, err)
		}
	}
	// Bare names are checked at the file PATH resolves them to.
	t.Setenv("PATH", filepath.Dir(bin))
	if _, err := Command(context.Background(), "codex"); !errors.Is(err, ErrInsideAppBundle) {
		t.Fatalf("bare name through PATH err = %v", err)
	}
	// A program outside any bundle is allowed.
	free := filepath.Join(root, "bin", "tool")
	putExecutable(t, free, "#!/bin/sh\nexit 0\n")
	if _, err := Command(context.Background(), free); err != nil {
		t.Fatalf("plain program refused: %v", err)
	}
}

// ModelPlan's own bundle is not another app: the Mac app's engine may run its own binaries.
func TestOwnBundleIsNotAnotherApp(t *testing.T) {
	root := t.TempDir()
	own := filepath.Join(root, "ModelPlan.app")
	old := ownBundle
	t.Cleanup(func() { ownBundle = old })
	ownBundle = func() string { return bundleRoot(filepath.Join(own, "Contents", "MacOS", "modelplan")) }
	helper := fakeAppTool(t, root, "ModelPlan.app", "Contents/Helpers/Engine.app/Contents/MacOS/engine")
	if InsideOtherApp(helper) {
		t.Fatal("own nested helper treated as another app")
	}
	if !InsideOtherApp(fakeAppTool(t, root, "ModelPlan Helper.app", "Contents/MacOS/x")) {
		t.Fatal("a sibling app with a prefix-sharing name was treated as ModelPlan")
	}
}

// The invariant holds only if nothing starts a program around this package. Every exec site
// under cli/ goes through toolcli, except ModelPlan re-running itself (detach) and developer
// tooling that never ships in a reader.
func TestNoExecSiteBypassesToolcli(t *testing.T) {
	allowed := map[string]string{
		"internal/detach/detach_unix.go":   "re-runs ModelPlan's own executable, detached by design",
		"internal/detach/detach_other.go":  "re-runs ModelPlan's own executable, detached by design",
		"internal/appcontract/generate.go": "developer contract generator (go build, the built CLI)",
		"internal/testenv/home.go":         "test environment helper (go env)",
	}
	execCall := regexp.MustCompile(`\bexec\.Command(Context)?\(|\bos\.StartProcess\(|\bsyscall\.(Exec|ForkExec|StartProcess)\(`)
	bundleLiteral := regexp.MustCompile(`(?i)\.app/Contents/`)
	usesToolcli := regexp.MustCompile(`\btoolcli\.(Command|CommandContext|NodeCommandContext)\(`)
	directLifecycle := regexp.MustCompile(`\bcmd\.(Start|Run|Output|CombinedOutput|Wait)\(`)
	cliRoot, err := filepath.Abs(filepath.Join("..", ".."))
	if err != nil {
		t.Fatal(err)
	}
	err = filepath.WalkDir(cliRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() && (d.Name() == "testdata" || d.Name() == "vendor") {
			return filepath.SkipDir
		}
		if d.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		rel, _ := filepath.Rel(cliRoot, path)
		rel = filepath.ToSlash(rel)
		if strings.HasPrefix(rel, "internal/toolcli/") {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if _, ok := allowed[rel]; !ok && execCall.Match(b) {
			t.Errorf("%s starts a program without toolcli.Command (bundle guard and process-group cleanup)", rel)
		}
		if usesToolcli.Match(b) && directLifecycle.Match(b) {
			t.Errorf("%s starts or waits on a toolcli command directly; use toolcli.Start/Run/Finish so tagged descendants are stopped", rel)
		}
		if bundleLiteral.Match(b) {
			t.Errorf("%s names a path inside an app bundle; ModelPlan never runs programs there", rel)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

// Owner decision D487 (2026-11-28): the desktop apps' own Codex CLI, at exactly its place, may run;
// any other program in those bundles, a lookalike path or a link that leaves the bundle may not.
func TestCodexAppCLIIsTheOneBundleException(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	for _, inner := range []string{"ChatGPT.app/Contents/Resources/codex", "ChatGPT.app/Contents/Resources/codex-cli/bin/codex", "Codex.app/Contents/Resources/codex"} {
		parts := strings.SplitN(inner, "/", 2)
		bin := fakeAppTool(t, filepath.Join(home, "Applications"), parts[0], parts[1])
		if _, err := Command(context.Background(), bin, "--version"); err != nil {
			t.Fatalf("Command(%s) refused: %v", bin, err)
		}
		if _, err := CommandContext(context.Background(), bin, "app-server"); err != nil {
			t.Fatalf("CommandContext(%s) refused: %v", bin, err)
		}
	}
	apps := filepath.Join(home, "Applications")
	other := fakeAppTool(t, apps, "ChatGPT.app", "Contents/Resources/helper")
	dotted := apps + "/ChatGPT.app/Contents/../Contents/Resources/codex" // spelled unclean on purpose
	outside := filepath.Join(t.TempDir(), "codex")
	putExecutable(t, outside, "#!/bin/sh\nexit 0\n")
	escape := filepath.Join(apps, "Codex.app", "Contents", "Resources", "codex")
	if err := os.Remove(escape); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, escape); err != nil {
		t.Fatal(err)
	}
	elsewhere := fakeAppTool(t, t.TempDir(), "ChatGPT.app", "Contents/Resources/codex")
	for _, p := range []string{other, dotted, escape, elsewhere} {
		if _, err := Command(context.Background(), p, "app-server"); !errors.Is(err, ErrInsideAppBundle) {
			t.Fatalf("Command(%s) err = %v, want refusal", p, err)
		}
	}
}

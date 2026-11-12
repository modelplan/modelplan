// SPDX-License-Identifier: MIT
package profile_test

import (
	"io/fs"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/profile"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func under(t *testing.T, root, path, name string) {
	t.Helper()
	rel, err := filepath.Rel(root, path)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) || filepath.IsAbs(rel) {
		t.Errorf("%s resolves outside the profile root: %s", name, path)
	}
}

// D164: with a fresh-profile root every ModelPlan store resolves under it, and
// MODELPLAN_CACHE cannot pull the cache back out.
func TestEveryEngineStoreResolvesUnderTheProfileRoot(t *testing.T) {
	testenv.IsolateHome(t)
	home, _ := os.UserHomeDir()
	root := t.TempDir()
	t.Setenv(profile.RootEnv, root)
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "elsewhere"))
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	p := quota.ProductionPaths(st.Dir, "test")
	stores := map[string]string{
		"store":          st.Dir,
		"consent":        consent.Path(),
		"consent lock":   consent.Path() + ".lock",
		"reader lock":    consent.Path() + ".readers.lock",
		"declared quota": p.LocalFile,
		"codexbar":       p.CodexBarFile,
		"connections":    p.ConnectionsFile,
		"cache (quota)":  p.Cache,
		"local usage":    localusage.SettingsPath(home),
		"project labels": speed.ProjectLabelsFile(home),
		"config folder":  profile.ConfigDir(home),
	}
	for name, path := range stores {
		under(t, root, path, name)
	}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	for _, real := range []string{filepath.Join(home, ".config"), filepath.Join(home, "Library"), filepath.Join(home, ".cache"), filepath.Join(home, "elsewhere")} {
		if _, err := os.Stat(real); !os.IsNotExist(err) {
			t.Errorf("fresh profile wrote into the real profile: %s", real)
		}
	}
}

func TestDefaultsWithoutARoot(t *testing.T) {
	testenv.IsolateHome(t)
	home, _ := os.UserHomeDir()
	t.Setenv(profile.RootEnv, "")
	os.Unsetenv(profile.RootEnv) // unset, not empty: t.Setenv restores it afterwards
	if got, want := consent.Path(), filepath.Join(home, ".config", "modelplan", "consent.json"); got != want {
		t.Fatalf("consent path %s, want %s", got, want)
	}
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "cache"))
	if dir, err := profile.CacheDir(); err != nil || dir != filepath.Join(home, "cache") {
		t.Fatalf("MODELPLAN_CACHE no longer honoured: %s %v", dir, err)
	}
}

func TestRelativeRootIsRefused(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv(profile.RootEnv, "relative/profile")
	if profile.Check() == nil {
		t.Fatal("relative root admitted")
	}
	if _, err := store.Locate(); err == nil {
		t.Fatal("store located under a relative root")
	}
}

// Every ModelPlan config or cache path goes through this package; a new store
// that joins ~/.config/modelplan or the user cache folder itself would escape
// a fresh profile.
func TestNoStoreBypassesTheResolver(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	cli := filepath.Join(filepath.Dir(file), "..", "..")
	allowed := map[string]bool{
		filepath.Join("internal", "profile", "profile.go"): true,
		// The contract generator builds its own synthetic HOME and reads the store it seeded.
		filepath.Join("internal", "appcontract", "retired_consent.go"): true,
	}
	err := filepath.WalkDir(cli, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() && d.Name() == "testdata" {
			return filepath.SkipDir
		}
		if d.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		rel, _ := filepath.Rel(cli, path)
		if allowed[rel] {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		text := string(b)
		for _, needle := range []string{`".config", "modelplan"`, "os.UserCacheDir(", "os.UserConfigDir("} {
			if strings.Contains(text, needle) {
				t.Errorf("%s uses %s; resolve ModelPlan state through internal/profile", rel, needle)
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

// macrevc-861-1: a key that is present but empty is refused, never read as "unset".
func TestEmptyPresentRootIsRefused(t *testing.T) {
	testenv.IsolateHome(t)
	home, _ := os.UserHomeDir()
	t.Setenv(profile.RootEnv, "")
	if profile.Check() == nil {
		t.Fatal("empty root admitted")
	}
	if _, err := store.Locate(); err == nil {
		t.Fatal("store located under an empty root")
	}
	if strings.HasPrefix(consent.Path(), filepath.Join(home, ".config")) {
		t.Fatalf("empty root fell back to the real config: %s", consent.Path())
	}
}

// macrevc-861-2: a store folder or file inside the root that is a symlink could lead back
// into the real profile; such a root is refused.
func TestLinkedStoreInsideTheRootIsRefused(t *testing.T) {
	testenv.IsolateHome(t)
	home, _ := os.UserHomeDir()
	realConfig := filepath.Join(home, ".config", "modelplan")
	if err := os.MkdirAll(realConfig, 0o700); err != nil {
		t.Fatal(err)
	}
	for _, link := range []string{"engine", filepath.Join("engine", "config"), filepath.Join("engine", "cache"), filepath.Join("engine", "config", "consent.json")} {
		root := t.TempDir()
		if err := os.MkdirAll(filepath.Dir(filepath.Join(root, link)), 0o700); err != nil {
			t.Fatal(err)
		}
		if err := os.Symlink(realConfig, filepath.Join(root, link)); err != nil {
			t.Fatal(err)
		}
		t.Setenv(profile.RootEnv, root)
		if profile.Check() == nil {
			t.Errorf("root with linked %s admitted", link)
		}
		if _, err := store.Locate(); err == nil {
			t.Errorf("store located in a root with linked %s", link)
		}
	}
}

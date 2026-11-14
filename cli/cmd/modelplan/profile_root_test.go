// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/profile"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// macrevc-861-1/2 through the real command entry: an empty, relative or linked root
// exits before any store is touched, and the real profile stays empty.
func TestUnusableProfileRootStopsBeforeAnyStore(t *testing.T) {
	testenv.IsolateHome(t)
	home, _ := os.UserHomeDir()
	linked := t.TempDir()
	if err := os.Symlink(filepath.Join(home, ".config"), filepath.Join(linked, "engine")); err != nil {
		t.Fatal(err)
	}
	for _, value := range []string{"", "relative/profile", linked} {
		t.Setenv(profile.RootEnv, value)
		var out, errOut bytes.Buffer
		if code := run([]string{"consent", "--json"}, strings.NewReader(""), &out, &errOut); code != exitUsage {
			t.Errorf("root %q: exit %d, want %d (%s)", value, code, exitUsage, errOut.String())
		}
		for _, real := range []string{".config", "Library", ".cache"} {
			if _, err := os.Stat(filepath.Join(home, real)); !os.IsNotExist(err) {
				t.Errorf("root %q wrote the real profile: %s", value, real)
			}
		}
	}
}

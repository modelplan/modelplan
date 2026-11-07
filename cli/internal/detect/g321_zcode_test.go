// SPDX-License-Identifier: MIT
package detect

import (
	"os"
	"path/filepath"
	"testing"
)

// G3-21: ZCode installed as the zcode-app-cli package under a host's own layout
// (~/.local/share/zcode-community, a `zcode-cli` launcher) or as ZCode Desktop was not
// detected. Synthetic homes only; detection stats paths and never reads them.
func TestG321ZCodeLayoutsAreDetected(t *testing.T) {
	zai := func(t *testing.T, e Env) Tool {
		t.Helper()
		for _, tool := range Run(Fallback(), e, "1.0.0", "built-in").Tools {
			if tool.ProviderID == "zai" {
				return tool
			}
		}
		t.Fatal("no ZCode detector")
		return Tool{}
	}
	for _, tc := range []struct{ name, dir, command string }{
		{"community package data", ".local/share/zcode-community/settings", ""},
		{"community launcher only", "", "zcode-cli"},
		{"desktop app support", "Library/Application Support/ZCode", ""},
		{"standard home", ".zcode/cli", ""},
	} {
		t.Run(tc.name, func(t *testing.T) {
			home := t.TempDir()
			bin := filepath.Join(home, "bin")
			if err := os.MkdirAll(bin, 0o700); err != nil {
				t.Fatal(err)
			}
			if tc.dir != "" {
				if err := os.MkdirAll(filepath.Join(home, filepath.FromSlash(tc.dir)), 0o700); err != nil {
					t.Fatal(err)
				}
			}
			if tc.command != "" {
				if err := os.WriteFile(filepath.Join(bin, tc.command), []byte("#!/bin/sh\n"), 0o700); err != nil {
					t.Fatal(err)
				}
			}
			if tool := zai(t, Env{Home: home, Path: bin, OS: "darwin"}); !tool.Detected {
				t.Fatalf("ZCode not detected: %s", tool.Status)
			}
		})
	}
	if tool := zai(t, Env{Home: t.TempDir(), Path: t.TempDir(), OS: "darwin"}); tool.Detected {
		t.Fatal("ZCode detected on an empty home")
	}
}

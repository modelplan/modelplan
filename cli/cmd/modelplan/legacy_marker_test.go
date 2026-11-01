// SPDX-License-Identifier: MIT
package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestFreshLegacyMarkerBlocksHistoryErasure(t *testing.T) {
	for _, name := range []string{"speed.lock", "perf.lock"} {
		t.Run(name, func(t *testing.T) {
			home, cache := t.TempDir(), t.TempDir()
			t.Setenv("HOME", home)
			t.Setenv("USERPROFILE", home)
			dir := filepath.Join(cache, "observed")
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			path := filepath.Join(dir, "perf.json")
			if err := os.WriteFile(path, []byte(`{"rows":[{"source":"codex"},{"source":"claude-code"}]}`), 0600); err != nil {
				t.Fatal(err)
			}
			marker := filepath.Join(dir, name)
			if err := os.WriteFile(marker, nil, 0600); err != nil {
				t.Fatal(err)
			}
			erase := func() error {
				return quota.EraseScope(quota.Paths{Cache: cache}, consent.ScopeCodexLocalHistory, false)
			}
			if err := erase(); err == nil {
				t.Fatal("cleanup ignored fresh legacy marker")
			}
			b, err := os.ReadFile(path)
			if err != nil || !strings.Contains(string(b), `"source":"codex"`) {
				t.Fatal("busy cleanup changed ledger", err)
			}
			if err := os.Remove(marker); err != nil {
				t.Fatal(err)
			}
			if err := erase(); err != nil {
				t.Fatal("cleanup did not resume", err)
			}
			b, err = os.ReadFile(path)
			if err != nil || strings.Contains(string(b), `"source":"codex"`) || !strings.Contains(string(b), `"source":"claude-code"`) {
				t.Fatalf("bad cleanup: %s %v", b, err)
			}
		})
	}
}

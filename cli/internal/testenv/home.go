// Package testenv isolates test-owned files while keeping Go's shared caches.
package testenv

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"testing"
)

var shared struct {
	sync.Once
	paths map[string]string
	err   error
}

// IsolateHome must run before a test changes HOME. Resolve the caller's real Go
// cache paths once, before replacing HOME, so subprocesses such as go list do
// not download modules/build caches into a temporary test home. t.Setenv restores
// each setting and t.TempDir removes the home even when a test fails.
func IsolateHome(t *testing.T) {
	t.Helper()
	// Go's test-only telemetry override prevents subprocess counter/report writers
	// from racing with TempDir cleanup. Never alter the user's Go telemetry mode.
	telemetry := t.TempDir()
	if err := os.WriteFile(filepath.Join(telemetry, "mode"), []byte("off\n"), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("TEST_TELEMETRY_DIR", telemetry)
	shared.Do(func() {
		var b []byte
		b, shared.err = exec.Command("go", "env", "-json", "GOMODCACHE", "GOCACHE", "GOPATH").Output()
		if shared.err == nil {
			shared.err = json.Unmarshal(b, &shared.paths)
		}
	})
	if shared.err != nil {
		t.Fatalf("resolve shared Go caches: %v", shared.err)
	}
	for _, key := range []string{"GOMODCACHE", "GOCACHE", "GOPATH"} {
		path := shared.paths[key]
		if !filepath.IsAbs(path) {
			t.Fatalf("%s must resolve to an absolute shared path", key)
		}
		t.Setenv(key, path)
	}
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	t.Setenv("CODEX_HOME", filepath.Join(home, ".codex"))
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	t.Setenv("XDG_DATA_HOME", filepath.Join(home, ".local", "share"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, ".cache"))
}

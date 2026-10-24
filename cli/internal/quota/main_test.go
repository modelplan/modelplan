package quota

import (
	"os"
	"os/exec"
	"strings"
	"testing"
)

// TestMain keeps every test away from the real home directory: Claude Code's account file and the
// harness logs are read from $HOME.
func TestMain(m *testing.M) {
	// Keep subprocess Go builds on the real shared caches before isolating HOME.
	// TestMain cannot use t.TempDir; this suite-wide home is explicitly removed below.
	for _, name := range []string{"GOMODCACHE", "GOCACHE", "GOPATH"} {
		if os.Getenv(name) != "" {
			continue
		}
		value, err := exec.Command("go", "env", name).Output()
		if err != nil {
			panic("cannot resolve shared Go cache: " + name)
		}
		os.Setenv(name, strings.TrimSpace(string(value)))
	}

	home, err := os.MkdirTemp("", "modelplan-home-")
	if err != nil {
		panic(err)
	}
	os.Setenv("HOME", home)
	os.Unsetenv("CLAUDE_CONFIG_DIR")
	code := m.Run()
	os.RemoveAll(home)
	os.Exit(code)
}

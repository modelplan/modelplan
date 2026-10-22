package quota

import (
	"os"
	"testing"
)

// TestMain keeps every test away from the real home directory: Claude Code's account file and the
// harness logs are read from $HOME.
func TestMain(m *testing.M) {
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

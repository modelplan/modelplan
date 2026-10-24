package testenv

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestHomeCleanupAndSharedGoCaches(t *testing.T) {
	var home string
	t.Run("isolated", func(t *testing.T) {
		IsolateHome(t)
		home = os.Getenv("HOME")
		if err := os.WriteFile(filepath.Join(home, "test-owned"), []byte("fixture"), 0600); err != nil {
			t.Fatal(err)
		}
		b, err := exec.Command("go", "env", "-json", "GOMODCACHE", "GOCACHE", "GOPATH").Output()
		if err != nil {
			t.Fatal(err)
		}
		var paths map[string]string
		if err = json.Unmarshal(b, &paths); err != nil {
			t.Fatal(err)
		}
		for key, path := range paths {
			if path != shared.paths[key] || strings.HasPrefix(path, home+string(filepath.Separator)) {
				t.Fatalf("%s did not use shared cache: %s", key, path)
			}
		}
	})
	if _, err := os.Stat(home); !os.IsNotExist(err) {
		t.Fatalf("temporary home was not cleaned: %v", err)
	}
}

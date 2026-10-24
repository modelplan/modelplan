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
	var home, telemetry string
	t.Run("isolated", func(t *testing.T) {
		IsolateHome(t)
		home = os.Getenv("HOME")
		telemetry = os.Getenv("TEST_TELEMETRY_DIR")
		if err := os.WriteFile(filepath.Join(home, "test-owned"), []byte("fixture"), 0600); err != nil {
			t.Fatal(err)
		}
		b, err := exec.Command("go", "env", "-json", "GOMODCACHE", "GOCACHE", "GOPATH", "GOTELEMETRY", "GOTELEMETRYDIR").Output()
		if err != nil {
			t.Fatal(err)
		}
		var paths map[string]string
		if err = json.Unmarshal(b, &paths); err != nil {
			t.Fatal(err)
		}
		for _, key := range []string{"GOMODCACHE", "GOCACHE", "GOPATH"} {
			path := paths[key]
			if path != shared.paths[key] || strings.HasPrefix(path, home+string(filepath.Separator)) {
				t.Fatalf("%s did not use shared cache: %s", key, path)
			}
		}
		if paths["GOTELEMETRY"] != "off" || paths["GOTELEMETRYDIR"] != telemetry {
			t.Fatalf("Go subprocess telemetry not isolated/off: %v", paths)
		}
		entries, err := os.ReadDir(telemetry)
		if err != nil || len(entries) != 1 || entries[0].Name() != "mode" {
			t.Fatalf("unexpected telemetry writes: %v %v", entries, err)
		}
	})
	if _, err := os.Stat(home); !os.IsNotExist(err) {
		t.Fatalf("temporary home was not cleaned: %v", err)
	}
	if _, err := os.Stat(telemetry); !os.IsNotExist(err) {
		t.Fatalf("temporary telemetry directory was not cleaned: %v", err)
	}
}

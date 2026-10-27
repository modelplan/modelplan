package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/plugininstall"
)

func TestPluginInstallMissingHostPrintsCommandsWithoutCache(t *testing.T) {
	isolateHome(t)
	t.Setenv("PATH", t.TempDir())
	cache := filepath.Join(t.TempDir(), "absent")
	t.Setenv("MODELPLAN_CACHE", cache)
	var out, stderr bytes.Buffer
	code := run([]string{"plugin", "install", "claude-code", "--json"}, nil, &out, &stderr)
	var result plugininstall.Result
	if code != 0 || stderr.Len() != 0 || json.Unmarshal(out.Bytes(), &result) != nil || result.Status != "instructions" || len(result.Commands) != 2 {
		t.Fatalf("missing host: exit=%d stdout=%s stderr=%s", code, out.String(), stderr.String())
	}
	if _, err := os.Stat(cache); !os.IsNotExist(err) {
		t.Fatalf("plugin command created cache: %v", err)
	}
}

func TestPluginInstallExecutesFixtureHostAndOfflineDoesNot(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("POSIX fixture host")
	}
	isolateHome(t)
	bin := t.TempDir()
	calls := filepath.Join(t.TempDir(), "calls")
	t.Setenv("FIXTURE_INSTALL_CALLS", calls)
	if err := os.WriteFile(filepath.Join(bin, "codex"), []byte("#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$FIXTURE_INSTALL_CALLS\"\n"), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("PATH", bin)
	var out, stderr bytes.Buffer
	if code := run([]string{"plugin", "install", "codex", "--offline", "--json"}, nil, &out, &stderr); code != 0 || !strings.Contains(out.String(), `"status": "planned"`) {
		t.Fatalf("offline plan: %d %s %s", code, out.String(), stderr.String())
	}
	if _, err := os.Stat(calls); !os.IsNotExist(err) {
		t.Fatalf("offline invoked host: %v", err)
	}
	out.Reset()
	if code := run([]string{"plugin", "install", "codex", "--json"}, nil, &out, &stderr); code != 0 || !json.Valid(out.Bytes()) || !strings.Contains(out.String(), `"status": "installed"`) {
		t.Fatalf("install: %d %s %s", code, out.String(), stderr.String())
	}
	b, err := os.ReadFile(calls)
	if err != nil || string(b) != "plugin marketplace add modelplan/modelplan --sparse .agents --sparse codex\nplugin add modelplan-codex@modelplan\n" {
		t.Fatalf("wrong commands: %q %v", b, err)
	}
}

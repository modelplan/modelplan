// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestShareAndFlagErrorsRealBinaryAreCopySafe(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	build := exec.Command("go", "build", "-o", binary, ".")
	if b, err := build.CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, b)
	}
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "config"))
	t.Setenv("XDG_CACHE_HOME", filepath.Join(home, "cache-root"))
	cache := filepath.Join(home, "cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	const user = "SYNTHETIC-USER-958"
	const password = "SYNTHETIC-PASSWORD-452"
	const token = "SYNTHETIC-TOKEN-a67"
	const poison = "https://" + user + ":" + password + "@example.invalid/path?token=" + token
	t.Setenv("MODELPLAN_BASE", poison)
	t.Setenv("MODELPLAN_LANG", "SYNTHETIC-LANG-SECRET")
	canaries := []string{user, password, token, "SYNTHETIC-LANG-SECRET", "person.synthetic@example.invalid", "SYNTHETIC-LOCAL-SECRET"}
	run := func(args ...string) (string, int) {
		t.Helper()
		cmd := exec.Command(binary, args...)
		out, err := cmd.CombinedOutput()
		exit := 0
		if err != nil {
			e, ok := err.(*exec.ExitError)
			if !ok {
				t.Fatalf("launch: %v", err)
			}
			exit = e.ExitCode()
		}
		for _, c := range canaries {
			if strings.Contains(string(out), c) {
				t.Errorf("%v exposed canary in output", args)
			}
		}
		return string(out), exit
	}
	for _, tc := range []struct {
		args []string
		exit int
	}{
		{[]string{"diagnostics", "--share", "--bad-flag"}, 2},
		{[]string{"diagnostics", "--share", "--app-version"}, 2},
		{[]string{"diagnostics", "--share=person.synthetic@example.invalid"}, 2},
		{[]string{"diagnostics", "--share", "-h"}, 0},
		{[]string{"diagnostics", "--share", "--help"}, 0},
		{[]string{"version", "--bad-flag"}, 2},
		{[]string{"version", "-h"}, 2},
		{[]string{"version", "--help"}, 2},
		{[]string{"version"}, 2}, // invalid base must not be echoed
	} {
		out, exit := run(tc.args...)
		if exit != tc.exit {
			t.Errorf("%v: exit %d want %d; output %q", tc.args, exit, tc.exit, out)
		}
		if tc.args[0] == "version" && len(tc.args) > 1 && !strings.Contains(out, "--base: publication base URL") {
			t.Errorf("missing static usage: %q", out)
		}
	}
	assertJSON := func() {
		t.Helper()
		out, exit := run("diagnostics", "--share")
		if exit != 0 || !json.Valid([]byte(out)) {
			t.Fatalf("report failed: exit %d output %q", exit, out)
		}
	}
	assertJSON() // empty consent and cache
	if err := os.MkdirAll(filepath.Join(cache, "observed"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(cache, "observed", "native.json"), []byte(`{"error":"SYNTHETIC-LOCAL-SECRET`), 0600); err != nil {
		t.Fatal(err)
	}
	assertJSON() // malformed cache
	consentDir := filepath.Join(home, ".config", "modelplan")
	if err := os.MkdirAll(consentDir, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(consentDir, "consent.json"), []byte(`{"error":"SYNTHETIC-LOCAL-SECRET`), 0600); err != nil {
		t.Fatal(err)
	}
	out, exit := run("diagnostics", "--share") // corrupt consent
	var report struct {
		ReaderMode string `json:"readerMode"`
	}
	if exit != 0 || json.Unmarshal([]byte(out), &report) != nil || report.ReaderMode != "unknown" {
		t.Fatalf("corrupt consent did not fail closed: %d %q", exit, out)
	}
	// Old cache state may contain a URL or a saved error from an earlier version.
	if err := os.WriteFile(filepath.Join(cache, "state.json"), []byte(`{"base":"`+poison+`","lastError":"request failed: `+poison+`"}`), 0600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_BASE", "https://example.invalid")
	out, exit = run("doctor")
	if exit != 0 || !strings.Contains(out, "https://example.invalid/path") || !strings.Contains(out, "previous sync failed") {
		t.Fatalf("doctor redaction failed: %d %q", exit, out)
	}
	t.Setenv("MODELPLAN_BASE", poison)
	t.Setenv("HOME", "")
	t.Setenv("XDG_CACHE_HOME", "")
	t.Setenv("MODELPLAN_CACHE", "")
	if out, exit := run("diagnostics", "--share"); exit != 1 || !strings.Contains(out, "cache_unavailable") {
		t.Fatalf("location failure: %d %q", exit, out)
	}
}

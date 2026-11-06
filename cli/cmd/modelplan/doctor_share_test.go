package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDoctorShareDoesNotCreateCacheOrRunReaders(t *testing.T) {
	isolateHome(t)
	cache := filepath.Join(t.TempDir(), "missing-cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	original := startDetached
	t.Cleanup(func() { startDetached = original })
	startDetached = func(...string) error { t.Fatal("share report started a process"); return nil }
	var out, stderr bytes.Buffer
	code := run([]string{"doctor", "--share", "--json", "--base", "https://private:secret@example.invalid/path"}, nil, &out, &stderr)
	if code != 0 || stderr.Len() != 0 || !json.Valid(out.Bytes()) {
		t.Fatalf("share: exit=%d stderr=%s out=%s", code, stderr.String(), out.String())
	}
	for _, hidden := range []string{cache, "private", "secret", "path", "base"} {
		if strings.Contains(out.String(), hidden) {
			t.Fatalf("share leaked %q: %s", hidden, out.String())
		}
	}
	if _, err := os.Stat(cache); !os.IsNotExist(err) {
		t.Fatalf("share created cache: %v", err)
	}
}

func TestDoctorShareIncludesManagedFailureWithoutPrivateDetails(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	t.Setenv("MODELPLAN_CACHE", cache)
	path := filepath.Join(cache, "observed", "readers", "claude.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(`{"schemaVersion":1,"provider":"claude","entries":[{"status":"error","notice":"synthetic-secret","profileKey":"synthetic-private"}]}`), 0600); err != nil {
		t.Fatal(err)
	}
	var out, stderr bytes.Buffer
	if code := run([]string{"doctor", "--share", "--json"}, nil, &out, &stderr); code != 0 {
		t.Fatalf("doctor share: %d %s", code, stderr.String())
	}
	var report struct {
		Sources []struct{ Source, Status string } `json:"sources"`
	}
	if err := json.Unmarshal(out.Bytes(), &report); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, source := range report.Sources {
		found = found || source.Source == "native:claude" && source.Status == "error"
	}
	if !found || strings.Contains(out.String(), "synthetic-secret") || strings.Contains(out.String(), "synthetic-private") {
		t.Fatalf("unexpected share result: %s", out.String())
	}
}

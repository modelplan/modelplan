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

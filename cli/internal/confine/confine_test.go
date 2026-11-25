// SPDX-License-Identifier: MIT
package confine

import (
	"io"
	"os"
	"path/filepath"
	"testing"
)

// macrevb-1222-4: after any earlier check, an ancestor swapped for a symlink out of the root
// makes the open fail; nothing outside the root is opened. A file still below the root opens.
func TestOpenRefusesAnAncestorSwappedOutOfTheRoot(t *testing.T) {
	base := t.TempDir()
	root := filepath.Join(base, "sessions")
	day := filepath.Join(root, "2026", "11", "24")
	path := filepath.Join(day, "rollout.jsonl")
	if err := os.MkdirAll(day, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("inside\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	f, err := Open(root, path)
	if err != nil {
		t.Fatalf("a file below the root: %v", err)
	}
	b, _ := io.ReadAll(f)
	f.Close()
	if string(b) != "inside\n" {
		t.Fatalf("read %q", b)
	}
	// The swap happens after the caller's check: the month moves out, a symlink takes its place.
	outside := filepath.Join(base, "outside")
	if err := os.Rename(filepath.Join(root, "2026", "11"), outside); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(outside, "24", "rollout.jsonl"), []byte("outside\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "2026", "11")); err != nil {
		t.Skipf("symlinks unavailable: %v", err)
	}
	if f, err := Open(root, path); err == nil {
		b, _ := io.ReadAll(f)
		f.Close()
		t.Fatalf("opened through an ancestor swapped out of the root: %q", b)
	}
	if f, err := OpenUnder([]string{root}, path); err == nil {
		f.Close()
		t.Fatal("OpenUnder followed the swapped ancestor")
	}
	// A final component that is a symlink out of the root is refused too.
	if err := os.Remove(filepath.Join(root, "2026", "11")); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(day, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(outside, "24", "rollout.jsonl"), path); err != nil {
		t.Fatal(err)
	}
	if f, err := Open(root, path); err == nil {
		f.Close()
		t.Fatal("opened a final symlink out of the root")
	}
	if _, err := Open(root, filepath.Join(base, "elsewhere.jsonl")); err != ErrOutside {
		t.Fatalf("a path outside the root: %v", err)
	}
	if err := os.Mkdir(filepath.Join(day, "dir.jsonl"), 0o700); err != nil {
		t.Fatal(err)
	}
	if _, err := Open(root, filepath.Join(day, "dir.jsonl")); err != ErrNotRegular {
		t.Fatalf("a directory: %v", err)
	}
}

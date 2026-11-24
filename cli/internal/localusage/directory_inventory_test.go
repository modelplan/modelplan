// SPDX-License-Identifier: MIT
package localusage

import (
	"errors"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestDirectoryInventoryOnlyEnumeratesChangedDirectory(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "config"))
	t.Setenv("MODELPLAN_READERS", consent.Automatic)
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	admission := consent.Capture()
	left, right := filepath.Join(home, "left"), filepath.Join(home, "right")
	before := time.Unix(1100, 0)
	for _, dir := range []string{left, right} {
		if err := os.Mkdir(dir, 0700); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(dir, before, before); err != nil {
			t.Fatal(err)
		}
	}
	calls := map[string]int{}
	inventory := DirectoryInventory{readDir: func(dir string) ([]os.DirEntry, error) {
		calls[dir]++
		return os.ReadDir(dir)
	}}
	for offset := range 5 {
		read := inventory.ForAdmission(admission, before.Add(time.Duration(offset)*time.Second))
		for _, dir := range []string{left, right} {
			if _, err := read(dir); err != nil {
				t.Fatal(err)
			}
		}
	}
	if calls[left] != 1 || calls[right] != 1 {
		t.Fatalf("idle inventories enumerated: %v", calls)
	}
	if err := os.WriteFile(filepath.Join(left, "new.jsonl"), []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}
	read := inventory.ForAdmission(admission, before.Add(6*time.Second))
	if entries, err := read(left); err != nil || len(entries) != 1 {
		t.Fatalf("left directory missed the new log: %v, %v", entries, err)
	}
	if _, err := read(right); err != nil {
		t.Fatal(err)
	}
	if calls[left] != 2 || calls[right] != 1 {
		t.Fatalf("unaffected inventory was enumerated: %v", calls)
	}
	if err := os.Remove(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if _, err := read(left); !errors.Is(err, os.ErrPermission) || len(inventory.dirs) != 0 {
		t.Fatalf("withdrawn consent left a directory accessible: %v", err)
	}
}

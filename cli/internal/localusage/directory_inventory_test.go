// SPDX-License-Identifier: MIT
package localusage

import (
	"errors"
	"fmt"
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

func TestDirectoryInventoryBoundsStableOverflowAndRevisitsChangedDirectory(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, "config"))
	t.Setenv("MODELPLAN_READERS", consent.Automatic)
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	admission := consent.Capture()
	dirs := make([]string, directoryInventoryLimit+88)
	calls := 0
	inventory := DirectoryInventory{readDir: func(dir string) ([]os.DirEntry, error) {
		calls++
		return os.ReadDir(dir)
	}}
	now := time.Unix(1200, 0)
	for i := range dirs {
		dirs[i] = filepath.Join(home, fmt.Sprintf("history-%03d", i))
		if err := os.Mkdir(dirs[i], 0700); err != nil {
			t.Fatal(err)
		}
		// The fixture exceeds both the directory and total name limits.
		for j := range 9 {
			if err := os.WriteFile(filepath.Join(dirs[i], fmt.Sprintf("record-%d.jsonl", j)), []byte("{}"), 0600); err != nil {
				t.Fatal(err)
			}
		}
		if err := os.Chtimes(dirs[i], now, now); err != nil {
			t.Fatal(err)
		}
	}
	for pass := range 16 {
		at := now.Add(time.Duration(pass) * 6 * time.Second)
		read := inventory.ForAdmission(admission, at)
		calls = 0
		for _, dir := range dirs {
			if _, err := read(dir); err != nil {
				t.Fatal(err)
			}
		}
		if pass == 0 && calls != len(dirs) {
			t.Fatalf("first discovery omitted directories: %d", calls)
		}
		if pass > 0 && calls > 16 {
			t.Fatalf("stable overflow exceeded the fixed reconciliation budget: pass %d enumerated %d directories", pass, calls)
		}
	}
	last := dirs[len(dirs)-1]
	newFile := filepath.Join(last, "new.jsonl")
	if err := os.WriteFile(newFile, []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}
	for pass := 16; pass < 36; pass++ {
		at := now.Add(time.Duration(pass) * 6 * time.Second)
		// These first cold directories compete in every pass. The new log
		// in the last directory must get a turn despite the changing prefix.
		firstCold := directoryListingLimit / 9
		for _, dir := range dirs[firstCold : firstCold+16] {
			if err := os.Chtimes(dir, at, at); err != nil {
				t.Fatal(err)
			}
		}
		read := inventory.ForAdmission(admission, at)
		calls = 0
		found := false
		for _, dir := range dirs {
			names, err := read(dir)
			if err != nil {
				t.Fatal(err)
			}
			if dir == last {
				for _, name := range names {
					found = found || name.Name() == "new.jsonl"
				}
			}
		}
		if calls > 16 {
			t.Fatalf("contended overflow exceeded the fixed reconciliation budget: pass %d enumerated %d directories", pass, calls)
		}
		if found {
			return
		}
	}

	t.Fatal("a new log in the cold inventory was never discovered")
}

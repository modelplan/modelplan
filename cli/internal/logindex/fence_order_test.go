// SPDX-License-Identifier: MIT
package logindex

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// macrev2-1261-2: a call under a fence older than the inventory's (an older generation, or a
// store epoch a newer one replaced) reads nothing and keeps nothing.
func TestOlderFenceIsRefused(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "a.jsonl"), []byte("{}\n"), 0o600)
	now := time.Now()
	roots := []Root{{Dir: dir, Source: "x"}}
	var inv Inventory
	f1, f2 := consent.Fence{StoreEpoch: "e1", Generation: 1}, consent.Fence{StoreEpoch: "e1", Generation: 2}
	if got := inv.Files(f1, roots, now, now); len(got) != 1 {
		t.Fatalf("f1: %v", got)
	}
	inv.Advance(f2)
	if inv.Retained() != 0 {
		t.Fatal("advance kept files")
	}
	if got, gen, _ := inv.FilesIfChanged(f1, roots, now, now, 0); len(got) != 0 || gen != 0 || inv.Retained() != 0 {
		t.Fatalf("older generation read %v (gen %d, %d retained)", got, gen, inv.Retained())
	}
	if got := inv.Files(f2, roots, now, now); len(got) != 1 {
		t.Fatalf("current fence: %v", got)
	}
	e2 := consent.Fence{StoreEpoch: "e2", Generation: 1}
	if got := inv.Files(e2, roots, now, now); len(got) != 1 {
		t.Fatalf("new epoch: %v", got)
	}
	if got, gen, _ := inv.FilesIfChanged(consent.Fence{StoreEpoch: "e1", Generation: 9}, roots, now, now, 0); len(got) != 0 || gen != 0 {
		t.Fatalf("a retired epoch read %v", got)
	}
}

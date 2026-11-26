// SPDX-License-Identifier: MIT
package logindex

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// macrev2-1261-2/-4: a ticket from before a withdrawal reads and commits nothing; fences are never
// ordered or retired, so an epoch read again after another one (or after an empty fence from a
// failed consent read) reads normally under a fresh ticket.
func TestWithdrawalTicket(t *testing.T) {
	dir := t.TempDir()
	os.WriteFile(filepath.Join(dir, "a.jsonl"), []byte("{}\n"), 0o600)
	now := time.Now()
	roots := []Root{{Dir: dir, Source: "x"}}
	var inv Inventory
	a, b := consent.Fence{StoreEpoch: "a", Generation: 1}, consent.Fence{StoreEpoch: "b", Generation: 1}
	stale := inv.Ticket()
	if got, _, _ := inv.FilesIfChanged(a, roots, now, now, 0, stale); len(got) != 1 {
		t.Fatalf("a: %v", got)
	}
	inv.Withdraw(dir)
	if inv.Retained() != 0 {
		t.Fatal("withdraw kept the root")
	}
	if got, gen, _ := inv.FilesIfChanged(a, roots, now, now, 0, stale); len(got) != 0 || gen != 0 || inv.Retained() != 0 {
		t.Fatalf("a stale ticket read %v (gen %d)", got, gen)
	}
	if inv.CommitIf(stale, func() { t.Fatal("a stale commit ran") }) {
		t.Fatal("a stale commit was accepted")
	}
	for _, f := range []consent.Fence{b, {}, a, b, a} {
		if got, _, _ := inv.FilesIfChanged(f, roots, now, now, 0, inv.Ticket()); len(got) != 1 {
			t.Fatalf("fence %v under a fresh ticket read %v", f, got)
		}
	}
	if !inv.CommitIf(inv.Ticket(), func() {}) {
		t.Fatal("a fresh commit was refused")
	}
}

// SPDX-License-Identifier: MIT
package speed

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestEnginePerfMemoReusesLedgerAndDetectsAtomicReplacement(t *testing.T) {
	cache := t.TempDir()
	path := PerfPath(cache)
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	a := admitted(consent.ScopeCodexLocalHistory)
	now := time.Now()
	modified := now.Add(-time.Minute)
	write := func(output int64) {
		t.Helper()
		l := PerfLedger{SchemaVersion: 1, Since: now.Add(-time.Hour), Rows: []PerfRow{
			{GrantEpoch: currentEpoch(*a, "codex"), Source: "codex", Day: day(now), ObservedOutputTokens: output},
		}}
		b, err := json.Marshal(l)
		if err != nil {
			t.Fatal(err)
		}
		tmp := path + ".new"
		if err := os.WriteFile(tmp, b, 0600); err != nil {
			t.Fatal(err)
		}
		if err := os.Chtimes(tmp, modified, modified); err != nil {
			t.Fatal(err)
		}
		if err := os.Rename(tmp, path); err != nil {
			t.Fatal(err)
		}
	}
	var memo PerfReadMemo
	write(11)
	got := memo.Read(cache, *a, now)
	if len(got.Ledger.Rows) != 1 || got.Ledger.Rows[0].ObservedOutputTokens != 11 || !memo.valid {
		t.Fatalf("initial ledger not memoized: %+v", got)
	}
	prior := &memo.ledger.Rows[0]
	_ = memo.Read(cache, *a, now.Add(time.Second))
	if &memo.ledger.Rows[0] != prior {
		t.Fatal("unchanged ledger decoded again")
	}
	write(22)
	got = memo.Read(cache, *a, now)
	if len(got.Ledger.Rows) != 1 || got.Ledger.Rows[0].ObservedOutputTokens != 22 {
		t.Fatalf("same-size same-mtime atomic replacement missed: %+v", got)
	}
	prior = &memo.ledger.Rows[0]
	if err := os.WriteFile(ClearedPath(cache), []byte("{}"), 0600); err != nil {
		t.Fatal(err)
	}
	_ = memo.Read(cache, *a, now)
	if &memo.ledger.Rows[0] == prior {
		t.Fatal("a new history clear watermark must invalidate the accounting memo")
	}
	off := consent.NewAdmission(a.State(), consent.Off)
	if got := memo.Read(cache, off, now); got.OK || memo.valid || len(memo.ledger.Rows) != 0 {
		t.Fatal("memo survived readers-off")
	}
}

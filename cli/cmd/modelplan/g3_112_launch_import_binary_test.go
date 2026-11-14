// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// G3-112, the Swift RealHistoryImportTests flow through the real executable: a history grant
// recorded before launch starts nothing (status idle, first run not done); only a requested and
// unfinished first-run import is retried at launch.
func TestLaunchStartsOnlyARequestedUnfinishedFirstRunImport(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-ldflags", "-X main.version=1.0.0", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, raw)
	}
	for _, requested := range []bool{false, true} {
		t.Run(map[bool]string{false: "grant only", true: "unfinished request"}[requested], func(t *testing.T) {
			home := setupQueryHome(t)
			cstate, err := consent.EnsureStore(consent.Path())
			if err != nil {
				t.Fatal(err)
			}
			hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) { return consent.Record{}, nil }, Cleanup: func(string, bool) error { return nil }}
			if _, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "pre", ExpectStoreEpoch: cstate.StoreEpoch, ExpectGeneration: cstate.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeClaudeLocalHistory}}, hooks); err != nil {
				t.Fatal(err)
			}
			if requested {
				if err := speed.MarkAutoRequested(filepath.Join(home, "cache"), time.Now()); err != nil {
					t.Fatal(err)
				}
			}
			p := startQueryBinary(t, binary)
			status := func() wire.HistoryImportStatus {
				var env wire.Envelope[wire.HistoryImportStatus]
				msg := p.call("history/import_status", map[string]any{})
				if json.Unmarshal(msg["result"], &env) != nil {
					t.Fatalf("status: %s", msg["error"])
				}
				return env.Data
			}
			if !requested {
				time.Sleep(300 * time.Millisecond)
				if st := status(); st.Phase != wire.ImportIdle || st.FirstRunDone {
					t.Fatalf("a grant recorded before launch started an import: %+v", st)
				}
				return
			}
			var st wire.HistoryImportStatus
			for i := 0; i < 200; i++ {
				if st = status(); st.Phase == wire.ImportDone {
					break
				}
				time.Sleep(20 * time.Millisecond)
			}
			if st.Phase != wire.ImportDone || !st.FirstRunDone {
				t.Fatalf("owed first-run import not retried at launch: %+v", st)
			}
		})
	}
}

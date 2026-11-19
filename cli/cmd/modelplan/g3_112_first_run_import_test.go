// SPDX-License-Identifier: MIT
package main

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// glm-967-1: automatic imports (first run, launch or grant retry) read only tools whose history
// scope the user answered with an allow; a default-on scope nobody answered is never read. The
// explicit Import keeps the consent in force.
func TestAutomaticImportReadsOnlyRecordedGrants(t *testing.T) {
	consentFixtureHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache := t.TempDir()
	cstate, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) { return consent.Record{}, nil }, Cleanup: func(string, bool) error { return nil }}
	if _, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "codex", ExpectStoreEpoch: cstate.StoreEpoch, ExpectGeneration: cstate.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCodexLocalHistory}}, hooks); err != nil {
		t.Fatal(err)
	}
	st := &store.Store{Dir: cache}
	auto := importOptions(st, 30, true, time.Now(), automaticImport(nil))
	if auto.Claude != nil || auto.Codex == nil {
		t.Fatalf("automatic import roots: claude=%v codex=%v", auto.Claude != nil, auto.Codex != nil)
	}
	// Owed only after a requested first run, and only for the recorded, uncovered source.
	if got := owedHistoryTools(cache); len(got) != 0 {
		t.Fatalf("fresh profile owes %v", got)
	}
	if err := speed.MarkAutoRequested(cache, time.Now()); err != nil {
		t.Fatal(err)
	}
	if got := owedHistoryTools(cache); len(got) != 1 || !got["codex"] {
		t.Fatalf("owed %v, want codex only", got)
	}
	if !consent.Allowed("claude", consent.Local) {
		t.Skip("claude history is not default-on here; the boundary above still holds")
	}
	if manual := importOptions(st, 30, false, time.Now(), manualImport); manual.Claude == nil {
		t.Fatal("explicit import lost the consent in force")
	}
}

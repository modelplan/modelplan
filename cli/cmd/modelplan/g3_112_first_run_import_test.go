// SPDX-License-Identifier: MIT
package main

import (
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// G3-112: the engine starts the first-run import itself when it is still owed (it failed, never
// started, or a reset re-armed it) and a Claude Code or Codex history grant is in force.
func TestFirstRunImportPendingNeedsMarkerAndGrant(t *testing.T) {
	consentFixtureHome(t)
	t.Setenv("MODELPLAN_HISTORY", "")
	cache := t.TempDir()
	cstate, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	deny := consent.Grant{RequestID: "deny", ExpectStoreEpoch: cstate.StoreEpoch, ExpectGeneration: cstate.Generation, ConsentTextVersion: consent.TextVersion, Deny: []string{consent.ScopeClaudeLocalHistory, consent.ScopeCodexLocalHistory}}
	hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) { return consent.Record{}, nil }, Cleanup: func(scope string, forget bool) error {
		return quota.EraseScope(quota.Paths{Cache: cache}, scope, forget)
	}}
	if _, err := consent.ApplyGrant(consent.Path(), deny, hooks); err != nil {
		t.Fatal(err)
	}
	if firstRunImportPending(cache, consent.Capture()) {
		t.Fatal("pending without any history grant")
	}
	cstate, _ = consent.Current()
	allow := consent.Grant{RequestID: "allow", ExpectStoreEpoch: cstate.StoreEpoch, ExpectGeneration: cstate.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCodexLocalHistory}}
	if _, err := consent.ApplyGrant(consent.Path(), allow, hooks); err != nil {
		t.Fatal(err)
	}
	if !firstRunImportPending(cache, consent.Capture()) {
		t.Fatal("owed import with a Codex grant not started")
	}
	t.Setenv("MODELPLAN_HISTORY", "off")
	if firstRunImportPending(cache, consent.Capture()) {
		t.Fatal("pending while history is off")
	}
}

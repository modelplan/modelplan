// SPDX-License-Identifier: MIT
package consent

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestRowsInputUsesCapturedConsentFacts(t *testing.T) {
	state := Empty()
	state.Generation = 42
	state.Tools["grok"] = Record{Allowed: true, ConsentTextVersion: TextVersion - 1}
	state.Tools["retired-tool"] = Record{Allowed: false, ConsentTextVersion: TextVersion}
	state.Requests = map[string]Receipt{"request": {PendingForget: []string{"retired-tool"}}}
	admission := NewAdmission(state, Automatic)
	state.Tools["grok"] = Record{}
	now := time.Now()
	in := admission.RowsInput(now)
	if in.ConsentGeneration != 42 || in.ReadersOff || !in.Now.Equal(now) {
		t.Fatal(in)
	}
	got := map[string]rows.ConsentRecord{}
	for _, r := range in.Consents {
		got[r.ToolID] = r
	}
	if got["grok"].State != rows.ConsentAllowed || !got["grok"].Outdated || got["retired-tool"].State != rows.ConsentDenied || !got["retired-tool"].CleanupPending {
		t.Fatal(got)
	}
	for _, tool := range []string{"claude", "codex"} {
		if got[tool].State != rows.ConsentImplicit || got[tool].Generation != 42 {
			t.Fatal(got)
		}
	}
	if _, invented := got["cursor"]; invented {
		t.Fatal("new credential reader received an implicit grant")
	}
	in.Consents[0].State = rows.ConsentDenied
	if admission.RowsInput(now).Consents[0].State != rows.ConsentAllowed {
		t.Fatal("row adapter modified admission")
	}
	state.Tools["claude"] = Record{Allowed: false, ConsentTextVersion: TextVersion}
	for _, r := range NewAdmission(state, Passive).RowsInput(now).Consents {
		if r.ToolID == "claude" && r.State != rows.ConsentDenied {
			t.Fatal("implicit permission overrode denial")
		}
	}
	off := NewAdmission(Empty(), Off).RowsInput(now)
	if !off.ReadersOff || len(off.Consents) != 0 {
		t.Fatal("off invented implicit consent", off)
	}
}

func TestChangedRowsInputKeepsOnlyPublicationGeneration(t *testing.T) {
	state := Empty()
	state.Generation = 9
	state.Tools["claude"] = Record{Allowed: true, ConsentTextVersion: TextVersion}
	in := NewAdmission(state, Automatic).ChangedRowsInput(time.Now())
	if !in.ConsentChanged || in.ConsentGeneration != 9 || len(in.Consents) != 0 || len(in.Accounts) != 0 || len(in.Catalogue) != 0 || len(in.Profiles) != 0 {
		t.Fatal(in)
	}
}

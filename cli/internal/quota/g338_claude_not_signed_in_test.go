// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

// G3-38 (owner D52): a Mac where Claude Code is installed but signed out (no credentials file,
// no Keychain login item) is reported as not signed in, not as a generic reader error, and its
// row says so in Settings and the menu without a Dock ring. Synthetic HOME; nothing is read.
func TestG338ClaudeWithoutLoginIsNotSignedIn(t *testing.T) {
	p := claudeTestPaths(t)
	syntheticHome := t.TempDir()
	t.Setenv("HOME", syntheticHome)
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	root := filepath.Join(syntheticHome, ".claude")
	if err := os.MkdirAll(root, 0o700); err != nil {
		t.Fatal(err)
	}
	g := p.ReaderAccess.Grants["claude"]
	g.Profiles = []ReaderProfile{{Root: root}}
	g.Keychain = true
	g.KeychainConsent = "allowed"
	p.ReaderAccess.Grants["claude"] = g
	// The app's Keychain lookup found no Claude Code login item.
	bound, release := WithClaudeCredential(p, "not_found", "", nil)
	defer release()
	key := readerHash(p.Cache, "claude:profile", root+"\x00")
	out := collectClaudeAccount(context.Background(), nativeClient, readerContext{Paths: bound, Grant: bound.ReaderAccess.Grants["claude"], Profile: g.Profiles[0], ProfileKey: key, Now: claudeTestNow})
	if out.Entry.Account != nil {
		t.Fatal("a signed-out tool produced an account")
	}
	if out.Entry.ErrorCode != "not_signed_in" {
		t.Fatalf("error code = %q, want not_signed_in", out.Entry.ErrorCode)
	}
	if got := nativeDiagnosticState(out.Entry.Status, out.Entry.ErrorCode); got != "unavailable:reader_error:not_signed_in" {
		t.Fatalf("doctor state = %q, want unavailable:reader_error:not_signed_in", got)
	}
	out.Entry.ProfileKey = key
	grantKey := readerHash(p.Cache, "claude:grant", g.Generation)
	if err := saveReaderState(p.Cache, &readerState{SchemaVersion: 1, Provider: "claude", GrantKey: grantKey, Entries: []readerEntry{out.Entry}}); err != nil {
		t.Fatal(err)
	}
	in := rows.Input{Now: claudeTestNow, ConsentGeneration: 1,
		Catalogue: []rows.CatalogueEntry{{ToolID: "claude", Detected: true, ReaderExists: true}},
		Consents:  []rows.ConsentRecord{{ToolID: "claude", Generation: 1, State: rows.ConsentAllowed}}}
	AppendManagedRows(&in, p)
	projection := rows.Build(in)
	var claude *rows.Row
	for i := range projection.Rows {
		if projection.Rows[i].ID == "claude" {
			claude = &projection.Rows[i]
		}
	}
	if claude == nil {
		t.Fatal("the Claude row is missing; Settings must still say why")
	}
	if claude.Reason.Code != rows.CodeNotSignedIn || claude.Reason.Text.EN != "Not signed in" || claude.Reason.Text.ZH != "未登录" {
		t.Fatalf("reason = %+v, want not_signed_in", claude.Reason)
	}
	// One sentence pair with first run and Settings (rows.NotSignedInText), no English in the Chinese
	// line besides the tool's own name.
	want := rows.NotSignedInText(claude.Name.EN, claude.Name.ZH)
	if claude.NextStep == nil || claude.NextStep.Text != want || claude.NextStep.Text.ZH != "未登录 "+claude.Name.ZH+"。登录后会自动读取。" {
		t.Fatalf("next step = %+v, want %+v", claude.NextStep, want)
	}
	// Needs action, but there is nothing for the user to press: no menu next-step button, and the
	// summary does not count a signed-out tool as a usable Dock row.
	if claude.State != rows.StateNeedsAction || claude.NextStep.Action != rows.ActionNone {
		t.Fatalf("state=%s action=%s, want needs_action with action none", claude.State, claude.NextStep.Action)
	}
	if projection.RowsSummary.State == rows.SummaryStateOK {
		t.Fatalf("a signed-out tool alone flipped the summary to ok: %+v", projection.RowsSummary)
	}
	for _, surface := range claude.Surfaces {
		if surface == rows.SurfaceDock {
			t.Fatal("a signed-out tool still has a Dock ring")
		}
	}
	settings, menu := false, false
	for _, surface := range claude.Surfaces {
		settings = settings || surface == rows.SurfaceSettings
		menu = menu || surface == rows.SurfaceMenu
	}
	if !settings || !menu {
		t.Fatalf("surfaces = %v, want menu and settings", claude.Surfaces)
	}
}

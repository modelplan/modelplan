// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"path/filepath"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// D238: the engine re-runs presence detection on every view it builds (startup, each
// observation tick, every consent change). A tool that appears after the first view is
// offered in the menu as detected-not-enabled when it needs more than local logs
// (Kiro: its runtime, D240); it disappears again when it is uninstalled.
func TestD238ToolInstalledAfterLaunchIsOfferedOnTheNextView(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "")
	kiro := false
	ledger := detect.NewSeenLedger(filepath.Join(t.TempDir(), "detected-tools.json"), false)
	b, err := NewSharedBackend(SharedConfig{
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{
				{Entry: detect.Entry{ProviderID: "claude", Preferred: "native", ReaderID: "native:claude"}, Detected: true},
				{Entry: detect.Entry{ProviderID: "kiro", Preferred: "native", ReaderID: "native:kiro"}, Detected: kiro},
			}}
		},
		LaterInstalled: ledger.Observe,
		Paths:          func(a consent.Admission) quota.Paths { return quota.Paths{Admission: &a} }, Cleanup: func(string, bool) error { return nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	kiroRow := func() *rows.Row {
		view, err := b.Get(context.Background())
		if err != nil {
			t.Fatal(err)
		}
		for i := range view.Projection.Rows {
			if view.Projection.Rows[i].ID == "kiro" {
				return &view.Projection.Rows[i]
			}
		}
		return nil
	}
	if row := kiroRow(); row != nil {
		t.Fatalf("not installed yet: %+v", row)
	}
	kiro = true
	row := kiroRow()
	if row == nil || row.Consent != rows.ConsentUnset || row.Reason.Code != rows.CodeConsentRequired || len(row.Accounts) != 0 {
		t.Fatalf("installed after launch: %+v", row)
	}
	menu := false
	for _, s := range row.Surfaces {
		menu = menu || s == rows.SurfaceMenu
		if s == rows.SurfaceDock {
			t.Fatalf("undecided tool got a Dock ring: %v", row.Surfaces)
		}
	}
	if !menu {
		t.Fatalf("installed-later tool is not offered in the menu: %v", row.Surfaces)
	}
	kiro = false
	if row := kiroRow(); row != nil {
		t.Fatalf("uninstalled tool still listed: %+v", row)
	}
}

// D240: a later-installed tool's local-log scope is allowed automatically on the next view
// (no prompt); its saved-login scope stays undecided; a tool present at the baseline is not
// touched; a user's later refusal is kept.
func TestD240LaterInstalledLocalLogsAreReadWithoutAPrompt(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "")
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	gemini := false
	ledger := detect.NewSeenLedger(filepath.Join(t.TempDir(), "detected-tools.json"), false)
	b, err := NewSharedBackend(SharedConfig{
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{
				{Entry: detect.Entry{ProviderID: "cursor", Preferred: "native", ReaderID: "native:cursor"}, Detected: true},
				{Entry: detect.Entry{ProviderID: "gemini", Preferred: "native", ReaderID: "native:gemini"}, Detected: gemini},
			}}
		},
		LaterInstalled: ledger.Observe,
		Paths:          func(a consent.Admission) quota.Paths { return quota.Paths{Admission: &a} }, Cleanup: func(string, bool) error { return nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	state := func() consent.State {
		if _, err := b.Get(context.Background()); err != nil {
			t.Fatal(err)
		}
		s, err := consent.Load(consent.Path())
		if err != nil {
			t.Fatal(err)
		}
		return s
	}
	if s := state(); len(s.Scopes) != 0 {
		t.Fatalf("baseline tool changed: %+v", s.Scopes)
	}
	gemini = true
	s := state()
	if r, ok := s.Scopes[consent.ScopeGeminiLocalHistory]; !ok || !r.Allowed {
		t.Fatalf("later-installed local logs not allowed: %+v", s.Scopes)
	}
	if _, decided := s.Scopes[consent.ScopeGeminiAccountUsageSavedLogin]; decided {
		t.Fatal("saved-login scope was decided without the user")
	}
	if _, decided := s.Scopes[consent.ScopeCursorLocalHistory]; decided {
		t.Fatal("baseline tool's local logs were allowed (D240 is later installs only)")
	}
	if _, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "user-off", ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Deny: []string{consent.ScopeGeminiLocalHistory}}, consent.GrantHooks{}); err != nil {
		t.Fatal(err)
	}
	if r := state().Scopes[consent.ScopeGeminiLocalHistory]; r.Allowed {
		t.Fatal("the user's refusal was overridden")
	}
}

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
// offered in the menu as detected-not-enabled; it disappears again when it is uninstalled.
func TestD238ToolInstalledAfterLaunchIsOfferedOnTheNextView(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	t.Setenv("MODELPLAN_READERS", "")
	gemini := false
	ledger := detect.NewSeenLedger(filepath.Join(t.TempDir(), "detected-tools.json"), false)
	b, err := NewSharedBackend(SharedConfig{
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{
				{Entry: detect.Entry{ProviderID: "claude", Preferred: "native", ReaderID: "native:claude"}, Detected: true},
				{Entry: detect.Entry{ProviderID: "gemini", Preferred: "native", ReaderID: "native:gemini"}, Detected: gemini},
			}}
		},
		LaterInstalled: ledger.Observe,
		Paths:          func(a consent.Admission) quota.Paths { return quota.Paths{Admission: &a} }, Cleanup: func(string, bool) error { return nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	geminiRow := func() *rows.Row {
		view, err := b.Get(context.Background())
		if err != nil {
			t.Fatal(err)
		}
		for i := range view.Projection.Rows {
			if view.Projection.Rows[i].ID == "gemini" {
				return &view.Projection.Rows[i]
			}
		}
		return nil
	}
	if row := geminiRow(); row != nil {
		t.Fatalf("not installed yet: %+v", row)
	}
	gemini = true
	row := geminiRow()
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
	gemini = false
	if row := geminiRow(); row != nil {
		t.Fatalf("uninstalled tool still listed: %+v", row)
	}
}

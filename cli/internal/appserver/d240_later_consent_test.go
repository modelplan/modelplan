// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// laterToolBackend builds the production shared backend with one baseline tool (Cursor) and
// one tool that is absent on the first view and installed afterwards.
func laterToolBackend(t *testing.T, later string, paths func(consent.Admission) quota.Paths) (*SharedBackend, func()) {
	t.Helper()
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	installed := false
	ledger := detect.NewSeenLedger(filepath.Join(t.TempDir(), "detected-tools.json"), false)
	b, err := NewSharedBackend(SharedConfig{
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{
				{Entry: detect.Entry{ProviderID: "cursor", Preferred: "native", ReaderID: "native:cursor"}, Detected: true},
				{Entry: detect.Entry{ProviderID: later, Preferred: "native", ReaderID: "native:" + later}, Detected: installed},
			}}
		},
		LaterInstalled: ledger.Observe,
		Paths:          paths, Cleanup: func(string, bool) error { return nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := b.Get(context.Background()); err != nil { // baseline: the tool is not installed yet
		t.Fatal(err)
	}
	return b, func() {
		installed = true
		if _, err := b.Get(context.Background()); err != nil { // detects the install, applies D240
			t.Fatal(err)
		}
	}
}

func laterRow(t *testing.T, b *SharedBackend, id string) *rows.Row {
	t.Helper()
	view, err := b.Get(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	for i := range view.Projection.Rows {
		if view.Projection.Rows[i].ID == id {
			return &view.Projection.Rows[i]
		}
	}
	return nil
}

// #924-1: the automatic local-history grant for a later-installed tool covers its local logs
// only. Every runtime or account scope of every such tool stays closed until the user grants it.
func TestD240AutomaticHistoryGrantOpensNoRuntimeOrAccountScope(t *testing.T) {
	tools := map[string]bool{}
	for _, d := range consent.Definitions() {
		if d.Class == consent.Local && d.DefaultCheck {
			tools[d.Tool] = true
		}
	}
	for tool := range tools {
		if tool == "cursor" {
			continue // the fixture's baseline tool
		}
		t.Run(tool, func(t *testing.T) {
			cache := t.TempDir()
			paths := func(a consent.Admission) quota.Paths { return quota.ProductionPathsWithAdmission(cache, "1.0.0", a) }
			_, install := laterToolBackend(t, tool, paths)
			install()
			admission := consent.Capture()
			state := admission.State()
			if r, ok := state.Scopes[tool+".local_history"]; !ok || !r.Allowed {
				t.Fatalf("later-installed local history not allowed: %+v", state.Scopes)
			}
			for _, d := range consent.Definitions() {
				if d.Tool != tool || d.Class == consent.Local {
					continue
				}
				if state.AllowsScope(d.ID, admission.Mode()) {
					t.Errorf("%s passes consent after the automatic history grant", d.ID)
				}
				if plan, _ := quota.PlanScopeRefresh(paths(admission), d.ID, time.Now()); plan.Admitted {
					t.Errorf("%s is admitted for a refresh after the automatic history grant", d.ID)
				}
			}
			for _, scope := range liveRefreshScopes(state, admission.Mode()) {
				if d, _ := consent.Definition(scope); d.Tool == tool {
					t.Errorf("%s is scheduled after the automatic history grant", scope)
				}
			}
		})
	}
}

// #924-1 through the real entry points: a Copilot install detected after the first run, the
// automatic grant and the automatic scheduler never spawn `copilot --headless`. The user's own
// grant does.
func TestD240LaterInstalledCopilotIsNotLaunchedWithoutTheUsersGrant(t *testing.T) {
	cache := t.TempDir()
	paths := func(a consent.Admission) quota.Paths { return quota.ProductionPathsWithAdmission(cache, "1.0.0", a) }
	b, install := laterToolBackend(t, "copilot", paths)
	dir := t.TempDir()
	bin, log := filepath.Join(dir, "copilot"), filepath.Join(dir, "spawned")
	if err := os.WriteFile(bin, []byte("#!/bin/sh\necho \"$@\" >> '"+log+"'\nexit 1\n"), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_COPILOT", bin)
	install()
	if row := laterRow(t, b, "copilot"); row == nil || row.Reason.Code == rows.CodeNotAdmitted {
		t.Fatalf("later-installed Copilot row: %+v", row)
	}
	scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: b, Paths: paths, Run: quota.ExecuteScopeRefresh, Changed: b.Notify})
	defer scheduler.Close()
	scheduler.StartAutomatic()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(log); err == nil {
			t.Fatal("copilot --headless was spawned without the user's grant")
		}
		time.Sleep(20 * time.Millisecond)
	}
	state := consent.Capture().State()
	if _, err := b.Grant(context.Background(), wire.ConsentGrantParams{RequestID: "user-copilot-runtime", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation, TextVersion: consent.TextVersion, Allow: []string{consent.ScopeCopilotRuntimeUsage}, Deny: []string{}}); err != nil {
		t.Fatal(err)
	}
	signalAutomatic(scheduler)
	deadline = time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(log); err == nil {
			return
		}
		time.Sleep(20 * time.Millisecond)
	}
	t.Fatal("the user's explicit runtime grant did not start the Copilot read")
}

// #924-3: a later-installed tool whose account path is still blocked keeps its allowed local
// history; the row is not vetoed as a whole ("This reader is not admitted").
func TestD240BlockedAccountRouteDoesNotVetoLaterLocalHistory(t *testing.T) {
	for _, tool := range []string{"gemini", "grok", "kimi", "copilot"} {
		t.Run(tool, func(t *testing.T) {
			cache := t.TempDir()
			paths := func(a consent.Admission) quota.Paths { return quota.ProductionPathsWithAdmission(cache, "1.0.0", a) }
			b, install := laterToolBackend(t, tool, paths)
			install()
			row := laterRow(t, b, tool)
			if row == nil || row.Consent != rows.ConsentAllowed || row.Reason.Code == rows.CodeNotAdmitted {
				t.Fatalf("later-installed %s row: %+v", tool, row)
			}
		})
	}
}

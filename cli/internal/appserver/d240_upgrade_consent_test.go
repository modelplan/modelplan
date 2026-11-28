// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"os"
	"path/filepath"
	"reflect"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/resetevents"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// upgradeFixture is one Mac: a consent store, a seen-tools ledger and a Copilot install that
// appeared after the first run. Each engine() call is a fresh engine start on that Mac.
type upgradeFixture struct {
	t         *testing.T
	ledger    string
	cache     string
	installed bool
	spawned   string
}

func newUpgradeFixture(t *testing.T) *upgradeFixture {
	t.Helper()
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	dir := t.TempDir()
	f := &upgradeFixture{t: t, ledger: filepath.Join(dir, "detected-tools.json"), cache: t.TempDir(), spawned: filepath.Join(dir, "spawned")}
	bin := filepath.Join(dir, "copilot")
	if err := os.WriteFile(bin, []byte("#!/bin/sh\necho \"$@\" >> '"+f.spawned+"'\nexit 1\n"), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_COPILOT", bin)
	return f
}

func (f *upgradeFixture) paths(a consent.Admission) quota.Paths {
	return quota.ProductionPathsWithAdmission(f.cache, "1.0.0", a)
}

func (f *upgradeFixture) config() SharedConfig {
	ledger := detect.NewSeenLedger(f.ledger, false)
	return SharedConfig{
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{
				{Entry: detect.Entry{ProviderID: "cursor", Preferred: "native", ReaderID: "native:cursor"}, Detected: true},
				{Entry: detect.Entry{ProviderID: "copilot", Preferred: "native", ReaderID: "native:copilot"}, Detected: f.installed},
			}}
		},
		LaterInstalled: ledger.Observe,
		Paths:          f.paths, Cleanup: func(string, bool, consent.EraseGuard) error { return nil },
	}
}

// engine is a fresh engine start; running reuses an engine that was started before the upgrade
// store existed (no constructor work), so only the view path can repair.
func (f *upgradeFixture) engine() *SharedBackend {
	f.t.Helper()
	b, err := NewSharedBackend(f.config())
	if err != nil {
		f.t.Fatal(err)
	}
	return b
}

func (f *upgradeFixture) running() *SharedBackend {
	return &SharedBackend{config: f.config(), resetMemo: resetevents.NewMemo(), changes: make(chan struct{}, 1)}
}

func (f *upgradeFixture) view(b *SharedBackend) {
	f.t.Helper()
	if _, err := b.Get(context.Background()); err != nil {
		f.t.Fatal(err)
	}
}

// v060Store installs Copilot after the first run and lets D240 grant its local history, then
// removes what v0.5.61 adds (#924): the deny records for the runtime/account scopes. What is
// left is the store CLI v0.5.60 wrote: local history allowed, a Copilot tool record, and
// copilot.runtime_usage undecided, which that tool record admits.
func (f *upgradeFixture) v060Store() {
	f.t.Helper()
	f.view(f.engine()) // baseline: Copilot is not installed yet
	f.installed = true
	f.view(f.engine())
	err := consent.Transaction(consent.Path(), func(s *consent.State) error {
		for _, d := range consent.Definitions() {
			if d.Tool == "copilot" && d.Class != consent.Local {
				delete(s.Scopes, d.ID)
				delete(s.Revoked, d.ID)
			}
		}
		return nil
	}, nil)
	if err != nil {
		f.t.Fatal(err)
	}
	state := consent.Capture().State()
	if !state.AllowsScope(consent.ScopeCopilotRuntimeUsage, consent.Automatic) {
		f.t.Fatalf("fixture is not the v0.5.60 store: %+v", state.Scopes)
	}
}

func (f *upgradeFixture) assertCopilotRuntimeClosed() {
	f.t.Helper()
	admission := consent.Capture()
	state := admission.State()
	if r, ok := state.Scopes["copilot.local_history"]; !ok || !r.Allowed {
		f.t.Fatalf("the upgrade dropped the allowed local history: %+v", state.Scopes)
	}
	if r, ok := state.Scopes[consent.ScopeCopilotRuntimeUsage]; !ok || r.Allowed {
		f.t.Fatalf("copilot.runtime_usage is not recorded as off after the upgrade: %+v", state.Scopes)
	}
	if state.AllowsScope(consent.ScopeCopilotRuntimeUsage, admission.Mode()) {
		f.t.Fatal("copilot.runtime_usage passes consent after the upgrade")
	}
	if plan, _ := quota.PlanScopeRefresh(f.paths(admission), consent.ScopeCopilotRuntimeUsage, time.Now()); plan.Admitted {
		f.t.Fatal("copilot.runtime_usage is admitted for a refresh after the upgrade")
	}
	for _, scope := range liveRefreshScopes(state, admission.Mode()) {
		if scope == consent.ScopeCopilotRuntimeUsage {
			f.t.Fatal("copilot.runtime_usage is scheduled after the upgrade")
		}
	}
}

func (f *upgradeFixture) assertNotLaunched(b *SharedBackend) {
	f.t.Helper()
	scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: b, Paths: f.paths, Run: quota.ExecuteScopeRefresh, Changed: b.Notify})
	defer scheduler.Close()
	scheduler.StartAutomatic()
	signalAutomatic(scheduler)
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(f.spawned); err == nil {
			f.t.Fatal("copilot --headless was spawned on the v0.5.60 auto grant")
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// Sampling P1 on #955: the engine start of the fixed CLI closes the runtime scope that the
// v0.5.60 auto grant opened, before any view or refresh, and Copilot is never launched.
func TestD240UpgradeClosesV060AutoGrantOnEngineStart(t *testing.T) {
	f := newUpgradeFixture(t)
	f.v060Store()
	b := f.engine()
	f.assertCopilotRuntimeClosed()
	f.assertNotLaunched(b)
}

// The same repair through the later-install path (a view on an engine that is already running).
func TestD240UpgradeClosesV060AutoGrantOnView(t *testing.T) {
	f := newUpgradeFixture(t)
	f.v060Store()
	b := f.running()
	f.view(b)
	f.assertCopilotRuntimeClosed()
}

// A runtime scope the user allowed themselves is a recorded decision. The upgrade never
// touches it, on engine start or on a view.
func TestD240UpgradeKeepsTheUsersOwnRuntimeGrant(t *testing.T) {
	f := newUpgradeFixture(t)
	f.v060Store()
	state := consent.Capture().State()
	// The user turns Copilot's runtime on in the v0.5.60 build (no repair runs in between).
	b := f.running()
	b.config.LaterInstalled = nil
	if _, err := b.Grant(context.Background(), wire.ConsentGrantParams{RequestID: "user-copilot-runtime", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation, TextVersion: consent.TextVersion, Allow: []string{consent.ScopeCopilotRuntimeUsage}, Deny: []string{}}); err != nil {
		t.Fatal(err)
	}
	f.view(f.engine())
	admission := consent.Capture()
	if r := admission.State().Scopes[consent.ScopeCopilotRuntimeUsage]; !r.Allowed || !admission.State().AllowsScope(consent.ScopeCopilotRuntimeUsage, admission.Mode()) {
		t.Fatalf("the user's own runtime grant was revoked: %+v", admission.State().Scopes)
	}
}

// The repair is idempotent: a second engine start and further views change nothing.
func TestD240UpgradeRepairRunsOnce(t *testing.T) {
	f := newUpgradeFixture(t)
	f.v060Store()
	b := f.engine()
	f.view(b)
	before := consent.Capture().State()
	f.view(f.engine())
	f.view(b)
	after := consent.Capture().State()
	if after.Generation != before.Generation || !reflect.DeepEqual(after.Scopes, before.Scopes) || !reflect.DeepEqual(after.Tools, before.Tools) {
		t.Fatalf("a second run changed the store: generation %d -> %d\n%+v\n%+v", before.Generation, after.Generation, before.Scopes, after.Scopes)
	}
	f.assertCopilotRuntimeClosed()
}

// #971 review (glm-971-1): the repair grant can fail or go stale (a concurrent consent change,
// an unwritable store). Until it commits, the automatic scheduler must not admit the scopes the
// v0.5.60 grant left open, and once it can commit the scheduler's own attempt records them off.
func TestD240AutomaticRefreshWaitsForTheRepair(t *testing.T) {
	f := newUpgradeFixture(t)
	f.v060Store()
	dir := filepath.Dir(consent.Path())
	for _, lock := range []string{".lock", ".readers.lock"} { // the locks still work
		if err := os.WriteFile(consent.Path()+lock, nil, 0600); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Chmod(dir, 0500); err != nil { // every consent write now fails
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.Chmod(dir, 0700) })
	b := f.running()
	f.view(b) // the view's repair attempt fails
	if !consent.Capture().State().AllowsScope(consent.ScopeCopilotRuntimeUsage, consent.Automatic) {
		t.Fatal("fixture: the repair committed although the store is read-only")
	}
	scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: b, Paths: f.paths, Run: quota.ExecuteScopeRefresh, Changed: b.Notify})
	defer scheduler.Close()
	scheduler.StartAutomatic()
	signalAutomatic(scheduler)
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(f.spawned); err == nil {
			t.Fatal("copilot --headless was spawned while the repair had not committed")
		}
		time.Sleep(20 * time.Millisecond)
	}
	if err := os.Chmod(dir, 0700); err != nil {
		t.Fatal(err)
	}
	signalAutomatic(scheduler)
	deadline = time.Now().Add(5 * time.Second)
	for {
		if r, ok := consent.Capture().State().Scopes[consent.ScopeCopilotRuntimeUsage]; ok && !r.Allowed {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("the scheduler did not retry the repair once the store was writable")
		}
		time.Sleep(20 * time.Millisecond)
	}
	if _, err := os.Stat(f.spawned); err == nil {
		t.Fatal("copilot --headless was spawned around the repair")
	}
	f.assertCopilotRuntimeClosed()
}

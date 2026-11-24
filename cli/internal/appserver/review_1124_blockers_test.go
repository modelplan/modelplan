//go:build darwin || linux

// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

func reviewConfig(home string, readOnly bool, cleanup func(string, bool) error) SharedConfig {
	return SharedConfig{ReadOnly: readOnly, Detect: func() detect.Report { return detect.Report{} }, Paths: func(a consent.Admission) quota.Paths {
		return quota.Paths{Cache: filepath.Join(home, "cache"), Admission: &a}
	}, Cleanup: cleanup}
}

func owedScopes(t *testing.T) []string {
	t.Helper()
	s, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	var out []string
	for _, r := range s.Requests {
		out = append(out, r.PendingForget...)
	}
	sort.Strings(out)
	return out
}

// macrevb-1218-2: the live retry held the consent lock over two erasure callbacks that each
// wait up to two seconds for the reader lock, so a concurrent Deny gave up and never committed.
// Invariant: while background erasure waits on a running reader, a foreground Deny commits.
func TestReviewCleanupRetryLetsConcurrentDenyCommit(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_READERS", "automatic")
	consent.SetReadOnlyProcess(false)
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	var erased atomic.Int32
	// Like the production erasure hook: wait (bounded) for the reader lock, then erase.
	erase := func(scope string, forget bool) error {
		unlock, err := consent.ReaderLockWait()
		if err != nil {
			return err
		}
		defer unlock()
		erased.Add(1)
		return nil
	}
	failFast := func(string, bool) error { return errors.New("reader lock busy") }
	forget := consent.Grant{RequestID: "forget-two", ExpectStoreEpoch: state.StoreEpoch, Forget: []string{"retired.old_path"}, Deny: []string{consent.ScopeClaudeAccountUsageSavedLogin}}
	original, err := consent.ApplyGrant(consent.Path(), forget, consent.GrantHooks{Cleanup: failFast})
	if err != nil || original.Code != "cleanup_pending" {
		t.Fatal(original, err)
	}
	reader, err := consent.ReaderLock() // a long read is running
	if err != nil {
		t.Fatal(err)
	}
	released := false
	release := func() {
		if !released {
			released = true
			reader()
		}
	}
	defer release()
	b, err := NewSharedBackend(reviewConfig(home, false, erase))
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	changes := b.Changes(ctx)
	time.Sleep(600 * time.Millisecond) // the watcher has started the retry, which waits on the reader
	current, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	deny := consent.Grant{RequestID: "deny-gemini", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: current.Generation, Deny: []string{consent.ScopeGeminiAccountUsageSavedLogin}}
	result, err := consent.ApplyGrant(consent.Path(), deny, consent.GrantHooks{Cleanup: failFast})
	if err != nil || !result.Committed {
		t.Fatal("concurrent deny did not commit while background erasure waited:", result, err)
	}
	release()
	deadline := time.After(20 * time.Second)
	for len(owedScopes(t)) > 0 {
		select {
		case <-changes:
		case <-time.After(100 * time.Millisecond):
		case <-deadline:
			t.Fatal("owed erasure never completed after the reader released", owedScopes(t))
		}
	}
	if erased.Load() < 3 {
		t.Fatal("obligations cleared without erasing", erased.Load())
	}
	for _, request := range []struct {
		grant consent.Grant
		want  consent.GrantReceipt
	}{{forget, original}, {deny, result}} {
		replay, err := consent.ApplyGrant(consent.Path(), request.grant, consent.GrantHooks{})
		if err != nil || !replay.Replayed || replay.Code != request.want.Code || *replay.CommittedGeneration != *request.want.CommittedGeneration {
			t.Fatal("retry changed an original reply", replay, err)
		}
	}
}

func snapshotDir(t *testing.T, dir string) map[string]string {
	t.Helper()
	out := map[string]string{}
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		b, _ := os.ReadFile(filepath.Join(dir, e.Name()))
		out[e.Name()] = string(b)
	}
	return out
}

func sameDir(t *testing.T, before, after map[string]string) {
	t.Helper()
	if len(after) != len(before) {
		t.Fatalf("consent directory changed: %d -> %d entries (%v)", len(before), len(after), after)
	}
	for name, content := range before {
		if got, ok := after[name]; !ok || got != content {
			t.Fatalf("%s was written", name)
		}
	}
}

func flockExisting(t *testing.T, path string, how int) func() {
	t.Helper()
	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := syscall.Flock(int(f.Fd()), how|syscall.LOCK_NB); err != nil {
		t.Fatal(err)
	}
	return func() { syscall.Flock(int(f.Fd()), syscall.LOCK_UN); f.Close() }
}

// macrevb-1218-3: read-only applied only to the constructor and the missing-lock path; publish
// took the exclusive consent lock and live stamp/view/watcher reads could migrate a legacy store.
// Invariant: a cache-only server never migrates, writes, creates or exclusively locks consent
// files, and never publishes once the admitted fence is invalid or cannot be serialized.
func TestReviewReadOnlyServerNeverWritesOrLocksConsent(t *testing.T) {
	t.Cleanup(func() { consent.SetReadOnlyProcess(false) })
	start := func(t *testing.T) (*SharedBackend, string) {
		t.Helper()
		home := t.TempDir()
		t.Setenv("HOME", home)
		t.Setenv("MODELPLAN_READERS", "automatic")
		consent.SetReadOnlyProcess(false)
		if _, err := consent.EnsureStore(consent.Path()); err != nil { // a writable launch made the store
			t.Fatal(err)
		}
		b, err := NewSharedBackend(reviewConfig(home, true, func(string, bool) error { return nil }))
		if err != nil {
			t.Fatal(err)
		}
		return b, filepath.Dir(consent.Path())
	}
	exercise := func(t *testing.T, b *SharedBackend) {
		t.Helper()
		ctx, cancel := context.WithCancel(context.Background())
		b.Changes(ctx)
		_, _ = b.CurrentStamp(context.Background())
		_, _ = b.Get(context.Background())
		b.ViewCurrent(b.ViewToken())
		time.Sleep(500 * time.Millisecond) // a few watcher ticks
		cancel()
	}
	publish := func(b *SharedBackend, stamp Stamp) (bool, error) {
		called := false
		err := b.Publish(context.Background(), stamp, func() error { called = true; return nil })
		return called, err
	}
	t.Run("existing lock", func(t *testing.T) {
		b, dir := start(t)
		before := snapshotDir(t, dir)
		view, err := b.Get(context.Background())
		if err != nil {
			t.Fatal(err)
		}
		// Another reader's shared lock never excludes this one: no exclusive lock is taken.
		shared := flockExisting(t, consent.Path()+".lock", syscall.LOCK_SH)
		exercise(t, b)
		if called, err := publish(b, view.Stamp); err != nil || !called {
			t.Fatal("read-only publish took an exclusive lock", err)
		}
		shared()
		// A writer's exclusive lock still fences publication.
		writer := flockExisting(t, consent.Path()+".lock", syscall.LOCK_EX)
		called, err := publish(b, view.Stamp)
		writer()
		if called || !errors.Is(err, ProtocolError{wire.CodeBusy}) {
			t.Fatal("publication was not serialized with a writer", called, err)
		}
		sameDir(t, before, snapshotDir(t, dir))
		// Another process commits a revoke: the admitted fence is gone.
		var raw map[string]any
		b0, _ := os.ReadFile(consent.Path())
		_ = json.Unmarshal(b0, &raw)
		raw["generation"] = raw["generation"].(float64) + 1
		b1, _ := json.Marshal(raw)
		if err := os.WriteFile(consent.Path(), b1, 0600); err != nil {
			t.Fatal(err)
		}
		if called, err := publish(b, view.Stamp); called || !errors.Is(err, ProtocolError{wire.CodeConsentChanged}) {
			t.Fatal("published after the admitted fence was invalidated", called, err)
		}
	})
	t.Run("missing lock", func(t *testing.T) {
		b, dir := start(t)
		if err := os.Remove(consent.Path() + ".lock"); err != nil {
			t.Fatal(err)
		}
		before := snapshotDir(t, dir)
		view, err := b.Get(context.Background())
		if err != nil {
			t.Fatal(err)
		}
		exercise(t, b)
		// Without a lock file nothing can serialize this publication with a writer: fail closed.
		if called, err := publish(b, view.Stamp); called || err == nil {
			t.Fatal("published without writer serialization", called, err)
		}
		sameDir(t, before, snapshotDir(t, dir))
	})
	t.Run("legacy restored while running", func(t *testing.T) {
		b, dir := start(t)
		view, err := b.Get(context.Background())
		if err != nil {
			t.Fatal(err)
		}
		legacy := `{"schemaVersion":1,"generation":7,"privacy":"passive","tools":{"gemini":{"allowed":true,"consentTextVersion":2,"at":"2026-01-01T00:00:00Z","readerId":"native:gemini","backend":"native"}}}`
		if err := os.WriteFile(consent.Path(), []byte(legacy), 0600); err != nil {
			t.Fatal(err)
		}
		before := snapshotDir(t, dir)
		exercise(t, b)
		if _, err := b.CurrentStamp(context.Background()); err == nil {
			t.Fatal("legacy store admitted a stamp")
		}
		if called, err := publish(b, view.Stamp); called || err == nil {
			t.Fatal("published over a restored legacy store", called, err)
		}
		sameDir(t, before, snapshotDir(t, dir))
	})
	t.Run("writers refused", func(t *testing.T) {
		start(t)
		dir := filepath.Dir(consent.Path())
		before := snapshotDir(t, dir)
		if err := consent.RetryCleanup(consent.Path(), func(string, bool) error { return nil }); !errors.Is(err, consent.ErrReadOnly) {
			t.Fatal("cleanup ran in a read-only process", err)
		}
		if _, err := consent.ReaderLock(); !errors.Is(err, consent.ErrReadOnly) {
			t.Fatal("reader lock taken in a read-only process", err)
		}
		if err := consent.Change(consent.Path(), func(*consent.State) error { return nil }); !errors.Is(err, consent.ErrReadOnly) {
			t.Fatal("consent changed in a read-only process", err)
		}
		sameDir(t, before, snapshotDir(t, dir))
	})
}

// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"sort"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Review 11-24 #6: a Forget whose erasure lost the wait for a busy reader lock is retried by the
// running engine once the lock is released; it no longer waits for a helper restart.
func TestPendingForgetCleanupIsRetriedInTheRunningEngine(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_READERS", "automatic")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	var busy atomic.Bool
	var erased atomic.Int32
	busy.Store(true)
	cleanup := func(scope string, forget bool) error {
		if busy.Load() {
			return errors.New("reader lock busy")
		}
		if scope == "retired.old_path" && forget {
			erased.Add(1)
		}
		return nil
	}
	b, err := NewSharedBackend(SharedConfig{Detect: func() detect.Report { return detect.Report{} }, Paths: func(a consent.Admission) quota.Paths {
		return quota.Paths{Cache: filepath.Join(home, "cache"), Admission: &a}
	}, Cleanup: cleanup})
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	changes := b.Changes(ctx)
	request := consent.Grant{RequestID: "forget-while-busy", ExpectStoreEpoch: state.StoreEpoch, Forget: []string{"retired.old_path"}}
	result, err := consent.ApplyGrant(consent.Path(), request, consent.GrantHooks{Cleanup: cleanup})
	if err != nil || result.Code != "cleanup_pending" {
		t.Fatal(result, err)
	}
	busy.Store(false) // the long read finishes and releases its lock
	deadline := time.After(5 * time.Second)
	for {
		current, err := consent.Load(consent.Path())
		if err == nil && len(current.Requests[consent.ReceiptKey(state.StoreEpoch, request.RequestID)].PendingForget) == 0 {
			break
		}
		select {
		case <-changes:
		case <-time.After(100 * time.Millisecond):
		case <-deadline:
			t.Fatal("pending cleanup was never retried in the running engine")
		}
	}
	if erased.Load() == 0 {
		t.Fatal("cleanup marked done without erasing")
	}
	replay, err := consent.ApplyGrant(consent.Path(), request, consent.GrantHooks{})
	if err != nil || !replay.Replayed || replay.Code != "cleanup_pending" {
		t.Fatal("retry rewrote the original receipt", replay, err)
	}
}

// Review 11-24 #9: a read-only app-server neither migrates a legacy store nor creates the
// consent lock, backup or epoch while it starts, builds a view and publishes.
func TestReadOnlyBackendLeavesConsentFilesUntouched(t *testing.T) {
	snapshot := func(dir string) map[string]string {
		out := map[string]string{}
		entries, _ := os.ReadDir(dir)
		for _, e := range entries {
			b, _ := os.ReadFile(filepath.Join(dir, e.Name()))
			out[e.Name()] = string(b)
		}
		return out
	}
	names := func(m map[string]string) []string {
		var n []string
		for k := range m {
			n = append(n, k)
		}
		sort.Strings(n)
		return n
	}
	config := func(home string) SharedConfig {
		return SharedConfig{ReadOnly: true, Detect: func() detect.Report { return detect.Report{} }, Paths: func(a consent.Admission) quota.Paths {
			return quota.Paths{Cache: filepath.Join(home, "cache"), Admission: &a}
		}, Cleanup: func(string, bool) error { return nil }}
	}
	t.Run("legacy", func(t *testing.T) {
		home := t.TempDir()
		t.Setenv("HOME", home)
		dir := filepath.Dir(consent.Path())
		if err := os.MkdirAll(dir, 0700); err != nil {
			t.Fatal(err)
		}
		raw := `{"schemaVersion":1,"generation":7,"privacy":"passive","tools":{"gemini":{"allowed":true,"consentTextVersion":2,"at":"2026-01-01T00:00:00Z","readerId":"native:gemini","backend":"native"}}}`
		if err := os.WriteFile(consent.Path(), []byte(raw), 0600); err != nil {
			t.Fatal(err)
		}
		before := snapshot(dir)
		if _, err := NewSharedBackend(config(home)); err == nil {
			t.Fatal("legacy store without an epoch admitted a read-only view")
		}
		if after := snapshot(dir); len(after) != len(before) || after[filepath.Base(consent.Path())] != raw {
			t.Fatalf("read-only start changed the consent directory: %v -> %v", names(before), names(after))
		}
	})
	t.Run("v2", func(t *testing.T) {
		home := t.TempDir()
		t.Setenv("HOME", home)
		if _, err := consent.EnsureStore(consent.Path()); err != nil {
			t.Fatal(err)
		}
		dir := filepath.Dir(consent.Path())
		_ = os.Remove(consent.Path() + ".lock")
		before := snapshot(dir)
		b, err := NewSharedBackend(config(home))
		if err != nil {
			t.Fatal(err)
		}
		view, err := b.Get(context.Background())
		if err != nil {
			t.Fatal(err)
		}
		published := false
		if err := b.Publish(context.Background(), view.Stamp, func() error { published = true; return nil }); err != nil || !published {
			t.Fatal("read-only publish refused", err)
		}
		after := snapshot(dir)
		if len(after) != len(before) {
			t.Fatalf("read-only session changed the consent directory: %v -> %v", names(before), names(after))
		}
		for name, content := range before {
			if after[name] != content {
				t.Fatalf("read-only session rewrote %s", name)
			}
		}
	})
}

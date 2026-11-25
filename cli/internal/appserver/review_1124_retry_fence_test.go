//go:build darwin || linux

// SPDX-License-Identifier: MIT
package appserver

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// macrevb-1218-5: a live retry snapshotted an owed Forget, waited for the reader lock outside
// the consent lock, and then erased even though a confirmed reset, a new-epoch grant and a fresh
// capture had happened meanwhile. Invariant: erasure authority never outlives the store epoch
// (or the obligation) that granted it; a stale retry deletes nothing admitted afterwards, while
// an authorized retry still erases without holding up a foreground Deny.
func TestReviewRetryCannotEraseARecoveredProfilesNewCapture(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_READERS", "automatic")
	consent.SetReadOnlyProcess(false)
	cache := filepath.Join(home, "cache")
	observed := filepath.Join(cache, "observed")
	if err := os.MkdirAll(observed, 0700); err != nil {
		t.Fatal(err)
	}
	capture := filepath.Join(observed, "history-v1-zai-"+strings.Repeat("ab", 32)+".json")
	write := func(body string) {
		t.Helper()
		if err := os.WriteFile(capture, []byte(body), 0600); err != nil {
			t.Fatal(err)
		}
	}
	scope := consent.ScopeZaiLocalHistory
	failFast := consent.GrantHooks{Cleanup: func(string, bool) error { return errors.New("reader lock busy") }}
	admit := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) { return consent.Record{}, nil }, Cleanup: failFast.Cleanup}
	entered := make(chan struct{}, 4)
	// The production erasure hook (cmd/modelplan/app_server.go), with an entry signal.
	erase := func(scope string, forget bool, guard consent.EraseGuard) error {
		entered <- struct{}{}
		return quota.EraseScopeGuarded(quota.Paths{Cache: cache}, scope, forget, guard)
	}
	forgetOwed := func(id string) {
		t.Helper()
		s, err := consent.Load(consent.Path())
		if err != nil {
			t.Fatal(err)
		}
		r, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: id, ExpectStoreEpoch: s.StoreEpoch, ExpectGeneration: s.Generation, ConsentTextVersion: consent.TextVersion, Forget: []string{scope}}, failFast)
		if err != nil || r.Code != "cleanup_pending" {
			t.Fatal("forget did not leave erasure owed", r, err)
		}
	}
	startRetry := func() (chan error, func()) {
		t.Helper()
		reader, err := consent.ReaderLock() // a running reader pauses the retry before erasure
		if err != nil {
			t.Fatal(err)
		}
		done := make(chan error, 1)
		go func() { done <- consent.RetryCleanup(consent.Path(), erase) }()
		select {
		case <-entered: // the retry holds its snapshot and waits for the reader lock
		case <-time.After(5 * time.Second):
			reader()
			t.Fatal("retry never reached erasure")
		}
		return done, reader
	}
	wait := func(done chan error) {
		t.Helper()
		select {
		case err := <-done:
			if err != nil {
				t.Fatal(err)
			}
		case <-time.After(10 * time.Second):
			t.Fatal("retry did not finish")
		}
	}

	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	write("old-epoch")
	forgetOwed("forget-old")

	// 1. Stale retry: reset, grant in the new epoch and capture while it waits.
	done, reader := startRetry()
	reset, err := consent.Reset(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	grant, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "grant-new", ExpectStoreEpoch: reset.StoreEpoch, ExpectGeneration: reset.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{scope}}, admit)
	if err != nil || !grant.Committed {
		reader()
		t.Fatal("new-epoch grant failed", grant, err)
	}
	write("new-epoch") // the running reader commits a fresh capture under its lock
	reader()
	wait(done)
	if body, err := os.ReadFile(capture); err != nil || string(body) != "new-epoch" {
		t.Fatalf("stale retry erased the recovered profile's new capture: %q %v", body, err)
	}

	// 2. Authorized retry in the current epoch: it erases, and a foreground Deny commits meanwhile.
	forgetOwed("forget-new")
	done, reader = startRetry()
	current, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	began := time.Now()
	deny, err := consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "deny-gemini", ExpectStoreEpoch: current.StoreEpoch, ExpectGeneration: current.Generation, Deny: []string{consent.ScopeGeminiAccountUsageSavedLogin}}, failFast)
	if err != nil || !deny.Committed || time.Since(began) > time.Second {
		reader()
		t.Fatal("foreground deny waited on background erasure", deny, err, time.Since(began))
	}
	reader()
	wait(done)
	if _, err := os.Stat(capture); !os.IsNotExist(err) {
		t.Fatal("authorized retry did not erase the owed capture", err)
	}
	// The Deny moved the fence, so the first pass leaves its bookkeeping; the next one clears it.
	if err := consent.RetryCleanup(consent.Path(), func(scope string, forget bool, guard consent.EraseGuard) error {
		return quota.EraseScopeGuarded(quota.Paths{Cache: cache}, scope, forget, guard)
	}); err != nil {
		t.Fatal(err)
	}
	if owed := owedScopes(t); len(owed) != 0 {
		t.Fatal("authorized erasure still owed", owed)
	}
}

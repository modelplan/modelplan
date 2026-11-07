// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"errors"
	"reflect"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestAppPublicationDueRule(t *testing.T) {
	now := time.Date(2026, 11, 7, 12, 0, 0, 0, time.UTC)
	fresh := store.State{CheckedAt: now.Add(-time.Hour), LastAttemptAt: now.Add(-time.Hour)}
	stale := store.State{CheckedAt: now.Add(-staleAfter - time.Minute), LastAttemptAt: now.Add(-staleAfter - time.Minute)}
	justTried := store.State{CheckedAt: now.Add(-staleAfter - time.Minute), LastAttemptAt: now.Add(-time.Minute)}
	f := newPublicationFixture(t, nil)
	d := loadedFixture(t, f)
	for name, c := range map[string]struct {
		state store.State
		want  bool
	}{"fresh": {fresh, false}, "stale": {stale, true}, "another client just tried": {justTried, false}} {
		if got := publicationSyncDue(d, c.state, now); got != c.want {
			t.Errorf("%s: %v", name, got)
		}
	}
	if !publicationSyncDue(nil, store.State{}, now) {
		t.Error("an empty cache is due")
	}
}

func loadedFixture(t *testing.T, f publicationFixture) *digest.Digest {
	t.Helper()
	st := &store.Store{Dir: t.TempDir()}
	saveFixture(t, st, f, store.State{})
	d, _, err := publication.Load(st)
	if err != nil {
		t.Fatal(err)
	}
	return d
}

func saveFixture(t *testing.T, st *store.Store, f publicationFixture, state store.State) {
	t.Helper()
	t.Setenv("MODELPLAN_CACHE", st.Dir)
	if _, err := store.Open(); err != nil {
		t.Fatal(err)
	}
	if err := st.PutObject(f.objectHash, f.object); err != nil {
		t.Fatal(err)
	}
	if err := st.PutManifest(f.id, f.manifest); err != nil {
		t.Fatal(err)
	}
	state.PublicationID, state.ManifestHash, state.Component, state.ComponentHash = f.id, publicationHash(f.manifest), "client", f.objectHash
	if err := st.SaveState(state); err != nil {
		t.Fatal(err)
	}
}

// scriptedAppPublication runs the real loop with a scripted sync and records every delay. The
// loop stops when the script runs out.
func scriptedAppPublication(st *store.Store, now time.Time, script []func() error) (*appPublication, *[]time.Duration, *int, *int) {
	delays, syncs, changes := []time.Duration{}, 0, 0
	ctx, cancel := context.WithCancel(context.Background())
	a := &appPublication{st: st, now: func() time.Time { return now }, changed: func() { changes++ }, ctx: ctx, cancel: cancel, done: make(chan struct{})}
	a.sync = func(context.Context) (publication.Result, error) {
		step := script[syncs]
		syncs++
		return publication.Result{}, step()
	}
	a.wait = func(_ context.Context, d time.Duration) error {
		delays = append(delays, d)
		if syncs == len(script) {
			return context.Canceled
		}
		return nil
	}
	return a, &delays, &syncs, &changes
}

func TestAppPublicationBacksOffWhileThereIsNothingToShow(t *testing.T) {
	down := func() error { return errors.New("offline") }
	a, delays, _, changes := scriptedAppPublication(&store.Store{Dir: t.TempDir()}, time.Now(), []func() error{down, down, down, down, down, down, down})
	a.run(context.Background())
	want := []time.Duration{30 * time.Second, time.Minute, 2 * time.Minute, 4 * time.Minute, 8 * time.Minute, 10 * time.Minute, 10 * time.Minute}
	if !reflect.DeepEqual(*delays, want) || *changes != 0 {
		t.Fatalf("delays %v changes %d", *delays, *changes)
	}
}

func TestAppPublicationBusyLockRetriesWithoutBackingOff(t *testing.T) {
	busy := func() error { return store.ErrBusy }
	down := func() error { return errors.New("offline") }
	a, delays, _, _ := scriptedAppPublication(&store.Store{Dir: t.TempDir()}, time.Now(), []func() error{busy, busy, down})
	a.run(context.Background())
	if want := []time.Duration{15 * time.Second, 15 * time.Second, 30 * time.Second}; !reflect.DeepEqual(*delays, want) {
		t.Fatalf("delays %v", *delays)
	}
}

func TestAppPublicationArrivalNotifiesAndSettles(t *testing.T) {
	st := &store.Store{Dir: t.TempDir()}
	f := newPublicationFixture(t, nil)
	down := func() error { return errors.New("offline") }
	arrive := func() error { saveFixture(t, st, f, store.State{}); return nil }
	a, delays, _, changes := scriptedAppPublication(st, time.Now(), []func() error{down, arrive})
	a.run(context.Background())
	if want := []time.Duration{30 * time.Second, backgroundEvery}; !reflect.DeepEqual(*delays, want) || *changes != 1 {
		t.Fatalf("delays %v changes %d", *delays, *changes)
	}
}

// A long-running app keeps data fresh on the shared rule, and a failed refresh of data it can
// still show waits the ordinary interval rather than the empty-cache back-off.
func TestAppPublicationCachedDataFollowsSharedRule(t *testing.T) {
	st := &store.Store{Dir: t.TempDir()}
	now := time.Now()
	saveFixture(t, st, newPublicationFixture(t, nil), store.State{CheckedAt: now.Add(-time.Hour), LastAttemptAt: now.Add(-time.Hour)})
	a, _, syncs, _ := scriptedAppPublication(st, now, nil)
	failures := 0
	if got := a.pass(context.Background(), &failures); got != backgroundEvery || *syncs != 0 {
		t.Fatalf("fresh cache: %v, %d syncs", got, *syncs)
	}
	saveFixture(t, st, newPublicationFixture(t, nil), store.State{CheckedAt: now.Add(-staleAfter - time.Hour), LastAttemptAt: now.Add(-staleAfter - time.Hour)})
	a, _, syncs, _ = scriptedAppPublication(st, now, []func() error{func() error { return errors.New("offline") }})
	if got := a.pass(context.Background(), &failures); got != backgroundEvery || *syncs != 1 {
		t.Fatalf("stale cache: %v, %d syncs", got, *syncs)
	}
}

func TestAppPublicationCloseWithoutStart(t *testing.T) {
	a := newAppPublication(context.Background(), &store.Store{Dir: t.TempDir()}, "http://127.0.0.1:1", func() {})
	a.Close()
	a.Start() // a session that races shutdown must not start after Close
	if newAppPublication(context.Background(), &store.Store{Dir: t.TempDir()}, "http://example.test", func() {}) != nil {
		t.Fatal("a plain-http remote base must not be used")
	}
}

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
func scriptedAppPublication(st *store.Store, now time.Time, script []func() error) (*appPublication, *[]time.Duration, *int) {
	delays, syncs := []time.Duration{}, 0
	ctx, cancel := context.WithCancel(context.Background())
	a := &appPublication{st: st, now: func() time.Time { return now }, ctx: ctx, cancel: cancel, done: make(chan struct{})}
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
	return a, &delays, &syncs
}

func TestAppPublicationBacksOffWhileThereIsNothingToShow(t *testing.T) {
	down := func() error { return errors.New("offline") }
	a, delays, _ := scriptedAppPublication(&store.Store{Dir: t.TempDir()}, time.Now(), []func() error{down, down, down, down, down, down, down})
	a.run(context.Background())
	want := []time.Duration{30 * time.Second, time.Minute, 2 * time.Minute, 4 * time.Minute, 8 * time.Minute, 10 * time.Minute, 10 * time.Minute}
	if !reflect.DeepEqual(*delays, want) {
		t.Fatalf("delays %v", *delays)
	}
}

func TestAppPublicationBusyLockRetriesWithoutBackingOff(t *testing.T) {
	busy := func() error { return store.ErrBusy }
	down := func() error { return errors.New("offline") }
	a, delays, _ := scriptedAppPublication(&store.Store{Dir: t.TempDir()}, time.Now(), []func() error{busy, busy, down})
	a.run(context.Background())
	if want := []time.Duration{15 * time.Second, 15 * time.Second, 30 * time.Second}; !reflect.DeepEqual(*delays, want) {
		t.Fatalf("delays %v", *delays)
	}
}

func TestAppPublicationArrivalSettles(t *testing.T) {
	st := &store.Store{Dir: t.TempDir()}
	f := newPublicationFixture(t, nil)
	down := func() error { return errors.New("offline") }
	arrive := func() error { saveFixture(t, st, f, store.State{}); return nil }
	a, delays, _ := scriptedAppPublication(st, time.Now(), []func() error{down, arrive})
	a.run(context.Background())
	if want := []time.Duration{30 * time.Second, backgroundEvery}; !reflect.DeepEqual(*delays, want) {
		t.Fatalf("delays %v", *delays)
	}
}

// A long-running app keeps data fresh on the shared rule, and a failed refresh of data it can
// still show waits the ordinary interval rather than the empty-cache back-off.
func TestAppPublicationCachedDataFollowsSharedRule(t *testing.T) {
	st := &store.Store{Dir: t.TempDir()}
	now := time.Now()
	saveFixture(t, st, newPublicationFixture(t, nil), store.State{CheckedAt: now.Add(-time.Hour), LastAttemptAt: now.Add(-time.Hour)})
	a, _, syncs := scriptedAppPublication(st, now, nil)
	failures := 0
	if got := a.pass(context.Background(), &failures); got != backgroundEvery || *syncs != 0 {
		t.Fatalf("fresh cache: %v, %d syncs", got, *syncs)
	}
	saveFixture(t, st, newPublicationFixture(t, nil), store.State{CheckedAt: now.Add(-staleAfter - time.Hour), LastAttemptAt: now.Add(-staleAfter - time.Hour)})
	a, _, syncs = scriptedAppPublication(st, now, []func() error{func() error { return errors.New("offline") }})
	if got := a.pass(context.Background(), &failures); got != backgroundEvery || *syncs != 1 {
		t.Fatalf("stale cache: %v, %d syncs", got, *syncs)
	}
}

func TestAppPublicationCloseWithoutStart(t *testing.T) {
	a := newAppPublication(context.Background(), &store.Store{Dir: t.TempDir()}, "http://127.0.0.1:1")
	a.Close()
	a.Start() // a session that races shutdown must not start after Close
	if newAppPublication(context.Background(), &store.Store{Dir: t.TempDir()}, "http://example.test") != nil {
		t.Fatal("a plain-http remote base must not be used")
	}
}

// DOCK-3.8-30: reset notices refresh every 15-30 minutes while a subscription is enabled; the
// ordinary six-hour rule is untouched.
func TestAppPublicationResetNoticeCadence(t *testing.T) {
	now := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	st := &store.Store{Dir: t.TempDir()}
	f := newPublicationFixture(t, nil)
	at := func(checked time.Duration) {
		saveFixture(t, st, f, store.State{CheckedAt: now.Add(-checked), LastAttemptAt: now.Add(-checked)})
	}
	cases := []struct {
		name       string
		subscribed bool
		jitter     time.Duration
		age        time.Duration
		wantSyncs  int
	}{
		{"before 15 min", true, 0, 14 * time.Minute, 0},
		{"after 15 min with no jitter", true, 0, 16 * time.Minute, 1},
		{"jitter pushes it to 30 min", true, resetNoticeSpread, 29 * time.Minute, 0},
		{"after 30 min at the latest", true, resetNoticeSpread, 31 * time.Minute, 1},
		{"jitter above the range is clamped", true, time.Hour, 31 * time.Minute, 1},
		{"no subscription keeps 6 h", false, 0, time.Hour, 0},
		{"no subscription syncs after 6 h", false, 0, staleAfter + time.Minute, 1},
	}
	for _, c := range cases {
		at(c.age)
		a, _, syncs := scriptedAppPublication(st, now, []func() error{func() error { return nil }})
		a.subscribed = func() bool { return c.subscribed }
		a.jitter = func() time.Duration { return c.jitter }
		failures := 0
		a.pass(context.Background(), &failures)
		if *syncs != c.wantSyncs {
			t.Errorf("%s: %d syncs, want %d", c.name, *syncs, c.wantSyncs)
		}
	}
}

func TestAppPublicationResetNoticeJitterIsDrawnPerCheck(t *testing.T) {
	a := &appPublication{subscribed: func() bool { return true }}
	seen := map[time.Duration]bool{}
	for range 200 {
		d := a.drawResetAfter()
		if d < resetNoticeMin || d > resetNoticeMax {
			t.Fatalf("draw %v outside 15-30 min", d)
		}
		seen[d] = true
	}
	if len(seen) < 20 {
		t.Fatalf("draws are not spread: %d distinct", len(seen))
	}
}

func TestAppPublicationResetNoticeBacksOffOnFailure(t *testing.T) {
	now := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	st := &store.Store{Dir: t.TempDir()}
	saveFixture(t, st, newPublicationFixture(t, nil), store.State{CheckedAt: now.Add(-time.Hour), LastAttemptAt: now.Add(-time.Hour)})
	down := func() error { return errors.New("offline") }
	a, _, _ := scriptedAppPublication(st, now, []func() error{down, down, down, down})
	a.subscribed = func() bool { return true }
	a.jitter = func() time.Duration { return 0 }
	failures := 0
	var got []time.Duration
	for range 4 {
		got = append(got, a.pass(context.Background(), &failures))
	}
	want := []time.Duration{10 * time.Minute, 20 * time.Minute, 30 * time.Minute, 30 * time.Minute}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("backoff %v, want %v", got, want)
	}
}

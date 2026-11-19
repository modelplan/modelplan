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
	"github.com/modelplan/modelplan/cli/internal/quota"
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

// macrevc-895-1: a not-due pass sleeps to the real deadline (15-30 min, not a ten-minute grid that stretches it to
// 39), and a failed check's backoff count survives a pass that finds nothing due.
func TestAppPublicationSleepsToTheRealDeadlineAndKeepsFailureCount(t *testing.T) {
	now := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	st := &store.Store{Dir: t.TempDir()}
	f := newPublicationFixture(t, nil)
	saveFixture(t, st, f, store.State{CheckedAt: now.Add(-14 * time.Minute), LastAttemptAt: now.Add(-14 * time.Minute)})
	a, _, syncs := scriptedAppPublication(st, now, []func() error{func() error { return nil }})
	a.subscribed = func() bool { return true }
	a.jitter = func() time.Duration { return 0 }
	failures := 2
	got := a.pass(context.Background(), &failures)
	if *syncs != 0 || got != time.Minute+time.Second || failures != 2 {
		t.Fatalf("not due at 14 min: syncs=%d delay=%v failures=%d, want 0, 1m1s, 2", *syncs, got, failures)
	}
	// Far from any deadline the wake-up stays at the regular ten minutes.
	saveFixture(t, st, f, store.State{CheckedAt: now.Add(-time.Minute), LastAttemptAt: now.Add(-time.Minute)})
	a.resetAfter = 0
	if got := a.pass(context.Background(), &failures); got != backgroundEvery {
		t.Fatalf("far from due: delay %v", got)
	}
	// Without a subscription only the six-hour rule counts.
	a.subscribed = func() bool { return false }
	saveFixture(t, st, f, store.State{CheckedAt: now.Add(-staleAfter + 3*time.Minute), LastAttemptAt: now.Add(-staleAfter + 3*time.Minute)})
	if got := a.pass(context.Background(), &failures); got != 3*time.Minute+time.Second {
		t.Fatalf("six-hour deadline: delay %v", got)
	}
}

// macrevc-895-1 (third head): a failed check is retried at its own 10-minute deadline, even when the next normal
// interval is redrawn longer than the time that has passed.
func TestAppPublicationFailedCheckRetriesOnItsOwnDeadline(t *testing.T) {
	t0 := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	clock := t0
	st := &store.Store{Dir: t.TempDir()}
	f := newPublicationFixture(t, nil)
	saveFixture(t, st, f, store.State{CheckedAt: t0.Add(-16 * time.Minute), LastAttemptAt: t0.Add(-16 * time.Minute)})
	calls := 0
	ok := func() error { return nil }
	down := func() error { return errors.New("offline") }
	a, _, syncs := scriptedAppPublication(st, t0, []func() error{down, ok})
	a.now = func() time.Time { return clock }
	a.sync = func(context.Context) (publication.Result, error) {
		calls++
		if calls == 1 {
			return publication.Result{}, down()
		}
		return publication.Result{}, ok()
	}
	a.subscribed = func() bool { return true }
	draws := []time.Duration{0, resetNoticeSpread}
	a.jitter = func() time.Duration { d := draws[0]; draws = append(draws[1:], resetNoticeSpread); return d }
	failures := 0
	if got := a.pass(context.Background(), &failures); got != 10*time.Minute || calls != 1 {
		t.Fatalf("first failure: delay %v, syncs %d, want 10m, 1", got, calls)
	}
	// The failed attempt is recorded by the real sync; this stub records it here.
	saveFixture(t, st, f, store.State{CheckedAt: t0.Add(-16 * time.Minute), LastAttemptAt: t0})
	clock = t0.Add(10*time.Minute + time.Second)
	a.pass(context.Background(), &failures)
	if calls != 2 {
		t.Fatalf("no retry after the 10-minute backoff (syncs %d, scripted %d)", calls, *syncs)
	}
}

// macrevc-895-1 (fourth head): a due retry that finds sync.lock busy keeps its deadline, so it is tried again after
// the short busy wait instead of waiting for a redrawn normal interval. Failure, due retry, busy, successful retry.
func TestAppPublicationBusyRetryKeepsItsDeadline(t *testing.T) {
	t0 := time.Date(2026, 11, 12, 12, 0, 0, 0, time.UTC)
	clock := t0
	st := &store.Store{Dir: t.TempDir()}
	f := newPublicationFixture(t, nil)
	saveFixture(t, st, f, store.State{CheckedAt: t0.Add(-16 * time.Minute), LastAttemptAt: t0.Add(-16 * time.Minute)})
	script := []error{errors.New("offline"), store.ErrBusy, nil}
	calls := 0
	a, _, _ := scriptedAppPublication(st, t0, nil)
	a.now = func() time.Time { return clock }
	a.sync = func(context.Context) (publication.Result, error) {
		if calls >= len(script) {
			t.Fatalf("unexpected sync %d", calls+1)
		}
		err := script[calls]
		calls++
		return publication.Result{}, err
	}
	a.subscribed = func() bool { return true }
	// The first draw makes the 16-minute-old cache due; every later draw is the full 30 minutes, so only the pending
	// retry can make the later passes due.
	draws := []time.Duration{0}
	a.jitter = func() time.Duration {
		if len(draws) == 0 {
			return resetNoticeSpread
		}
		d := draws[0]
		draws = draws[1:]
		return d
	}
	failures := 0
	if got := a.pass(context.Background(), &failures); got != 10*time.Minute || calls != 1 {
		t.Fatalf("first failure: delay %v, syncs %d, want 10m, 1", got, calls)
	}
	retry := a.retryAt
	if !retry.Equal(t0.Add(10 * time.Minute)) {
		t.Fatalf("retry deadline %v, want %v", retry, t0.Add(10*time.Minute))
	}
	// The failed attempt is recorded by the real sync; this stub records it here. A busy lock records nothing.
	saveFixture(t, st, f, store.State{CheckedAt: t0.Add(-16 * time.Minute), LastAttemptAt: t0})
	clock = t0.Add(10*time.Minute + time.Second)
	if got := a.pass(context.Background(), &failures); got != appPublicationBusyRetry || calls != 2 {
		t.Fatalf("due retry with a busy lock: delay %v, syncs %d, want %v, 2", got, calls, appPublicationBusyRetry)
	}
	if !a.retryAt.Equal(retry) || failures != 1 {
		t.Fatalf("after busy: retry deadline %v, failures %d, want %v, 1", a.retryAt, failures, retry)
	}
	clock = clock.Add(appPublicationBusyRetry)
	a.pass(context.Background(), &failures)
	if calls != 3 {
		t.Fatalf("the retry was deferred after a busy lock (syncs %d, want 3)", calls)
	}
	if !a.retryAt.IsZero() || failures != 0 {
		t.Fatalf("after the successful retry: retry deadline %v, failures %d, want none, 0", a.retryAt, failures)
	}
}

// macrevc-895-2: only an enabled reader's account bound to a subscription it saw turns on the faster cadence.
func TestAppPublicationTrackedSubscriptionGate(t *testing.T) {
	bound := func(status, ref string) *quota.Binding {
		return &quota.Binding{Ref: ref, Status: status, Basis: "codex-account"}
	}
	for _, c := range []struct {
		name     string
		accounts []quota.Account
		want     bool
	}{
		{"no accounts (readers off or none enabled)", nil, false},
		{"user declaration only", []quota.Account{{Source: "user", Plan: "codex-plus"}}, false},
		{"reader account without a binding", []quota.Account{{Source: "codex"}}, false},
		{"binding not verified", []quota.Account{{Source: "codex", Subscription: bound("unverified", "0123456789abcdef")}}, false},
		{"verified binding without a reference", []quota.Account{{Source: "codex", Subscription: bound("verified", "")}}, false},
		{"bound tracked subscription", []quota.Account{{Source: "codex", Subscription: bound("verified", "0123456789abcdef")}}, true},
		{"declaration beside a bound subscription", []quota.Account{{Source: "user"}, {Source: "claude-code", Subscription: bound("verified", "fedcba9876543210")}}, true},
	} {
		if got := hasTrackedSubscription(c.accounts); got != c.want {
			t.Errorf("%s: %v, want %v", c.name, got, c.want)
		}
	}
}

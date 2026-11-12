// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"errors"
	"math/rand/v2"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/store"
)

const (
	// While there is nothing to show, retry soon and back off to the ordinary spacing.
	appPublicationRetry = 30 * time.Second
	// Another client holds sync.lock, or an abandoned lock is waiting out its two minutes.
	appPublicationBusyRetry = 15 * time.Second
	// The foreground sync command's limit; each request also has its own timeout.
	appPublicationSyncLimit = 2 * time.Minute
	// DOCK-3.8-30 (D148): announced reset notices travel in the publication, so while the user
	// has an enabled subscription the app re-checks the pointer (a conditional ETag request, a
	// 304 when nothing changed) every 15-30 minutes instead of every six hours. Each client
	// draws its own point in that range so clients do not sync in lockstep.
	resetNoticeMin    = 15 * time.Minute
	resetNoticeSpread = 15 * time.Minute
	resetNoticeMax    = resetNoticeMin + resetNoticeSpread
)

// publicationSyncDue is the shared background rule: a missing or stale publication, and no
// attempt by any client in the last ten minutes.
func publicationSyncDue(d *digest.Digest, s store.State, now time.Time) bool {
	return (d == nil || now.Sub(s.CheckedAt) > staleAfter) && now.Sub(s.LastAttemptAt) > backgroundEvery
}

// resetNoticeDue is the faster rule for reset notices only; everything else keeps staleAfter.
func (a *appPublication) resetNoticeDue(s store.State, now time.Time) bool {
	if a.subscribed == nil || !a.subscribed() {
		return false
	}
	if a.resetAfter <= 0 {
		a.resetAfter = a.drawResetAfter()
	}
	return now.Sub(s.CheckedAt) > a.resetAfter && now.Sub(s.LastAttemptAt) > a.every()
}

// every is the wake-up and the minimum gap between two attempts (ten minutes unless a test build says otherwise).
func (a *appPublication) every() time.Duration {
	if a.testCadence > 0 {
		return a.testCadence
	}
	return backgroundEvery
}

func (a *appPublication) drawResetAfter() time.Duration {
	if a.testCadence > 0 {
		return a.testCadence // test builds only, see app_publication_testcadence.go
	}
	j := time.Duration(0)
	if a.jitter != nil {
		j = a.jitter()
	} else {
		j = time.Duration(rand.Int64N(int64(resetNoticeSpread) + 1))
	}
	return resetNoticeMin + min(max(j, 0), resetNoticeSpread)
}

func appPublicationBase() string { return env("MODELPLAN_BASE", publication.DefaultBase) }

// appPublication keeps the verified publication current for an app that nothing else syncs for:
// the status line and hooks do it only where a plugin is installed. It is the ordinary
// publication.Client.Sync, so the same lock, interval and verification apply. The publication
// is public: a request carries no account data, and no consent scope or reader setting applies.
// Sync writes state.json last, and the backend already watches that file, so subscribers get the
// rows event the cockpit refreshes on without being told.
type appPublication struct {
	st   *store.Store
	sync func(context.Context) (publication.Result, error)
	now  func() time.Time
	wait func(context.Context, time.Duration) error
	// subscribed reports whether the user has at least one enabled subscription; nil means no.
	subscribed func() bool
	// jitter returns a duration in [0, resetNoticeSpread]; tests may inject it.
	jitter func() time.Duration
	// resetAfter is this client's current reset-notice interval, redrawn after each check.
	resetAfter time.Duration
	// testCadence is set only by a binary built with the modelplan_test_cadence tag (never in a release): it replaces
	// the 10-minute wake-up and the 15-30 minute reset-notice interval.
	testCadence time.Duration

	ctx    context.Context
	cancel context.CancelFunc
	once   sync.Once
	done   chan struct{}
}

// newAppPublication returns nil for an unusable base. The app-server then runs on what is
// cached, as it does with --offline.
func newAppPublication(ctx context.Context, st *store.Store, base string) *appPublication {
	if _, err := publication.New(base, st, version); err != nil {
		return nil
	}
	ctx, cancel := context.WithCancel(ctx)
	return &appPublication{st: st, now: time.Now, ctx: ctx, cancel: cancel, done: make(chan struct{}), wait: func(ctx context.Context, d time.Duration) error {
		timer := time.NewTimer(d)
		defer timer.Stop()
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-timer.C:
			return nil
		}
	}, sync: func(ctx context.Context) (publication.Result, error) {
		// The app-server only locates its cache so that read-only sessions create nothing.
		opened, err := store.Open()
		if err != nil {
			return publication.Result{}, err
		}
		client, err := publication.New(base, opened, version)
		if err != nil {
			return publication.Result{}, err
		}
		if testCadenceOn() { // test builds only
			client.NoCheckDelay = true
			client.Jitter = func() time.Duration { return 0 }
		}
		ctx, cancel := context.WithTimeout(ctx, appPublicationSyncLimit)
		defer cancel()
		return client.Sync(ctx, false)
	}}
}

// Start begins on the first initialized session. It never holds up the session.
func (a *appPublication) Start() {
	a.once.Do(func() {
		go func() {
			defer close(a.done)
			a.run(a.ctx)
		}()
	})
}

// Close stops any request in flight and waits, so sync.lock is not left behind.
func (a *appPublication) Close() {
	a.cancel()
	a.once.Do(func() { close(a.done) })
	<-a.done
}

func (a *appPublication) run(ctx context.Context) {
	failures := 0
	for ctx.Err() == nil {
		if a.wait(ctx, a.pass(ctx, &failures)) != nil {
			return
		}
	}
}

// pass makes at most one sync and returns the delay before the next look. The wake-up itself
// reads only the local cache. Without a publication it attempts whatever another client's last
// attempt was, because Sync has no interval for an empty cache and the app has nothing to show;
// retries are spaced here.
func (a *appPublication) pass(ctx context.Context, failures *int) time.Duration {
	d, s, _ := publication.Load(a.st)
	if d != nil && !publicationSyncDue(d, s, a.now()) && !a.resetNoticeDue(s, a.now()) {
		*failures = 0
		return a.every()
	}
	a.resetAfter = 0 // redraw after every check
	_, err := a.sync(ctx)
	if errors.Is(err, store.ErrBusy) {
		return appPublicationBusyRetry
	}
	if err == nil {
		d, _, _ = publication.Load(a.st)
	}
	if d != nil {
		if err != nil && a.subscribed != nil && a.subscribed() {
			// A failed reset-notice check backs off 10, 20, then 30 minutes.
			delay := min(a.every()<<min(*failures, 2), resetNoticeMax)
			*failures++
			return delay
		}
		*failures = 0
		return a.every()
	}
	delay := min(appPublicationRetry<<min(*failures, 5), backgroundEvery)
	*failures++
	return delay
}

// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"errors"
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
)

// publicationSyncDue is the shared background rule: a missing or stale publication, and no
// attempt by any client in the last ten minutes.
func publicationSyncDue(d *digest.Digest, s store.State, now time.Time) bool {
	return (d == nil || now.Sub(s.CheckedAt) > staleAfter) && now.Sub(s.LastAttemptAt) > backgroundEvery
}

func appPublicationBase() string { return env("MODELPLAN_BASE", publication.DefaultBase) }

// appPublication keeps the verified publication current for an app that nothing else syncs for:
// the status line and hooks do it only where a plugin is installed. It is the ordinary
// publication.Client.Sync, so the same lock, interval and verification apply. The publication
// is public: a request carries no account data, and no consent scope or reader setting applies.
type appPublication struct {
	st      *store.Store
	sync    func(context.Context) (publication.Result, error)
	changed func()
	now     func() time.Time
	wait    func(context.Context, time.Duration) error

	ctx    context.Context
	cancel context.CancelFunc
	once   sync.Once
	done   chan struct{}
}

// newAppPublication returns nil for an unusable base. The app-server then runs on what is
// cached, as it does with --offline.
func newAppPublication(ctx context.Context, st *store.Store, base string, changed func()) *appPublication {
	if _, err := publication.New(base, st, version); err != nil {
		return nil
	}
	ctx, cancel := context.WithCancel(ctx)
	return &appPublication{st: st, changed: changed, now: time.Now, ctx: ctx, cancel: cancel, done: make(chan struct{}), wait: func(ctx context.Context, d time.Duration) error {
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
	if d != nil && !publicationSyncDue(d, s, a.now()) {
		*failures = 0
		return backgroundEvery
	}
	_, err := a.sync(ctx)
	if errors.Is(err, store.ErrBusy) {
		return appPublicationBusyRetry
	}
	if err == nil {
		// Level-triggered: the rows event goes out only if the view really changed, and the
		// cockpit refreshes on it.
		a.changed()
		d, _, _ = publication.Load(a.st)
	}
	if d != nil {
		*failures = 0
		return backgroundEvery
	}
	delay := min(appPublicationRetry<<min(*failures, 5), backgroundEvery)
	*failures++
	return delay
}

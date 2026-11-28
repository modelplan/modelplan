// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"fmt"
	"io"
	"path/filepath"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/logindex"
	"github.com/modelplan/modelplan/cli/internal/publication"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func appServerCmd(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	options, err := parseAppServerOptions(args)
	if err != nil {
		fmt.Fprintln(stderr, "app-server: invalid_arguments")
		return exitUsage
	}
	in, ok := stdin.(io.ReadCloser)
	if !ok {
		fmt.Fprintln(stderr, "app-server: anonymous input pipe required")
		return exitUsage
	}
	out, ok := stdout.(io.WriteCloser)
	if !ok {
		fmt.Fprintln(stderr, "app-server: anonymous output pipe required")
		return exitUsage
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	server, closeBackend, err := newAppServer(ctx, options)
	if err != nil {
		fmt.Fprintln(stderr, "app-server: internal")
		return exitErr
	}
	defer closeBackend()
	if err := server.Serve(ctx, in, out); err != nil {
		fmt.Fprintln(stderr, "app-server: internal")
		return exitErr
	}
	return 0
}

// newAppServer is the ordinary executable constructor. Transport, framing and
// process supervision remain owned by appserver.Server.
func newAppServer(ctx context.Context, options appServerOptions) (*appserver.Server, func(), error) {
	return newAppServerWithSources(ctx, options, appServerSources{})
}

// A typed history-source seam allows provider/fault tests to retain the real
// consent backend, scheduler and transport. The ordinary constructor uses nil.
type appServerSources struct {
	History func(appserver.Backend, queries.HistorySource) queries.HistorySource
	Detect  func(func() detect.Report) func() detect.Report
	// Clock paces history discovery (the idle-work gates' test clock); nil is time.Now.
	Clock func() time.Time
	// Built receives the shared backend and scheduler the server was built from.
	Built func(*appserver.SharedBackend, *appserver.RefreshScheduler)
}

func newAppServerWithSources(ctx context.Context, options appServerOptions, sources appServerSources) (*appserver.Server, func(), error) {
	st, err := store.Locate()
	if err != nil {
		return nil, func() {}, err
	}
	clock := sources.Clock
	if clock == nil {
		clock = time.Now
	}
	// One history inventory for the activity observer, the rollout selection and the
	// observation pass: discovery is paid once per root (D397).
	inventory := &logindex.Inventory{}
	codexIndex := quota.CodexRolloutIndex{Clock: sources.Clock, Inventory: inventory, RequireTicket: true}
	rawPaths := func(a consent.Admission) quota.Paths {
		p := quota.ProductionPathsWithAdmission(st.Dir, version, a)
		p.CodexIndex = &codexIndex // the appserver hands in the ticket it took before a
		return p
	}
	watchPaths := func(a consent.Admission) quota.Paths {
		p := quota.ProductionWatchPaths(st.Dir)
		p.Admission, p.CodexIndex = &a, &codexIndex // the appserver hands in the ticket it took before a
		return p
	}
	detectTools := func() detect.Report { return detection(st) }
	// D238: tool ids only; a read-only engine keeps the ledger in memory.
	seen := detect.NewSeenLedger(filepath.Join(st.Dir, "detected-tools.json"), options.ReadOnly)
	if sources.Detect != nil {
		detectTools = sources.Detect(detectTools)
	}
	broker := &appserver.CredentialBroker{PathsFor: rawPaths, Offline: options.Offline, ReadOnly: options.ReadOnly}
	paths := broker.Paths
	var importer *appserver.ImportController
	shared, err := appserver.NewSharedBackend(appserver.SharedConfig{
		Granted: func() {
			if importer != nil {
				importer.StartOwedAfter(owedGrantDelay, speed.ImportDefaultDays)
			}
		},
		ManualKeyPresent: func(provider string) bool { return quota.ManualKeyPresent(st.Dir, provider) },
		Activity:         appActivityClock(st.Dir, clock, inventory),
		Reported: func(report quota.Report, now time.Time) {
			if !options.ReadOnly {
				observeQuotaHistory(st, report, now)
			}
		},
		ResetPublication: func() (*digest.Digest, error) { d, _, err := publication.LoadShared(st); return d, err }, // read only (WP-17)
		Detect:           detectTools, LaterInstalled: seen.Observe, Paths: paths, WatchPaths: watchPaths, Ticket: codexIndex.Ticket, Offline: options.Offline, ReadOnly: options.ReadOnly,
		Cleanup: func(scope string, forget bool, guard consent.EraseGuard) error {
			return quota.EraseScopeGuarded(quota.ProductionPaths(st.Dir, version), scope, forget, guard)
		},
	})
	var backend appserver.Backend = shared
	if err != nil {
		backend = appserver.UnavailableBackend{}
	}
	handlers := map[string]appserver.Handler{"plugin/install": appserver.PluginInstallHandler(options.Offline, options.ReadOnly)}
	publication, err := queries.PublicationHandler(queries.VerifiedPublication{Store: st})
	if err != nil {
		return nil, func() {}, err
	}
	handlers["publication/get"] = publication
	for method, h := range appserver.ReaderKeyHandlers(appserver.ReaderKeyConfig{Dir: st.Dir, ReadOnly: options.ReadOnly, Offline: options.Offline}) {
		handlers[method] = h
	}
	if !options.ReadOnly {
		importer = appserver.NewImportController(importEngine{st: st})
		for method, h := range appserver.HistoryImportHandlers(importer) {
			handlers[method] = h
		}
		// G3-112: an import still owed (failed, interrupted, withdrawn, or cleared and granted
		// again) is retried at start and after each committed grant. A fresh profile owes nothing.
		importer.StartOwedAfter(owedLaunchDelay, speed.ImportDefaultDays)
	}
	closeBackend := func() {}
	var scheduler *appserver.RefreshScheduler
	var server *appserver.Server
	if shared != nil {
		var source queries.HistorySource = sharedHistory{backend: shared, cache: st.Dir}
		if sources.History != nil {
			source = sources.History(shared, source)
		}
		history, err := queries.HistoryHandler(queries.HistoryConfig{State: shared, Source: source, Session: appserver.SessionID})
		if err != nil {
			return nil, func() {}, err
		}
		handlers["history/query"] = history
		var cockpitSource queries.CockpitSource = sharedCockpit{backend: shared, cache: st.Dir, publicationStore: st}
		cockpit, err := queries.CockpitHandler(queries.CockpitConfig{State: shared, Source: cockpitSource})
		if err != nil {
			return nil, func() {}, err
		}
		handlers["cockpit/query"] = cockpit
		scheduler = appserver.NewRefreshScheduler(ctx, appserver.RefreshConfig{Backend: shared, Paths: paths, Ticket: codexIndex.Ticket, Run: quota.ExecuteScopeRefresh, Observe: observeForAppIn(st, inventory), ObserveAfter: appserver.ObserveFirstDelay, Offline: options.Offline, ReadOnly: options.ReadOnly, Changed: shared.Notify, CredentialHold: func(provider string) (bool, time.Time) {
			if server == nil {
				return false, time.Time{}
			}
			return server.CredentialHold(provider)
		}})
		handlers["refresh/request"] = scheduler.Handler()
		shared.RefreshDeadline = scheduler.PendingDeadline
		shared.CredentialSink = broker
		broker.Changed = shared.Notify
		closeBackend = scheduler.Close
	}
	if importer != nil {
		closeBase := closeBackend
		closeBackend = func() {
			importer.Close()
			closeBase()
		}
	}
	var fetcher *appPublication
	if !options.Offline && !options.ReadOnly {
		fetcher = newAppPublication(ctx, st, appPublicationBase())
		if fetcher != nil {
			applyTestCadence(fetcher)
			fetcher.subscribed = func() bool {
				return hasTrackedSubscription(quota.ReadPermitted(quota.ProductionPaths(st.Dir, version), time.Now()).Accounts)
			}
		}
	}
	if fetcher != nil {
		closeScheduler := closeBackend
		closeBackend = func() {
			closeScheduler()
			fetcher.Close()
		}
	}
	var decisions func() []wire.RefreshDecision
	if scheduler != nil {
		decisions = scheduler.Decisions
	}
	sessionStarted := func() {
		if scheduler != nil {
			scheduler.StartAutomatic()
		}
		if fetcher != nil {
			fetcher.Start()
		}
	}
	server = appserver.New(appserver.Config{Version: version, Backend: backend, Handlers: handlers, SessionStarted: sessionStarted, RefreshDecisions: decisions, LastErrorClass: func() string {
		state, err := st.State()
		if err != nil {
			return ""
		}
		return store.CleanLastError(state.LastError)
	}})
	broker.Request = server.ReadCredential
	if sources.Built != nil {
		sources.Built(shared, scheduler)
	}
	return server, closeBackend, nil
}

// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"fmt"
	"io"

	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/appserver/queries"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
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
}

func newAppServerWithSources(ctx context.Context, options appServerOptions, sources appServerSources) (*appserver.Server, func(), error) {
	st, err := store.Locate()
	if err != nil {
		return nil, func() {}, err
	}
	rawPaths := func(a consent.Admission) quota.Paths { return quota.ProductionPathsWithAdmission(st.Dir, version, a) }
	detectTools := func() detect.Report { return detection(st) }
	if sources.Detect != nil {
		detectTools = sources.Detect(detectTools)
	}
	broker := &appserver.CredentialBroker{PathsFor: rawPaths, Offline: options.Offline, ReadOnly: options.ReadOnly}
	paths := broker.Paths
	shared, err := appserver.NewSharedBackend(appserver.SharedConfig{
		Detect: detectTools, Paths: paths, Offline: options.Offline, ReadOnly: options.ReadOnly,
		Cleanup: func(scope string, forget bool) error {
			return quota.EraseScope(quota.ProductionPaths(st.Dir, version), scope, forget)
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
		scheduler = appserver.NewRefreshScheduler(ctx, appserver.RefreshConfig{Backend: shared, Paths: paths, Run: quota.ExecuteScopeRefresh, Offline: options.Offline, ReadOnly: options.ReadOnly, Changed: shared.Notify})
		handlers["refresh/request"] = scheduler.Handler()
		shared.CredentialSink = broker
		broker.Changed = shared.Notify
		closeBackend = scheduler.Close
	}
	server = appserver.New(appserver.Config{Version: version, Backend: backend, Handlers: handlers})
	broker.Request = server.ReadCredential
	return server, closeBackend, nil
}

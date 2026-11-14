// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/signal"
	"path/filepath"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

// historyImportCmd runs `history --import` and `history --remove-imported`: the engine behind the
// first-run import and Settings > Data & Privacy. Interrupting (Ctrl-C) cancels without writing.
func historyImportCmd(stdout, stderr io.Writer, st *store.Store, c common, doImport bool, days int, firstRun bool) int {
	if !doImport {
		if err := speed.RemoveImported(st.Dir); err != nil {
			fmt.Fprintln(stderr, err)
			return exitErr
		}
		if c.json {
			return printJSON(stdout, map[string]any{"schemaVersion": 1, "removed": true})
		}
		fmt.Fprintln(stdout, say(c, "Imported history removed.", "已删除导入的历史。"))
		return 0
	}
	if firstRun && !speed.NeedsAutoImport(st.Dir) {
		if c.json {
			return printJSON(stdout, map[string]any{"schemaVersion": 1, "skipped": "already-ran"})
		}
		return 0
	}
	if firstRun {
		if err := speed.MarkAutoRequested(st.Dir, time.Now()); err != nil {
			fmt.Fprintln(stderr, err)
			return exitErr
		}
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	opts := importOptions(st, days, firstRun, time.Now())
	res, err := speed.Import(ctx, st.Dir, opts)
	if err != nil {
		fmt.Fprintln(stderr, err)
		return exitErr
	}
	if c.json {
		return printJSON(stdout, map[string]any{"schemaVersion": 1, "days": res.Days, "cancelled": res.Cancelled, "sources": res.Sources, "file": speed.ImportPath(st.Dir)})
	}
	if res.Cancelled {
		fmt.Fprintln(stdout, say(c, "Import cancelled; nothing was changed.", "导入已取消，未做任何改动。"))
		return 0
	}
	for _, s := range res.Sources {
		fmt.Fprintf(stdout, "%s: %s (%d turns)\n", s.Source, s.Status, s.Turns)
	}
	return 0
}

func say(c common, en, zh string) string {
	if c.lang == "en" {
		return en
	}
	return zh
}

// importOptions: the roots of the tools the user granted history consent for, each write under the
// consent fence. A tool without consent gets no root and is reported as skipped.
func importOptions(st *store.Store, days int, firstRun bool, now time.Time) speed.ImportOptions {
	opts := speed.ImportOptions{Days: days, Now: now, Auto: firstRun,
		Guard: guardLocalWrite}
	if consent.Allowed("claude", consent.Local) {
		home, _ := os.UserHomeDir()
		dir := os.Getenv("CLAUDE_CONFIG_DIR")
		if dir == "" {
			dir = filepath.Join(home, ".claude")
		}
		opts.Claude = &speed.ImportRoot{Dir: dir}
	}
	if consent.Allowed("codex", consent.Local) {
		opts.Codex = &speed.ImportRoot{Dir: quotaPaths(st).CodexHome, Background: func(p string) bool { return quota.Background(quota.ThreadOrigin(p), "") }}
	}
	return opts
}

// firstRunImportPending: a requested first-run import is still owed (it failed, was interrupted
// or found no grant) and a recorded Claude Code or Codex history grant is in force (G3-112). The engine then starts
// it itself; the run skips every source without a grant.
func firstRunImportPending(cache string, a consent.Admission) bool {
	if !speed.AutoImportOwed(cache) {
		return false
	}
	// Only a recorded grant counts: before the user has answered first run, a default-on scope must
	// not start a read of past logs.
	s := a.State()
	for _, scope := range []string{consent.ScopeClaudeLocalHistory, consent.ScopeCodexLocalHistory} {
		if r, decided := s.Scopes[scope]; decided && r.Allowed && s.AllowsScope(scope, a.Mode()) {
			return true
		}
	}
	return false
}

// importEngine adapts the importer to the app-server's history/import_* methods.
type importEngine struct{ st *store.Store }

func (e importEngine) Run(ctx context.Context, days int, firstRun bool, progress func(done, total int)) ([]wire.HistoryImportSource, error) {
	if firstRun && !speed.NeedsAutoImport(e.st.Dir) {
		return []wire.HistoryImportSource{}, nil
	}
	if firstRun {
		if err := speed.MarkAutoRequested(e.st.Dir, time.Now()); err != nil {
			return nil, err
		}
	}
	opts := importOptions(e.st, days, firstRun, time.Now())
	opts.Progress = progress
	res, err := speed.Import(ctx, e.st.Dir, opts)
	if err == nil && res.Cancelled {
		err = context.Canceled // nothing was written
	}
	out := make([]wire.HistoryImportSource, 0, len(res.Sources))
	for _, s := range res.Sources {
		out = append(out, wire.HistoryImportSource{Source: s.Source, Status: wire.HistoryImportSourceStatus(s.Status), Turns: s.Turns})
	}
	return out, err
}

func (e importEngine) State() wire.HistoryImportStatus {
	s := speed.ImportStatus(e.st.Dir)
	out := wire.HistoryImportStatus{FirstRunDone: s.AutoRan, ImportedRows: s.Rows, Coverage: []wire.HistoryImportCoverage{}}
	for _, c := range s.Coverage {
		out.Coverage = append(out.Coverage, wire.HistoryImportCoverage{Source: c.Source, From: c.From, Through: c.Through, Rows: c.Rows})
	}
	return out
}

func (e importEngine) Remove() error { return speed.RemoveImported(e.st.Dir) }

// guardLocalWrite is consent.LocalWrite that waits a few seconds when another reader holds the
// admission lock (the running engine's own observers do, for a moment).
func guardLocalWrite(tool string, write func() error) error {
	var err error
	for i := 0; i < 50; i++ {
		if err = consent.LocalWrite(tool, write); !errors.Is(err, consent.ErrBusy) {
			return err
		}
		time.Sleep(100 * time.Millisecond)
	}
	return err
}

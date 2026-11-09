// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/signal"
	"path/filepath"
	"time"

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
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	opts := speed.ImportOptions{Days: days, Now: time.Now(), Auto: firstRun,
		Guard: func(tool string, write func() error) error { return consent.LocalWrite(tool, write) }}
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

package main

import (
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
	"os"
	"path/filepath"
	"time"
)

func reportWrite(report quota.Report, write func() error) {
	unlock, err := consent.ReaderLock()
	if err != nil {
		return
	}
	defer unlock()
	_ = consent.Publish(consent.Fence{StoreEpoch: report.ConsentStoreEpoch, Generation: report.ConsentGeneration}, write)
}
func observeQuotaHistory(st *store.Store, report quota.Report, now time.Time) {
	reportWrite(report, func() error { return history.Observe(st.Dir, report, now) })
}

// observeForApp is what `desktop` does on each read, for the app-server's scheduler. Without it
// the app shows sessions, rates and Today totals only while a plugin hook happens to feed them.
func observeForApp(st *store.Store) func(quota.Paths, time.Time) {
	return func(paths quota.Paths, now time.Time) {
		report := quota.ReadPermitted(paths, now)
		observeQuotaHistory(st, report, now)
		observeCodexSpeed(st, now)
		observeClaudeSpeed(st, paths, now)
		observeAgents(st, now)
		observeLiveSessions(st, paths, report, now)
	}
}

// observeClaudeSpeed measures the active Claude Code logs, which the plugin hook does on each
// turn. Without the plugin, nothing else records their sessions, project labels or Today totals.
func observeClaudeSpeed(st *store.Store, paths quota.Paths, now time.Time) {
	if !consent.Allowed("claude", consent.Local) {
		return
	}
	home, _ := os.UserHomeDir()
	claude := os.Getenv("CLAUDE_CONFIG_DIR")
	if claude == "" {
		claude = filepath.Join(home, ".claude")
	}
	for _, log := range speed.ActiveLogs(claude, paths.CodexHome, now) {
		if log.Source != "claude-code" || log.Sidechain {
			continue
		}
		_ = consent.LocalWrite("claude", func() error {
			return speed.ObserveClaude(st.Dir, log.Path, false, speed.Ingest{Labels: projectLabels(), Subscription: quota.ClaudeSubscription(st.Dir)}, now)
		})
	}
}

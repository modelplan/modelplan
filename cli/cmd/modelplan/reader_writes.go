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

// observeForApp feeds the app-server's sessions, rates and project labels, which otherwise appear
// only while a plugin hook runs. It runs every 30 seconds, so it must stay off the readers: session
// logs and ModelPlan's own cache only (TestObserveForAppStaysOffReaders).
func observeForApp(st *store.Store) func(time.Time) {
	return func(now time.Time) {
		codex := quota.CodexHome()
		observeCodexHomeSpeed(st, codex, now)
		observeClaudeSpeed(st, codex, now)
		observeAgents(st, now)
		observeLiveLogs(st, codex, cachedSubscriptions(st, now), now)
	}
}

// cachedSubscriptions: the accounts the last completed reads recorded for the tools with session logs.
func cachedSubscriptions(st *store.Store, now time.Time) map[string]string {
	refs := map[string]string{}
	if ref := quota.ClaudeSubscription(st.Dir); ref != "" {
		refs["claude-code"] = ref
	}
	if ref := quota.CodexSubscription(st.Dir, now); ref != "" {
		refs["codex"] = ref
	}
	return refs
}

// observeClaudeSpeed measures the active Claude Code logs, which the plugin hook does on each
// turn. Without the plugin, nothing else records their sessions, project labels or Today totals.
func observeClaudeSpeed(st *store.Store, codexHome string, now time.Time) {
	if !consent.Allowed("claude", consent.Local) {
		return
	}
	home, _ := os.UserHomeDir()
	claude := os.Getenv("CLAUDE_CONFIG_DIR")
	if claude == "" {
		claude = filepath.Join(home, ".claude")
	}
	for _, log := range speed.ActiveLogs(claude, codexHome, now) {
		if log.Source != "claude-code" || log.Sidechain {
			continue
		}
		_ = consent.LocalWrite("claude", func() error {
			return speed.ObserveClaude(st.Dir, log.Path, false, speed.Ingest{Labels: projectLabels(), Subscription: quota.ClaudeSubscription(st.Dir)}, now)
		})
	}
}

package main

import (
	"errors"
	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/logindex"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
	"os"
	"path/filepath"
	"time"
)

func reportWrite(report quota.Report, write func() error) error {
	unlock, err := consent.ReaderLock()
	if err != nil {
		return err
	}
	defer unlock()
	return consent.Publish(consent.Fence{StoreEpoch: report.ConsentStoreEpoch, Generation: report.ConsentGeneration}, write)
}

// observeOutcome names what a local write did for the app-server's observation log. A busy lock
// is a skip: a refresh read or a plugin hook holds it, and the next pass reads the same lines.
func observeOutcome(err error) appserver.ObserveOutcome {
	switch {
	case err == nil:
		return appserver.ObserveRan
	case errors.Is(err, consent.ErrBusy) || errors.Is(err, consent.ErrReaderBusy):
		return appserver.ObserveSkippedLockBusy
	default:
		return appserver.ObserveError
	}
}
func observeQuotaHistory(st *store.Store, report quota.Report, now time.Time) {
	reportWrite(report, func() error { return history.Observe(st.Dir, report, now) })
}

// observeForApp feeds the app-server's sessions, rates and project labels, which otherwise appear
// only while a plugin hook runs. It runs every 30 seconds, so it must stay off the readers: session
// logs and ModelPlan's own cache only (TestObserveForAppStaysOffReaders).
func observeForApp(st *store.Store) func(time.Time) []appserver.ObserveResult {
	return observeForAppIn(st, &logindex.Inventory{})
}

// observeForAppIn discovers the logs from the app-server's shared history inventory and skips
// an observer whose logs and ledgers are as its last clean pass left them (D397).
func observeForAppIn(st *store.Store, inventory *logindex.Inventory) func(time.Time) []appserver.ObserveResult {
	memo := &observeMemo{}
	return func(now time.Time) []appserver.ObserveResult {
		x := observeIndex{inventory: inventory, fence: consent.Capture().Fence(), memo: memo}
		codex := quota.CodexHome()
		results := []appserver.ObserveResult{
			{Source: "codex", Outcome: observeCodexHome(st, codex, now, x)},
			{Source: "claude", Outcome: observeClaude(st, now, x)},
		}
		results = append(results, observeAgents(st, now)...)
		return append(results, appserver.ObserveResult{Source: "live", Outcome: observeLiveLogs(st, codex, cachedSubscriptions(st, now), now, x)})
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
func observeClaudeSpeed(st *store.Store, now time.Time) appserver.ObserveOutcome {
	return observeClaude(st, now, observeIndex{})
}

func observeClaude(st *store.Store, now time.Time, x observeIndex) appserver.ObserveOutcome {
	if !consent.Allowed("claude", consent.Local) {
		return appserver.ObserveSkippedConsent
	}
	if speed.Off() {
		return appserver.ObserveSkippedOff
	}
	home, _ := os.UserHomeDir()
	claude := os.Getenv("CLAUDE_CONFIG_DIR")
	if claude == "" {
		claude = filepath.Join(home, ".claude")
	}
	var logs []string
	for _, log := range x.activeLogs(claude, "", now) {
		if log.Source == "claude-code" && !log.Sidechain {
			logs = append(logs, log.Path)
		}
	}
	if len(logs) == 0 {
		return appserver.ObserveSkippedNoLogs
	}
	in := speed.Ingest{Labels: projectLabels(), Subscription: quota.ClaudeSubscription(st.Dir)}
	return x.memo.skipUnchanged("claude", st.Dir, x.fence, in.Labels, in.Subscription, logs, observeSettle, now, func() appserver.ObserveOutcome {
		outcome := appserver.ObserveSkippedNoLogs
		for _, log := range logs {
			next := observeOutcome(consent.LocalWrite("claude", func() error {
				return speed.ObserveClaude(st.Dir, log, false, in, now)
			}))
			// The worst outcome of the pass is the one worth reading later.
			if outcome == appserver.ObserveSkippedNoLogs || outcome == appserver.ObserveRan {
				outcome = next
			}
		}
		return outcome
	})
}

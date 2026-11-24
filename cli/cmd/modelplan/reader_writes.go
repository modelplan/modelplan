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
	case errors.Is(err, consent.ErrChanged):
		// The admission moved during the pass: nothing was published; the next pass starts over.
		return appserver.ObserveSkippedConsent
	case errors.Is(err, errNoConfinedLogs):
		return appserver.ObserveSkippedNoLogs
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

// errNoConfinedLogs: every discovered log left its admitted root before it could be opened.
var errNoConfinedLogs = errors.New("no log still under its admitted root")

// observeCommitHook runs between a pass's discovery and its commit (tests only: an account or
// consent change in that gap must not reach the ledgers under the earlier binding).
var observeCommitHook func(source string)

func beforeObserveCommit(source string) {
	if observeCommitHook != nil {
		observeCommitHook(source)
	}
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
		// The live records are bound inside the commit, under the pass's fence (macrevb-1222-5).
		return append(results, appserver.ObserveResult{Source: "live", Outcome: observeLiveLogs(st, codex, func() map[string]string { return cachedSubscriptions(st, now) }, now, x)})
	}
}

// cachedSubscriptions: the accounts the last completed reads recorded for the tools with session
// logs. Both cache files are read only when their metadata moved (quota/cache_memo.go).
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
	labels, root := projectLabels(), filepath.Join(claude, "projects")
	// The memo keys on the binding seen now; the commit binds again under its own fence.
	return x.memo.skipUnchanged("claude", st.Dir, x.fence, labels, quota.ClaudeSubscription(st.Dir), logs, observeSettle, now, func() appserver.ObserveOutcome {
		outcome := appserver.ObserveSkippedNoLogs
		for _, log := range logs {
			beforeObserveCommit("claude")
			next := observeOutcome(consent.LocalWriteUnder("claude", x.fence, func() error {
				// Right before the open: the remembered path is still under the admitted root.
				if !speed.LogConfined(log, root, nil) {
					return errNoConfinedLogs
				}
				in := speed.Ingest{Labels: labels, Subscription: quota.ClaudeSubscription(st.Dir)}
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

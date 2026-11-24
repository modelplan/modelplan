package main

import (
	"errors"
	"github.com/modelplan/modelplan/cli/internal/appserver"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/history"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
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
	return observeForAppIndexed(st, &quota.CodexRolloutIndex{}, &speed.ActivityLogIndex{})
}

func observeForAppIndexed(st *store.Store, codexIndex *quota.CodexRolloutIndex, activity *speed.ActivityLogIndex) func(time.Time) []appserver.ObserveResult {
	return func(now time.Time) []appserver.ObserveResult {
		admission := consent.Capture()
		paths := quota.ProductionWatchPaths(st.Dir)
		paths.Admission, paths.CodexIndex = &admission, codexIndex
		// The background accounting pass uses the same active set and directory
		// listings as activity. Keep ZCode’s own ledger on its existing adapter.
		var logs, claudeLogs []speed.LiveLog
		if !speed.Off() {
			claude, codex, zcode, _ := appLogHomes(st.Dir, admission, now)
			logs, claudeLogs = activity.AdmittedLogSets(claude, codex, zcode, admission, now, time.Now())
		}
		results := []appserver.ObserveResult{
			{Source: "codex", Outcome: observeCodexWithLogs(st, now, func() []string {
				files, own := paths.RecentCodexRollouts()
				if len(files) > 8 && files[0] == own {
					files = files[1:] // the reader may add a ninth, older thread
				}
				return files
			})},
			{Source: "claude", Outcome: observeClaudeSpeed(st, claudeLogs, now)},
		}
		results = append(results, observeAgents(st, now)...)
		return append(results, appserver.ObserveResult{Source: "live", Outcome: observeLiveWithLogs(st, paths.CodexHome, cachedSubscriptions(st, now), quota.Report{
			ConsentStoreEpoch: admission.Fence().StoreEpoch, ConsentGeneration: admission.Fence().Generation,
		}, now, func(claude, codex string) []speed.LiveLog {
			return admittedLiveLogs(logs, claude != "", codex != "")
		})})
	}
}

func admittedLiveLogs(logs []speed.LiveLog, claude, codex bool) []speed.LiveLog {
	var admitted []speed.LiveLog
	for _, log := range logs {
		if log.Source == "claude-code" && claude || log.Source == "codex" && codex {
			admitted = append(admitted, log)
		}
	}
	return admitted
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
func observeClaudeSpeed(st *store.Store, logs []speed.LiveLog, now time.Time) appserver.ObserveOutcome {
	if !consent.Allowed("claude", consent.Local) {
		return appserver.ObserveSkippedConsent
	}
	if speed.Off() {
		return appserver.ObserveSkippedOff
	}
	outcome := appserver.ObserveSkippedNoLogs
	for _, log := range logs {
		if log.Source != "claude-code" || log.Sidechain {
			continue
		}
		next := observeOutcome(consent.LocalWrite("claude", func() error {
			return speed.ObserveClaude(st.Dir, log.Path, false, speed.Ingest{Labels: projectLabels(), Subscription: quota.ClaudeSubscription(st.Dir)}, now)
		}))
		// The worst outcome of the pass is the one worth reading later.
		if outcome == appserver.ObserveSkippedNoLogs || outcome == appserver.ObserveRan {
			outcome = next
		}
	}
	return outcome
}

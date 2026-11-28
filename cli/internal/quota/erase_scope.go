// SPDX-License-Identifier: MIT
package quota

import (
	"errors"
	"os"
	"path/filepath"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// EraseScope is the engine's cleanup hook. It never reads tool credentials,
// starts a provider, or erases the independent shared request reservations.
func EraseScope(p Paths, scope string, forget bool) error {
	return EraseScopeGuarded(p, scope, forget, nil)
}

// EraseScopeGuarded is EraseScope for a retried obligation: guard is checked after the reader
// lock is held and before anything is deleted, so a retry whose authority lapsed (a confirmed
// reset, or a re-grant after the obligation was met) erases nothing (macrevb-1218-5).
func EraseScopeGuarded(p Paths, scope string, forget bool, guard consent.EraseGuard) error {
	p.eraseGuard = guard
	tool, path, ok := strings.Cut(scope, ".")
	if !ok || !consent.ValidScope(scope) {
		return errors.New("invalid scope")
	}
	if path == "local_history" {
		unlock, err := consent.ReaderLockWait()
		if err != nil {
			return err
		}
		defer unlock()
		if err := p.eraseGuard.Check(); err != nil {
			return err
		}
		if tool == "codex" {
			forgetCodexRollouts() // WP-17: the decoded rollout memo goes with the scope
		}
		if err := forgetLocalSpeedLedgers(p, tool); err != nil {
			return err
		}
		if err := localusage.ForgetProductionHistoryLocked(p.Cache, tool); err != nil {
			return err
		}
		// Retired adapters can leave captures in the established cache namespace.
		// Remove those by validated tool ID even when no current parser owns them.
		entries, err := os.ReadDir(filepath.Join(p.Cache, "observed"))
		if err != nil && !os.IsNotExist(err) {
			return err
		}
		for _, entry := range entries {
			if owner, valid := localusage.HistoryCacheTool(entry.Name()); valid && owner == tool {
				if err := os.Remove(filepath.Join(p.Cache, "observed", entry.Name())); err != nil {
					return err
				}
			}
		}
		if tool == "claude" {
			if err := os.Remove(filepath.Join(p.Cache, "observed", "claude-code.json")); err != nil && !os.IsNotExist(err) {
				return err
			}
		}
		return nil
	}
	d, known := consent.Definition(scope)
	if known && d.Requires != "" {
		// An extension scope stores nothing: its refreshed token lives only in memory and is
		// keyed to the grant generation, which this revoke changes.
		return nil
	}
	if !known {
		return forgetTool(p, tool, false, forget, "", scope)
	} // Erase established cache formats even after a reader retires.
	return forgetTool(p, tool, false, forget, d.Class, scope)
}

// Caller holds ReaderLock. perf.flock also guards the daily-long rollup.
func forgetLocalSpeedLedgers(p Paths, tool string) error {
	cache := p.Cache
	observed := filepath.Join(cache, "observed")
	if _, err := os.Stat(observed); os.IsNotExist(err) {
		return nil
	} else if err != nil {
		return err
	}
	unlock, ok := speed.LockLedgersForCleanup(cache)
	if !ok {
		return errors.New("readings busy; retry cleanup")
	}
	defer unlock()
	if err := markHistoryCleared(cache, tool); err != nil {
		return err
	}
	if err := speed.ForgetAccountingLocked(cache, tool); err != nil {
		return err
	}
	legacy := speed.LegacyCursorSources(cache, ledgerLogRoots(p))
	for _, name := range []string{"speed.json", "perf.json", "daily-long.json", "imported.json"} {
		if err := filterCachedSource(filepath.Join(observed, name), name, tool, true, legacy); err != nil {
			return err
		}
	}
	return nil
}

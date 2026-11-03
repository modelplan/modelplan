// SPDX-License-Identifier: MIT
package quota

import (
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// ScopeRefreshOutcome returns a fixed code only when the persisted attempt
// belongs to this invocation; it never exposes provider data or error text.
func ScopeRefreshOutcome(p Paths, scope string, at time.Time) string {
	if scope == consent.ScopeCodexRuntimeUsage {
		s := loadAccount(p.Cache)
		if s == nil || !s.ObservedAt.Equal(at) {
			return "not_attempted"
		}
		if s.Status == "ok" {
			return "succeeded"
		}
		return "failed"
	}
	definition, ok := consent.Definition(scope)
	if !ok || definition.Class == consent.Local {
		return "not_attempted"
	}
	if state, err := loadReaderState(p.Cache, definition.Tool); err == nil && state.AttemptedAt.Equal(at) {
		for _, entry := range state.Entries {
			if entry.AttemptedAt.Equal(at) {
				if entry.Status == "ok" {
					return "succeeded"
				}
				return "failed"
			}
		}
		return "not_attempted"
	}
	if snap := loadNative(p.Cache); snap != nil && snap.ObservedAt.Equal(at) {
		for _, entry := range snap.Providers {
			if entry.Provider == definition.Tool {
				if entry.Status == "ok" {
					return "succeeded"
				}
				return "failed"
			}
		}
	}
	return "not_attempted"
}

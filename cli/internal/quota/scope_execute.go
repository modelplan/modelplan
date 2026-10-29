// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"errors"
	"os"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
)

// ExecuteScopeRefresh narrows existing production collectors, never duplicates
// their request implementation or bypasses their locked admission/budget gates.
func ExecuteScopeRefresh(ctx context.Context, p Paths, scope string, now time.Time) error {
	definition, known := consent.Definition(scope)
	if !known {
		return errors.New("scope unavailable")
	}
	admission := admissionFor(p)
	if !admission.State().AllowsScope(scope, admission.Mode()) || !consent.CurrentFence(admission.Fence()) {
		return errors.New("reader not permitted")
	}
	if id, pending := PolicyPending(definition.Tool); pending && id == scope {
		return nil
	}
	if definition.Class == consent.Local {
		if definition.Tool == "codex" {
			unlock, err := consent.ReaderLockContext(ctx)
			if err != nil {
				return err
			}
			defer unlock()
			if !consent.CurrentFence(admission.Fence()) {
				return errors.New("reader consent changed")
			}
			_, _ = readCodex(p.CodexHome, p.CodexThread)
			return ctx.Err()
		}
		home, _ := os.UserHomeDir()
		_ = localusage.RefreshProductionHistory(ctx, home, p.Cache, definition.Tool, now)
		if definition.Tool == "claude" {
			unlock, err := consent.ReaderLockContext(ctx)
			if err != nil {
				return err
			}
			defer unlock()
			refreshProductionClaudeSessions(ctx, p, now)
		}
		return ctx.Err()
	}
	if scope == consent.ScopeCodexRuntimeUsage {
		home, _ := os.UserHomeDir()
		return RefreshCodexAccount(ctx, p.Cache, CodexBin(home), now)
	}
	return RefreshNativeProviders(ctx, p, now, []string{definition.Tool})
}

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

type refreshScopeKey struct{}

func zaiAccountScope(scope string) bool {
	return scope == consent.ScopeZaiAccountUsageSavedLogin || scope == consent.ScopeZaiAccountUsageAPIKey
}

// Z.ai has two account scopes but one selected native provider. Scope-specific refreshes
// must use the selected route, not merely the shared provider ID.
func zaiScopeMatches(p Paths, scope string) bool {
	if !zaiAccountScope(scope) {
		return true
	}
	grant, ok := p.ReaderAccessGrant("zai")
	login := ok && grant.ConfigSource != nil && grant.ConfigSource.Tool == zcodeLoginTool
	if scope == consent.ScopeZaiAccountUsageSavedLogin {
		return login
	}
	return !login
}

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
	if !zaiScopeMatches(p, scope) {
		return errors.New("reader scope does not match selected route")
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
			_, status := readCodex(p.CodexHome, p.CodexThread)
			if err := ctx.Err(); err != nil {
				return err
			}
			if status.Status != "ok" {
				return errors.New("local history unavailable")
			}
			return nil
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
		return RefreshCodexAccountDiscover(ctx, p.Cache, home, now)
	}
	return RefreshNativeProviders(context.WithValue(ctx, refreshScopeKey{}, scope), p, now, []string{definition.Tool})
}

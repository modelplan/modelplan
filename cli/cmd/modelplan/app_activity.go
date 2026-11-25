// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"os"
	"path/filepath"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/logindex"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// This observer lives in the existing app-server, not in the UI or an extra child. It runs every
// two seconds, so it opens session logs and ModelPlan's own cache only, never a credential file.
func appActivity(cache string) func(context.Context, consent.Admission, time.Time) []rows.ActivityInput {
	return appActivityClock(cache, time.Now, nil)
}

// appActivityClock takes the monotonic clock that paces discovery, so the idle-work gates can
// step the production observer through its discovery interval without waiting.
// The inventory is the app-server's shared history inventory; nil keeps a private one.
func appActivityClock(cache string, elapsed func() time.Time, inventory *logindex.Inventory) func(context.Context, consent.Admission, time.Time) []rows.ActivityInput {
	observer := speed.NewActivityObserver()
	if inventory == nil {
		inventory = &logindex.Inventory{}
	}
	logsIndex := speed.ActivityLogIndex{Inventory: inventory}
	return func(ctx context.Context, a consent.Admission, now time.Time) []rows.ActivityInput {
		ticket := logsIndex.Ticket() // with a, before anything else runs under it (macrev2-1261-2)
		if speed.Off() {
			observer.Observe(ctx, nil, nil, now)
			return nil
		}
		home, _ := os.UserHomeDir()
		state := a.State()
		allowed := func(scope, tool string) bool {
			return state.AllowsScope(scope, a.Mode()) && !a.CleanupPending(scope) && !a.CleanupPending(tool)
		}
		claude, codex, zcode, zcodeRef := "", "", "", ""
		if allowed(consent.ScopeClaudeLocalHistory, "claude") {
			claude = os.Getenv("CLAUDE_CONFIG_DIR")
			if claude == "" {
				claude = filepath.Join(home, ".claude")
			}
		}
		if allowed(consent.ScopeCodexLocalHistory, "codex") {
			codex = quota.CodexHome()
		}
		// ZCode's ledger has no account. Its one configured key does, and that reading also proves
		// ZCode points at Z.ai, so nothing needs to open ZCode's own settings here.
		if allowed(consent.ScopeZaiLocalHistory, "zai") {
			if zcodeRef = quota.ZCodeSubscription(cache, a, now); zcodeRef != "" {
				zcode = filepath.Join(home, ".zcode")
			}
		}
		logs := logsIndex.LogsWith(claude, codex, zcode, a.Fence(), now, elapsed(), ticket)
		bindings := []speed.ActivityBinding{}
		if len(logs) > 0 {
			bindings = speed.ExistingActivityBindings(cache, a)
		}
		values := observer.Observe(ctx, logs, bindings, now)
		out := []rows.ActivityInput{}
		for _, v := range values {
			if v.Source == "zcode" && !v.RecordAt.Before(state.Scopes[consent.ScopeZaiLocalHistory].At) {
				v.SubscriptionRef = zcodeRef
			}
			if v.SubscriptionRef == "" {
				continue
			}
			tool := v.Source
			switch tool {
			case "claude-code":
				tool = "claude"
			case "zcode":
				tool = "zai"
			}
			out = append(out, rows.ActivityInput{ToolID: tool, SubscriptionRef: v.SubscriptionRef, SessionRef: v.SessionRef, BindingVerified: true, Phase: rows.ActivityPhase(v.Phase), RecordAt: v.RecordAt, ExpiresAt: v.ExpiresAt})
		}
		return out
	}
}

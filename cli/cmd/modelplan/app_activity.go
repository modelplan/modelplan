// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"os"
	"path/filepath"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// This observer lives in the existing app-server, not in the UI or an extra child. It runs every
// two seconds, so it opens session logs and ModelPlan's own cache only, never a credential file.
func appActivity(cache string, logsIndex *speed.ActivityLogIndex) func(context.Context, consent.Admission, time.Time) []rows.ActivityInput {
	observer := speed.NewActivityObserver()
	var lastFence consent.Fence
	var lastMode string
	return func(ctx context.Context, a consent.Admission, now time.Time) []rows.ActivityInput {
		if speed.Off() || lastFence != a.Fence() || lastMode != a.Mode() {
			observer.Observe(ctx, nil, nil, now)
			lastFence, lastMode = a.Fence(), a.Mode()
		}
		if speed.Off() {
			logsIndex.AdmittedLogs("", "", "", a, now, time.Now())
			return nil
		}
		claude, codex, zcode, zcodeRef := appLogHomes(cache, a, now)
		state := a.State()
		logs := logsIndex.AdmittedLogs(claude, codex, zcode, a, now, time.Now())
		bindings := []speed.ActivityBinding{}
		if len(logs) > 0 {
			bindings = speed.ExistingActivityBindings(cache, a)
		}
		values := observer.ObserveAdmitted(ctx, logs, bindings, now, func() bool {
			current := consent.Capture()
			return current.Fence() == a.Fence() && current.Mode() == a.Mode()
		})
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

func appLogHomes(cache string, a consent.Admission, now time.Time) (claude, codex, zcode, zcodeRef string) {
	home, _ := os.UserHomeDir()
	state := a.State()
	allowed := func(scope, tool string) bool {
		return state.AllowsScope(scope, a.Mode()) && !a.CleanupPending(scope) && !a.CleanupPending(tool)
	}
	if allowed(consent.ScopeClaudeLocalHistory, "claude") {
		claude = os.Getenv("CLAUDE_CONFIG_DIR")
		if claude == "" {
			claude = filepath.Join(home, ".claude")
		}
	}
	if allowed(consent.ScopeCodexLocalHistory, "codex") {
		codex = quota.CodexHome()
	}
	// ZCode's log has no account. Only a current admitted binding can
	// associate activity with a ZCode subscription.
	if allowed(consent.ScopeZaiLocalHistory, "zai") {
		if zcodeRef = quota.ZCodeSubscription(cache, a, now); zcodeRef != "" {
			zcode = filepath.Join(home, ".zcode")
		}
	}
	return
}

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

// This observer lives in the existing app-server, not in the UI or an extra
// child. Discovery/configuration happens only for currently admitted local scopes.
func appActivity(cache string, paths func(consent.Admission) quota.Paths) func(context.Context, consent.Admission, time.Time) []rows.ActivityInput {
	observer := speed.NewActivityObserver()
	return func(ctx context.Context, a consent.Admission, now time.Time) []rows.ActivityInput {
		if speed.Off() {
			observer.Observe(ctx, nil, nil, now)
			return nil
		}
		home, _ := os.UserHomeDir()
		claude, codex, zcode := "", "", ""
		if a.State().AllowsScope(consent.ScopeClaudeLocalHistory, a.Mode()) {
			claude = os.Getenv("CLAUDE_CONFIG_DIR")
			if claude == "" {
				claude = filepath.Join(home, ".claude")
			}
		}
		if a.State().AllowsScope(consent.ScopeCodexLocalHistory, a.Mode()) {
			codex = paths(a).CodexHome
		}
		if a.State().AllowsScope(consent.ScopeZaiLocalHistory, a.Mode()) {
			candidate := filepath.Join(home, ".zcode")
			if speed.ZCodeActivityHost(filepath.Join(candidate, "cli", "config.json")) {
				zcode = candidate
			}
		}
		logs := speed.ActivityLogs(claude, codex, zcode, now)
		bindings := []speed.ActivityBinding{}
		if len(logs) > 0 {
			bindings = speed.ExistingActivityBindings(cache)
		}
		values := observer.Observe(ctx, logs, bindings, now)
		out := []rows.ActivityInput{}
		for _, v := range values {
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

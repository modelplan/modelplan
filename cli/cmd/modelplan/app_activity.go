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
func appActivity(cache string) func(context.Context, consent.Admission, time.Time) []rows.ActivityInput {
	observer := speed.NewActivityObserver()
	return func(ctx context.Context, a consent.Admission, now time.Time) []rows.ActivityInput {
		if speed.Off() {
			observer.Observe(ctx, nil, nil, now)
			return nil
		}
		home, _ := os.UserHomeDir()
		claude, codex, zcode, zcodeRef := "", "", "", ""
		if a.State().AllowsScope(consent.ScopeClaudeLocalHistory, a.Mode()) {
			claude = os.Getenv("CLAUDE_CONFIG_DIR")
			if claude == "" {
				claude = filepath.Join(home, ".claude")
			}
		}
		if a.State().AllowsScope(consent.ScopeCodexLocalHistory, a.Mode()) {
			codex = quota.CodexHome()
		}
		// ZCode's ledger has no account. Its one configured key does, and that reading also proves
		// ZCode points at Z.ai, so nothing needs to open ZCode's own settings here.
		if a.State().AllowsScope(consent.ScopeZaiLocalHistory, a.Mode()) {
			if zcodeRef = quota.ZCodeSubscription(cache); zcodeRef != "" {
				zcode = filepath.Join(home, ".zcode")
			}
		}
		logs := speed.ActivityLogs(claude, codex, zcode, now)
		bindings := []speed.ActivityBinding{}
		if len(logs) > 0 {
			bindings = speed.ExistingActivityBindings(cache, a)
		}
		values := observer.Observe(ctx, logs, bindings, now)
		out := []rows.ActivityInput{}
		for _, v := range values {
			if v.Source == "zcode" && !v.RecordAt.Before(a.State().Scopes[consent.ScopeZaiLocalHistory].At) {
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

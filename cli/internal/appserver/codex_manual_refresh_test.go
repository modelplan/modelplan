// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Owner bad case 2026-11-28: one minute after a transient Codex failure the user's refresh reads
// again, marked as a manual refresh; a sign-in failure keeps its half-hour back-off.
func TestCodexMemberRefreshOneMinuteAfterATransientFailure(t *testing.T) {
	for _, c := range []struct {
		code    string
		started bool
	}{{"http_5xx", true}, {"rpc_error", true}, {"login_expired", false}} {
		t.Run(c.code, func(t *testing.T) {
			backend, paths, cache, member := memberFixture(t)
			now := time.Now().UTC().Truncate(time.Second)
			failedAt := now.Add(-time.Minute)
			path := filepath.Join(cache, "observed", "codex-account.json")
			if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
				t.Fatal(err)
			}
			granted, _ := consent.Current()
			data, _ := json.Marshal(map[string]any{"schemaVersion": 1, "observedAt": failedAt, "status": "error", "error": c.code, "errorCode": c.code,
				"admission": granted.CaptureStamp(consent.ScopeCodexRuntimeUsage),
				"failures":  []map[string]any{{"code": c.code, "at": failedAt, "streakSeconds": 0}}})
			if err := os.WriteFile(path, data, 0600); err != nil {
				t.Fatal(err)
			}
			manual := make(chan bool, 1)
			s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Now: func() time.Time { return now },
				Run: func(ctx context.Context, _ quota.Paths, _ string, _ time.Time) error {
					manual <- quota.IsManualRefresh(ctx)
					return nil
				}})
			defer s.Close()
			result, _, err := s.RequestMember(context.Background(), member)
			if err != nil {
				t.Fatal(err)
			}
			if !c.started {
				if result.Outcome == wire.MemberRefreshStarted || result.NotBefore == nil || !result.NotBefore.Equal(failedAt.Add(30*time.Minute)) {
					t.Fatalf("a sign-in failure skipped its back-off: %+v", result)
				}
				return
			}
			if result.Outcome != wire.MemberRefreshStarted {
				t.Fatalf("refresh one minute after a transient failure: %+v", result)
			}
			select {
			case m := <-manual:
				if !m {
					t.Fatal("the member refresh ran without the manual mark")
				}
			case <-time.After(5 * time.Second):
				t.Fatal("reader did not run")
			}
		})
	}
}

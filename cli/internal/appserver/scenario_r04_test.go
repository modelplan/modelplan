// SPDX-License-Identifier: MIT
package appserver

// Spec-data scenario R-04 (tier-1 producer half): "Two members, one within its
// floor and one ungranted / Click each ring / The first is deferred until
// eligible, the second is refused; neither bypasses the floor or reads another
// member." Both clicks resolve against the same epoch in one session and neither
// may run a reader.

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestR04FloorMemberDefersAndUngrantedMemberRefusesWithoutReads(t *testing.T) {
	backend, paths, cache, codexMember := memberFixture(t)
	// The second member: a claude saved-login account on its own row, never granted.
	other := "fedcba9876543210"
	backend.view.Projection.Rows = append(backend.view.Projection.Rows, rows.Row{ID: "claude", State: rows.StateFresh,
		Accounts: []rows.Account{{Route: rows.RouteSavedLoginAPI, SubscriptionRef: &other}}})
	claudeMember := wire.RefreshMember{RowID: "claude", Route: rows.RouteSavedLoginAPI, SubscriptionRef: other}

	// Put the codex member inside its persisted floor (observed moments ago).
	now := time.Now().UTC().Truncate(time.Second)
	path := filepath.Join(cache, "observed", "codex-account.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	data, err := json.Marshal(map[string]any{"schemaVersion": 1, "observedAt": now, "status": "ok"})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, data, 0600); err != nil {
		t.Fatal(err)
	}

	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths, Now: func() time.Time { return now },
		Run: func(context.Context, quota.Paths, string, time.Time) error {
			t.Error("prohibited read during deferral or refusal")
			return nil
		}})
	defer s.Close()

	result, _, err := s.RequestMember(context.Background(), codexMember)
	if err != nil || result.Outcome != wire.MemberRefreshDeferred || result.Reason == nil || *result.Reason != wire.MemberRefreshFloor ||
		result.NotBefore == nil || !result.NotBefore.Equal(now.Add(5*time.Minute)) {
		t.Fatalf("floor member was not deferred until eligible: %+v %v", result, err)
	}
	result, _, err = s.RequestMember(context.Background(), claudeMember)
	if err != nil || result.Outcome != wire.MemberRefreshDeferred || result.Reason == nil || *result.Reason != wire.MemberRefreshNotGranted || result.NotBefore != nil {
		t.Fatalf("ungranted member was not refused: %+v %v", result, err)
	}
}

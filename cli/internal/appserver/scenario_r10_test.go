// SPDX-License-Identifier: MIT
package appserver

// Spec-data scenario R-10 (tier-1 producer half): "A source is denied, revoked,
// offline or in back-off / Start, wake or click refresh / No prohibited read
// occurs and an old result is not republished after revocation." A revoked
// source must not be read by the automatic scheduler at its due time, and a
// ring click after revocation must be refused (first as a stale consent fence,
// then as ungranted once the backend view is rebuilt for the new fence).

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
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestR10RevokedSourceNeverReadAutomaticallyOrOnClick(t *testing.T) {
	backend, paths, cache := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	ref := "0123456789abcdef"
	backend.view.Projection.Rows = []rows.Row{{ID: "codex", State: rows.StateFresh,
		Accounts: []rows.Account{{Route: rows.RouteRuntimeRPC, SubscriptionRef: &ref}}}}
	due := time.Now().Add(time.Second).UTC()
	path := filepath.Join(cache, "observed", "reader-attempts", "codex.json")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	body, err := json.Marshal(map[string]any{"schemaVersion": 1, "nextAttemptAt": due})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, body, 0600); err != nil {
		t.Fatal(err)
	}
	called := make(chan struct{}, 1)
	s := NewRefreshScheduler(context.Background(), RefreshConfig{Backend: backend, Paths: paths,
		Run: func(context.Context, quota.Paths, string, time.Time) error {
			called <- struct{}{}
			return nil
		}})
	defer s.Close()
	s.StartAutomatic()

	// Revoke before the scheduled due time.
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		return consent.Set(state, "codex", false, "", "", time.Now())
	}); err != nil {
		t.Fatal(err)
	}

	// The automatic scheduler must not run the revoked source at its due time.
	select {
	case <-called:
		t.Fatal("revoked source was read automatically")
	case <-time.After(time.Until(due) + 150*time.Millisecond):
	}

	// A ring click after revocation is refused: the stale consent fence rejects it.
	member := wire.RefreshMember{RowID: "codex", Route: rows.RouteRuntimeRPC, SubscriptionRef: ref}
	if _, _, err := s.RequestMember(context.Background(), member); err == nil {
		t.Fatal("click after revocation was not refused")
	}

	// Once the backend view is rebuilt for the new fence (as the production
	// backend does), the same click is refused as ungranted — the old grant no
	// longer authorises a read and no old result is republished for it.
	backend.view.Stamp = stampOfFence(consent.Capture().Fence())
	backend.view.Scopes = nil
	backend.view.Projection = rows.Build(rows.Input{Now: time.Now(), ReadersOff: true})
	result, _, err := s.RequestMember(context.Background(), member)
	if err != nil || result.Outcome != wire.MemberRefreshDeferred || result.Reason == nil || *result.Reason != wire.MemberRefreshNotGranted {
		t.Fatalf("rebuilt click was not refused as ungranted: %+v %v", result, err)
	}
	select {
	case <-called:
		t.Fatal("revoked source was read on click")
	case <-time.After(10 * time.Millisecond):
	}
}

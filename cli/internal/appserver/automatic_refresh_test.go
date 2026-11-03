// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestAutomaticRefreshStartsGrantedCodexOnce(t *testing.T) {
	backend, paths, _ := refreshFixture(t, consent.ScopeCodexRuntimeUsage)
	calls := make(chan string, 2)
	scheduler := NewRefreshScheduler(context.Background(), RefreshConfig{
		Backend: backend, Paths: paths,
		Run: func(_ context.Context, _ quota.Paths, scope string, _ time.Time) error {
			calls <- scope
			return nil
		},
	})
	defer scheduler.Close()
	scheduler.StartAutomatic()
	scheduler.StartAutomatic()
	select {
	case scope := <-calls:
		if scope != consent.ScopeCodexRuntimeUsage { t.Fatalf("unexpected scope %s", scope) }
	case <-time.After(5 * time.Second):
		t.Fatal("granted runtime was not scheduled")
	}
	select {
	case scope := <-calls:
		t.Fatalf("duplicate request before floor: %s", scope)
	case <-time.After(100 * time.Millisecond):
	}
}

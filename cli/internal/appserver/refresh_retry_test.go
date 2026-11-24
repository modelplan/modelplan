// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// failingOnceBackend fails the next Get calls while failures > 0, like a rebuild that
// waited behind a slow read and found its context already expired.
type failingOnceBackend struct {
	*memoryBackend
	failures atomic.Int32
}

func (b *failingOnceBackend) Get(ctx context.Context) (View, error) {
	if b.failures.Load() > 0 && b.failures.Add(-1) >= 0 {
		return View{}, context.DeadlineExceeded
	}
	return b.memoryBackend.Get(ctx)
}

// Review 11-24 #7: one change wake whose rebuild fails must still reach the client, with no
// further change from the backend (steady file stamps, no observer tick).
func TestFailedChangeRefreshIsRetried(t *testing.T) {
	backend := &failingOnceBackend{memoryBackend: newMemoryBackend()}
	c := startClient(t, Config{Backend: backend})
	c.initialize(t)
	backend.failures.Store(1)
	backend.mu.Lock()
	backend.view.Health = wire.Health{State: wire.HealthDegraded, Code: "expired"}
	backend.mu.Unlock()
	backend.changed <- struct{}{}
	// next fails the test after 3 s; without a retry the failed rebuild is never repeated.
	c.next(t, func(m map[string]json.RawMessage) bool {
		if string(m["method"]) != `"engine/health"` {
			return false
		}
		var n wire.Envelope[wire.Health]
		return json.Unmarshal(m["params"], &n) == nil && n.Data.State == wire.HealthDegraded
	})
	if backend.failures.Load() > 0 {
		t.Fatal("the failing rebuild never ran")
	}
}

func TestRefreshBackoffIsBounded(t *testing.T) {
	d := time.Duration(0)
	for i := 0; i < 20; i++ {
		d = nextRefreshBackoff(d)
	}
	if d != refreshRetryMax || nextRefreshBackoff(0) != refreshRetryFirst {
		t.Fatalf("backoff %v", d)
	}
}

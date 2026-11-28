// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// busyPublishBackend fails the next Publish calls while busy > 0, like a shared publication
// fence held by another delivery, and records when each call was made.
type busyPublishBackend struct {
	*memoryBackend
	busy  atomic.Int32
	calls chan time.Time
}

func (b *busyPublishBackend) Publish(ctx context.Context, stamp Stamp, write func() error) error {
	select {
	case b.calls <- time.Now():
	default:
	}
	if b.busy.Load() > 0 && b.busy.Add(-1) >= 0 {
		return errors.New("publication busy")
	}
	return b.memoryBackend.Publish(ctx, stamp, write)
}

// Review 11-24 #7 (macrevc-1216-1): one change wake whose publication fails must not queue an
// immediate second wake. The retry waits at least the first backoff step, and the updated rows
// still arrive once publication recovers.
func TestPublicationFailureWaitsForBackoff(t *testing.T) {
	backend := &busyPublishBackend{memoryBackend: newMemoryBackend(), calls: make(chan time.Time, 16)}
	c := startClient(t, Config{Backend: backend})
	c.initialize(t)
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	c.response(t, 2)
	for len(backend.calls) > 0 {
		<-backend.calls
	}
	backend.busy.Store(1)
	backend.mu.Lock()
	backend.view.Health = wire.Health{State: wire.HealthDegraded, Code: "expired"}
	backend.mu.Unlock()
	backend.changed <- struct{}{}
	call := func() time.Time {
		t.Helper()
		select {
		case at := <-backend.calls:
			return at
		case <-time.After(3 * time.Second):
			t.Fatal("publication was not retried")
			return time.Time{}
		}
	}
	first, second := call(), call()
	if gap := second.Sub(first); gap < refreshRetryFirst {
		t.Fatalf("publication retried after %v, before the %v backoff", gap, refreshRetryFirst)
	}
	c.next(t, func(m map[string]json.RawMessage) bool { return string(m["method"]) == `"rows/changed"` })
}

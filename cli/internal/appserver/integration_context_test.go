// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"testing"
)

func TestRejectedGrantUsesAuthoritativeBackendStamp(t *testing.T) {
	for _, reset := range []bool{false, true} {
		t.Run(map[bool]string{false: "generation", true: "epoch"}[reset], func(t *testing.T) {
			b := newMemoryBackend()
			c := startClient(t, Config{Backend: b})
			c.initialize(t)
			b.mu.Lock()
			b.view.Stamp.Generation = 7
			b.view.Projection.ConsentGeneration = 7
			if reset {
				b.view.Stamp.Epoch = "epoch-reset"
			}
			expected := b.view.Stamp
			b.mu.Unlock()
			c.send(t, 2, "consent/grant", deny("stale-before-watcher", 1))
			failure := errorOf(t, c.response(t, 2))
			if failure.Code != wire.CodeConsentStale || failure.Data.StoreEpoch == nil || *failure.Data.StoreEpoch != expected.Epoch || failure.Data.ConsentGeneration == nil || *failure.Data.ConsentGeneration != expected.Generation {
				t.Fatalf("stale context: %+v", failure)
			}
		})
	}
}

func TestHandlerReceivesInitializedSession(t *testing.T) {
	var seen string
	c := startClient(t, Config{Backend: newMemoryBackend(), Handlers: map[string]Handler{"test/session": {Handle: func(ctx context.Context, _ json.RawMessage, s Stamp) (Reply, error) {
		seen = SessionID(ctx)
		return Reply{Stamp: s, Data: wire.Empty{}}, nil
	}}}})
	c.initialize(t)
	c.send(t, 2, "test/session", wire.Empty{})
	c.response(t, 2)
	if seen == "" || seen != c.server.session {
		t.Fatal("handler missing initialized session")
	}
}

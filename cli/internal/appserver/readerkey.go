// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Manual key methods (owner decision D90): readerkey/set, readerkey/test, readerkey/remove and
// readerkey/status.
// Capability "reader_key". The key travels only in the params of set and test; wire.ReaderKeyParams
// redacts itself in every formatter and log, a result never carries it, and quota.SetManualKey
// stores it in a 0600 file. A result carries one fixed outcome word.

// ReaderKeyConfig: Dir is the app support directory; Client is for tests (nil: the production
// reader client, which refuses every host but the compiled official ones).
type ReaderKeyConfig struct {
	Dir      string
	Client   *http.Client
	ReadOnly bool
	Offline  bool
	Now      func() time.Time
}

func (c ReaderKeyConfig) now() time.Time {
	if c.Now != nil {
		return c.Now()
	}
	return time.Now()
}

func readerKeyRegion(r wire.ReaderKeyRegion) (string, bool) {
	switch r {
	case wire.ReaderKeyRegionNone:
		return "", true
	case wire.ReaderKeyRegionGlobal, wire.ReaderKeyRegionChina:
		return string(r), true
	}
	return "", false
}

func wireRegion(region string) wire.ReaderKeyRegion {
	if region == "" {
		return wire.ReaderKeyRegionNone
	}
	return wire.ReaderKeyRegion(region)
}

// ReaderKeyHandlers returns the three methods.
func ReaderKeyHandlers(c ReaderKeyConfig) map[string]Handler {
	handler := func(run func(context.Context, wire.ReaderKeyParams, string) wire.ReaderKeyOutcome) Handler {
		return Handler{Capability: "reader_key", Timeout: 30 * time.Second, Handle: func(ctx context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
			p, err := params[wire.ReaderKeyParams](raw)
			region, regionOK := readerKeyRegion(p.Region)
			if err != nil || !regionOK || !quota.ManualKeyProvider(string(p.Provider)) {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			outcome := run(ctx, p, region)
			provider := string(p.Provider)
			result := wire.ReaderKeyResult{SchemaVersion: 1, Provider: p.Provider, Outcome: outcome,
				Present: quota.ManualKeyPresent(c.Dir, provider), Region: wireRegion(quota.ManualKeyRegion(c.Dir, provider))}
			return Reply{Stamp: stamp, Data: result, Receipt: true}, nil
		}}
	}
	return map[string]Handler{
		"readerkey/set": handler(func(_ context.Context, p wire.ReaderKeyParams, region string) wire.ReaderKeyOutcome {
			switch {
			case c.ReadOnly:
				return wire.ReaderKeyFailed
			case quota.SetManualKey(c.Dir, string(p.Provider), p.Key, region) != nil:
				return wire.ReaderKeyNotAccepted
			}
			return wire.ReaderKeySaved
		}),
		// status reports the stored key's presence and region (in the result) without any request.
		"readerkey/status": handler(func(context.Context, wire.ReaderKeyParams, string) wire.ReaderKeyOutcome {
			return wire.ReaderKeyOK
		}),
		"readerkey/remove": handler(func(_ context.Context, p wire.ReaderKeyParams, _ string) wire.ReaderKeyOutcome {
			if c.ReadOnly || quota.RemoveManualKey(c.Dir, string(p.Provider)) != nil {
				return wire.ReaderKeyFailed
			}
			return wire.ReaderKeyRemoved
		}),
		"readerkey/test": handler(func(ctx context.Context, p wire.ReaderKeyParams, region string) wire.ReaderKeyOutcome {
			if c.Offline {
				return wire.ReaderKeyUnreachable
			}
			// With no key in the call, the stored key is tested.
			if p.Key == "" {
				return wire.ReaderKeyOutcome(quota.TestStoredManualKey(ctx, c.Client, c.Dir, string(p.Provider), c.now()))
			}
			return wire.ReaderKeyOutcome(quota.TestManualKey(ctx, c.Client, string(p.Provider), p.Key, region, c.now()))
		}),
	}
}

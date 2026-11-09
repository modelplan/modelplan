// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// Manual key methods (owner decision D90): readerkey/set, readerkey/test, readerkey/remove.
// Capability "reader_key". The key travels only in the params of set and test; it is held in a
// type that redacts itself in every formatter and log, is never echoed in a result or error, and
// is stored by quota.SetManualKey in a 0600 file. A result carries one fixed outcome word.

type readerKeySecret string

func (readerKeySecret) String() string { return "[redacted]" }

func (readerKeySecret) GoString() string { return "[redacted]" }

func (readerKeySecret) LogValue() slog.Value { return slog.StringValue("[redacted]") }

func (readerKeySecret) MarshalText() ([]byte, error) { return []byte("[redacted]"), nil }

// ReaderKeyParams: Provider is zai or opencodego; Region (zai only) is global or china.
type ReaderKeyParams struct {
	Provider string          `json:"provider"`
	Region   string          `json:"region,omitempty"`
	Key      readerKeySecret `json:"key,omitempty"`
}

// ReaderKeyResult: Outcome is saved, removed, or a quota.ManualKey* word (ok, key_refused,
// plan_lapsed, no_key, unreachable, failed, not_accepted). Present says whether a manual key is
// stored after the call. The key is never part of a result.
type ReaderKeyResult struct {
	SchemaVersion int    `json:"schemaVersion"`
	Provider      string `json:"provider"`
	Region        string `json:"region,omitempty"`
	Present       bool   `json:"present"`
	Outcome       string `json:"outcome"`
}

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

// ReaderKeyHandlers returns the three methods.
func ReaderKeyHandlers(c ReaderKeyConfig) map[string]Handler {
	handler := func(run func(context.Context, ReaderKeyParams) ReaderKeyResult) Handler {
		return Handler{Capability: "reader_key", Timeout: 30 * time.Second, Handle: func(ctx context.Context, raw json.RawMessage, stamp Stamp) (Reply, error) {
			p, err := params[ReaderKeyParams](raw)
			if err != nil || !quota.ManualKeyProvider(p.Provider) {
				return Reply{}, ProtocolError{wire.CodeInvalidParams}
			}
			result := run(ctx, p)
			result.SchemaVersion, result.Provider = 1, p.Provider
			result.Present = quota.ManualKeyPresent(c.Dir, p.Provider)
			result.Region = quota.ManualKeyRegion(c.Dir, p.Provider)
			return Reply{Stamp: stamp, Data: result, Receipt: true}, nil
		}}
	}
	return map[string]Handler{
		"readerkey/set": handler(func(_ context.Context, p ReaderKeyParams) ReaderKeyResult {
			switch {
			case c.ReadOnly:
				return ReaderKeyResult{Outcome: quota.ManualKeyFailed}
			case quota.SetManualKey(c.Dir, p.Provider, string(p.Key), p.Region) != nil:
				return ReaderKeyResult{Outcome: quota.ManualKeyNotAccepted}
			}
			return ReaderKeyResult{Outcome: "saved"}
		}),
		"readerkey/remove": handler(func(_ context.Context, p ReaderKeyParams) ReaderKeyResult {
			if c.ReadOnly || quota.RemoveManualKey(c.Dir, p.Provider) != nil {
				return ReaderKeyResult{Outcome: quota.ManualKeyFailed}
			}
			return ReaderKeyResult{Outcome: "removed"}
		}),
		"readerkey/test": handler(func(ctx context.Context, p ReaderKeyParams) ReaderKeyResult {
			if c.Offline {
				return ReaderKeyResult{Outcome: quota.ManualKeyUnreachable}
			}
			// With no key in the call, the stored key is tested.
			if p.Key == "" {
				return ReaderKeyResult{Outcome: quota.TestStoredManualKey(ctx, c.Client, c.Dir, p.Provider, c.now())}
			}
			return ReaderKeyResult{Outcome: quota.TestManualKey(ctx, c.Client, p.Provider, string(p.Key), p.Region, c.now())}
		}),
	}
}

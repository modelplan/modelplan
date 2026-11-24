// SPDX-License-Identifier: MIT
package appserver

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// The app's ordinary readerkey RPC and subscribed rows, using the production backend, cache projection and file
// observer. Observe only public envelopes; do not inspect the cleared quota cache to decide whether the old ring left.
func TestGLMKeyChangeClearsSubscribedRows(t *testing.T) {
	for _, method := range []string{"readerkey/set", "readerkey/remove"} {
		t.Run(method, func(t *testing.T) {
			testenv.IsolateHome(t)
			t.Setenv("MODELPLAN_READERS", "")
			t.Setenv("MODELPLAN_IDENTITY", "")
			t.Setenv("Z_AI_API_KEY", "fake-detected-key")
			cache := t.TempDir()
			at := time.Now().UTC().Truncate(time.Second)
			if _, err := consent.EnsureStore(consent.Path()); err != nil {
				t.Fatal(err)
			}
			if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "zai", true, "native:zai", "native", at) }); err != nil {
				t.Fatal(err)
			}
			if err := quota.SetManualKey(cache, "zai", readerKeyFake, "global"); err != nil {
				t.Fatal(err)
			}
			paths := func(a consent.Admission) quota.Paths {
				return quota.Paths{Cache: cache, ConnectionsFile: filepath.Join(cache, "connections.json"), Admission: &a}
			}
			if err := quota.SetConnection(paths(consent.Capture()).ConnectionsFile, quota.QuotaSource{Provider: "zai", Backend: quota.BackendNative, Enabled: true}); err != nil {
				t.Fatal(err)
			}
			state, err := consent.Load(consent.Path())
			if err != nil {
				t.Fatal(err)
			}
			used := 25.0
			snapshot := map[string]any{"schemaVersion": 1, "providers": []any{map[string]any{
				"provider": "zai", "status": "ok", "observedAt": at, "detectedKeyRef": "0123456789abcdef",
				// manualKeyGeneration: read with the key saved above, its first generation (sampling 11-21 S8).
				"subscriptionRef": "fedcba9876543210", "admission": state.CaptureStamp(consent.ScopeZaiAccountUsageAPIKey), "manualKeyGeneration": 1,
				"windows": []quota.Window{{Kind: "five_hour", UsedPercent: &used, ObservedAt: at}},
			}}}
			data, _ := json.Marshal(snapshot)
			if err := os.WriteFile(filepath.Join(cache, "observed", "native.json"), data, 0600); err != nil {
				t.Fatal(err)
			}
			backend, err := NewSharedBackend(SharedConfig{now: func() time.Time { return at }, Paths: paths, Cleanup: func(string, bool) error { return nil },
				Detect: func() detect.Report {
					return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "zai", Preferred: "native", ReaderID: "native:zai"}, Detected: true}}}
				},
			})
			if err != nil {
				t.Fatal(err)
			}
			c := startClient(t, Config{Backend: backend, Handlers: ReaderKeyHandlers(ReaderKeyConfig{Dir: cache})})
			c.readMessages()
			c.send(t, 1, "initialize", wire.InitializeParams{SessionID: "glm-key-rows", ProtocolVersion: wire.ProtocolVersion, AppVersion: "test", Capabilities: []string{"rows", "reader_key"}})
			if m := c.response(t, 1); m["error"] != nil {
				t.Fatalf("initialize: %s", m["error"])
			}
			c.send(t, 2, "rows/subscribe", wire.Empty{})
			var initial wire.Envelope[wire.RowsSnapshot]
			if err := json.Unmarshal(c.response(t, 2)["result"], &initial); err != nil {
				t.Fatal(err)
			}
			var before *rows.Row
			for i := range initial.Data.Projection.Rows {
				if initial.Data.Projection.Rows[i].ID == "zai" {
					before = &initial.Data.Projection.Rows[i]
				}
			}
			if before == nil || len(before.Accounts) != 1 || len(before.Accounts[0].Windows) == 0 {
				t.Fatalf("fixture did not show the prior GLM reading: %+v", before)
			}
			params := wire.ReaderKeyParams{Provider: wire.ReaderKeyProvider("zai"), Region: wire.ReaderKeyRegionGlobal, Key: "replacement-key"}
			if method == "readerkey/remove" {
				params.Region, params.Key = wire.ReaderKeyRegionNone, ""
			}
			c.send(t, 3, method, params)
			var changed wire.Envelope[wire.ReaderKeyResult]
			if err := json.Unmarshal(c.response(t, 3)["result"], &changed); err != nil {
				t.Fatal(err)
			}
			if method == "readerkey/set" && (!changed.Data.OtherKeyFound || changed.Data.Outcome != wire.ReaderKeySaved) {
				t.Fatalf("saved-key indication: %+v", changed.Data)
			}
			if method == "readerkey/remove" && (changed.Data.Outcome != wire.ReaderKeyRemoved || changed.Data.Present || changed.Data.OtherKeyFound) {
				t.Fatalf("remove: %+v", changed.Data)
			}
			c.next(t, func(m map[string]json.RawMessage) bool {
				if string(m["method"]) != `"rows/changed"` {
					return false
				}
				var update wire.Envelope[wire.RowsSnapshot]
				if json.Unmarshal(m["params"], &update) != nil {
					return false
				}
				for _, row := range update.Data.Projection.Rows {
					if row.ID == "zai" {
						if len(row.Accounts) != 1 {
							return false
						}
						account := row.Accounts[0]
						return account.ValueState == rows.ValueStateNone && account.SubscriptionRef == nil &&
							len(account.Windows) == 0 && hasDockSurface(row)
					}
				}
				return false
			})
			// Removing hides the indication because no manual key is in use. Saving another key must still find the same
			// detected reference: it belongs to the tool, not to the erased reading.
			c.send(t, 4, "readerkey/set", wire.ReaderKeyParams{Provider: wire.ReaderKeyProvider("zai"), Region: wire.ReaderKeyRegionGlobal, Key: "another-replacement-key"})
			if err := json.Unmarshal(c.response(t, 4)["result"], &changed); err != nil || !changed.Data.OtherKeyFound {
				t.Fatalf("detected-key indication was lost: %+v %v", changed.Data, err)
			}
		})
	}
}

// The production rows backend reads existing sanitized cache provenance. The
// real subscription survives failed, empty and missing detection snapshots,
// while its previous account's private values and identity do not follow it.
func TestEstablishedZCodeKeepsUnavailableRingAcrossCacheAndDetectionChanges(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	cache := t.TempDir()
	at := time.Now().UTC().Truncate(time.Second)
	detected := true
	paths := func(a consent.Admission) quota.Paths {
		return quota.Paths{Cache: cache, ConnectionsFile: filepath.Join(cache, "connections.json"), Admission: &a}
	}
	backend, err := NewSharedBackend(SharedConfig{now: func() time.Time { return at }, Paths: paths,
		Cleanup: func(scope string, forget bool) error {
			return quota.EraseScope(paths(consent.Capture()), scope, forget)
		},
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "zai", Preferred: "native", ReaderID: "native:zai"}, Detected: detected}}}
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := quota.SetConnection(paths(consent.Capture()).ConnectionsFile, quota.QuotaSource{Provider: "zai", Backend: quota.BackendNative, Enabled: true}); err != nil {
		t.Fatal(err)
	}
	t.Setenv("Z_AI_API_KEY", "synthetic-key")
	admission := consent.Capture()
	// This is the only durable proof written by the native reader after a usable read.
	stamp := admission.State().CaptureStamp(consent.ScopeZaiAccountUsageAPIKey)
	observed := filepath.Join(cache, "observed")
	if err := os.MkdirAll(observed, 0o700); err != nil {
		t.Fatal(err)
	}
	writeCache := func(entry map[string]any, established bool) {
		t.Helper()
		snap := map[string]any{"schemaVersion": 1, "providers": []any{entry}}
		if established {
			snap["zaiMembership"] = map[string]any{stamp.Scope: stamp}
		}
		data, _ := json.Marshal(snap)
		if err := os.WriteFile(filepath.Join(observed, "native.json"), data, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	row := func() *rows.Row {
		for _, r := range backend.buildView(consent.Capture(), false).Projection.Rows {
			if r.ID == "zai" {
				return &r
			}
		}
		return nil
	}
	expiredWindow := quota.Window{Kind: "five_hour", UsedPercent: new(float64), ObservedAt: at, ResetsAt: timePointer(at)}
	writeCache(map[string]any{"provider": "zai", "status": "ok", "admission": stamp,
		"observedAt": at, "windows": []quota.Window{expiredWindow}}, false)
	if r := row(); r == nil || hasDockSurface(*r) {
		t.Fatalf("expired first response established a ring: %+v", r)
	}
	for _, tc := range []struct {
		name, status, errorCode string
		state                   rows.State
	}{
		{"failed", "error", "network", rows.StateFailed},
		{"empty", "ok", "", rows.StateEmpty},
	} {
		entry := map[string]any{"provider": "zai", "status": tc.status, "errorCode": tc.errorCode, "admission": stamp, "observedAt": at}
		writeCache(entry, false)
		if r := row(); r == nil || hasDockSurface(*r) {
			t.Fatalf("%s first read should have no ring: %+v", tc.name, r)
		}
		writeCache(entry, true)
		r := row()
		if r == nil || !hasDockSurface(*r) || r.State != tc.state || len(r.Accounts) != 1 {
			t.Fatalf("%s read dropped the established ring: %+v", tc.name, r)
		}
		a := r.Accounts[0]
		if a.ValueState != rows.ValueStateNone || len(a.Windows) != 0 || a.SubscriptionRef != nil || len(a.Activity) != 0 {
			t.Fatalf("unavailable ring exposed an old account: %+v", a)
		}
	}
	detected = false
	if r := row(); r == nil || !hasDockSurface(*r) || r.Reason.Code != rows.CodeToolNotFound {
		t.Fatalf("temporary loss of detection removed the established ring: %+v", r)
	}
	state := consent.Capture().State()
	_, err = consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "deny-zai-ring", ExpectStoreEpoch: state.StoreEpoch,
		ExpectGeneration: state.Generation, ConsentTextVersion: consent.TextVersion, Deny: []string{stamp.Scope}},
		consent.GrantHooks{Cleanup: func(scope string, forget bool) error {
			return quota.EraseScope(paths(consent.Capture()), scope, forget)
		}})
	if err != nil {
		t.Fatal(err)
	}
	if r := row(); r != nil && (hasDockSurface(*r) || len(r.Accounts) != 0) {
		t.Fatalf("revoked scope left a ring or account: %+v", r)
	}
}

func hasDockSurface(row rows.Row) bool {
	for _, surface := range row.Surfaces {
		if surface == rows.SurfaceDock {
			return true
		}
	}
	return false
}

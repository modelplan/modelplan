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
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func TestAccountTodaySubscriptionWithdrawsExpiredEvidence(t *testing.T) {
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	cache := filepath.Join(home, "cache")
	for k, v := range map[string]string{"MODELPLAN_CACHE": cache, "MODELPLAN_READERS": "passive", "MODELPLAN_CODEX_ACCOUNT": "", "MODELPLAN_CODEXBAR": "off", "MODELPLAN_HISTORY": "", "MODELPLAN_IDENTITY": ""} {
		t.Setenv(k, v)
	}
	codexHome := filepath.Join(home, ".codex")
	if err := os.MkdirAll(codexHome, 0700); err != nil {
		t.Fatal(err)
	}
	start := time.Date(2026, 11, 4, 23, 59, 50, 0, time.Local)
	clock := &syntheticRefreshClock{now: start}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "codex", true, "native:codex", "native", start) }); err != nil {
		t.Fatal(err)
	}
	state, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	ref := "0123456789abcdef"
	epoch := &speed.GrantEpoch{StoreEpoch: state.StoreEpoch, RevokedGeneration: state.Revoked[consent.ScopeCodexLocalHistory]}
	observed := filepath.Join(cache, "observed")
	if err := os.MkdirAll(observed, 0700); err != nil {
		t.Fatal(err)
	}
	write := func(name string, v any) {
		t.Helper()
		b, err := json.Marshal(v)
		if err != nil {
			t.Fatal(err)
		}
		tmp := filepath.Join(observed, name+".tmp")
		if err = os.WriteFile(tmp, b, 0600); err != nil {
			t.Fatal(err)
		}
		if err = os.Rename(tmp, filepath.Join(observed, name)); err != nil {
			t.Fatal(err)
		}
	}
	write("codex-account.json", map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": start, "admission": state.CaptureStamp(consent.ScopeCodexRuntimeUsage), "subscriptionRef": ref, "windows": []any{map[string]any{"kind": "weekly", "usedPercent": 25, "windowMinutes": 10080, "resetsAt": start.Add(time.Hour), "observedAt": start}}})
	ledger := speed.PerfLedger{SchemaVersion: 1, Since: start.Add(-time.Hour), Rows: []speed.PerfRow{{GrantEpoch: epoch, Day: start.Format("2006-01-02"), Source: "codex", ObservedOutputTokens: 12000, EligibleRequests: 5, EligibleOutputTokens: 210, GenMs: 5000}}, Live: []speed.LiveRecord{{GrantEpoch: epoch, Ref: "1111111111111111", Source: "codex", SubscriptionRef: ref, LastAt: start.Add(-speed.LiveWithin + 5*time.Second), StartedAt: start.Add(-time.Hour), Running: true}}}
	write("perf.json", ledger)
	backend, err := NewSharedBackend(SharedConfig{now: clock.read, Detect: func() detect.Report {
		return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "codex", ReaderID: "native:codex", Preferred: "native"}, Detected: true}}}
	}, Paths: func(a consent.Admission) quota.Paths {
		return quota.Paths{Cache: cache, CodexHome: codexHome, Admission: &a}
	}, Cleanup: func(string, bool) error { return nil }})
	if err != nil {
		t.Fatal(err)
	}
	client := startClient(t, Config{Backend: backend})
	client.readMessages()
	client.send(t, 1, "initialize", wire.InitializeParams{SessionID: "expiry", ProtocolVersion: wire.ProtocolVersion, AppVersion: "test", Capabilities: []string{"rows", CapabilityAccountTodayV1}})
	if m := client.response(t, 1); m["error"] != nil {
		t.Fatalf("initialize: %s", m["error"])
	}
	client.send(t, 2, "rows/subscribe", wire.Empty{})
	parse := func(raw json.RawMessage) *rowsTodayResult {
		t.Helper()
		var envelope wire.Envelope[wire.RowsSnapshot]
		if err := json.Unmarshal(raw, &envelope); err != nil {
			t.Fatal(err)
		}
		for _, r := range envelope.Data.Projection.Rows {
			if r.ID == "codex" {
				for _, a := range r.Accounts {
					if a.SubscriptionRef != nil && *a.SubscriptionRef == ref && a.ValueState == rows.ValueStateCurrent {
						if a.Today == nil {
							return &rowsTodayResult{}
						}
						return &rowsTodayResult{tokens: a.Today.ObservedOutputTokens, running: a.Today.RunningSessions}
					}
				}
			}
		}
		return nil
	}
	first := parse(client.response(t, 2)["result"])
	if first == nil || first.tokens == nil || *first.tokens != 12000 || first.running == nil || *first.running != 1 {
		t.Fatalf("initial: %+v", first)
	}
	ledger.Rows[0].ObservedOutputTokens = 13000
	write("perf.json", ledger)
	changed := func(m map[string]json.RawMessage) bool {
		if string(m["method"]) != `"rows/changed"` {
			return false
		}
		got := parse(m["params"])
		return got != nil && got.tokens != nil && *got.tokens == 13000
	}
	client.next(t, changed)
	clock.set(start.Add(5 * time.Second))
	expired := client.next(t, func(m map[string]json.RawMessage) bool {
		if string(m["method"]) != `"rows/changed"` {
			return false
		}
		got := parse(m["params"])
		return got != nil && got.tokens != nil && *got.tokens == 13000 && got.running == nil
	})
	if expired == nil {
		t.Fatal("missing expired session withdrawal")
	}
	clock.set(start.Add(10 * time.Second))
	client.next(t, func(m map[string]json.RawMessage) bool {
		if string(m["method"]) != `"rows/changed"` {
			return false
		}
		got := parse(m["params"])
		return got != nil && got.tokens == nil && got.running == nil
	})
}

func TestAccountTodaySubscriptionWithdrawsExpiredBinding(t *testing.T) {
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	cache := filepath.Join(home, "cache")
	for k, v := range map[string]string{"MODELPLAN_CACHE": cache, "MODELPLAN_READERS": "passive", "MODELPLAN_CODEX_ACCOUNT": "", "MODELPLAN_CODEXBAR": "off", "MODELPLAN_HISTORY": "", "MODELPLAN_IDENTITY": ""} {
		t.Setenv(k, v)
	}
	codexHome := filepath.Join(home, ".codex")
	if err := os.MkdirAll(codexHome, 0700); err != nil {
		t.Fatal(err)
	}
	start := time.Date(2026, 11, 4, 12, 0, 0, 0, time.Local)
	clock := &syntheticRefreshClock{now: start}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "codex", true, "native:codex", "native", start) }); err != nil {
		t.Fatal(err)
	}
	state, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	ref := "0123456789abcdef"
	epoch := &speed.GrantEpoch{StoreEpoch: state.StoreEpoch, RevokedGeneration: state.Revoked[consent.ScopeCodexLocalHistory]}
	observed := filepath.Join(cache, "observed")
	if err := os.MkdirAll(observed, 0700); err != nil {
		t.Fatal(err)
	}
	write := func(name string, v any) {
		t.Helper()
		b, err := json.Marshal(v)
		if err != nil {
			t.Fatal(err)
		}
		tmp := filepath.Join(observed, name+".tmp")
		if err = os.WriteFile(tmp, b, 0600); err != nil {
			t.Fatal(err)
		}
		if err = os.Rename(tmp, filepath.Join(observed, name)); err != nil {
			t.Fatal(err)
		}
	}
	write("codex-account.json", map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": start, "admission": state.CaptureStamp(consent.ScopeCodexRuntimeUsage), "subscriptionRef": ref, "windows": []any{map[string]any{"kind": "weekly", "usedPercent": 25, "windowMinutes": 10080, "resetsAt": start.Add(time.Hour), "observedAt": start}}})
	ledger := speed.PerfLedger{SchemaVersion: 1, Since: start.Add(-time.Hour), Rows: []speed.PerfRow{{GrantEpoch: epoch, Day: start.Format("2006-01-02"), Source: "codex", ObservedOutputTokens: 12000, EligibleRequests: 5, EligibleOutputTokens: 210, GenMs: 5000}}}
	write("perf.json", ledger)
	backend, err := NewSharedBackend(SharedConfig{now: clock.read, Detect: func() detect.Report {
		return detect.Report{Tools: []detect.Tool{{Entry: detect.Entry{ProviderID: "codex", ReaderID: "native:codex", Preferred: "native"}, Detected: true}}}
	}, Paths: func(a consent.Admission) quota.Paths {
		return quota.Paths{Cache: cache, CodexHome: codexHome, Admission: &a}
	}, Cleanup: func(string, bool) error { return nil }})
	if err != nil {
		t.Fatal(err)
	}
	client := startClient(t, Config{Backend: backend})
	client.readMessages()
	client.send(t, 1, "initialize", wire.InitializeParams{SessionID: "expiry", ProtocolVersion: wire.ProtocolVersion, AppVersion: "test", Capabilities: []string{"rows", CapabilityAccountTodayV1}})
	if m := client.response(t, 1); m["error"] != nil {
		t.Fatalf("initialize: %s", m["error"])
	}
	client.send(t, 2, "rows/subscribe", wire.Empty{})
	parse := func(raw json.RawMessage) *rowsTodayResult {
		t.Helper()
		var envelope wire.Envelope[wire.RowsSnapshot]
		if err := json.Unmarshal(raw, &envelope); err != nil {
			t.Fatal(err)
		}
		for _, r := range envelope.Data.Projection.Rows {
			if r.ID == "codex" {
				for _, a := range r.Accounts {
					if a.SubscriptionRef != nil && *a.SubscriptionRef == ref {
						if a.Today == nil {
							return &rowsTodayResult{}
						}
						return &rowsTodayResult{tokens: a.Today.ObservedOutputTokens, running: a.Today.RunningSessions}
					}
				}
			}
		}
		return nil
	}
	first := parse(client.response(t, 2)["result"])
	if first == nil || first.tokens == nil || *first.tokens != 12000 || first.running != nil {
		t.Fatalf("initial: %+v", first)
	}
	// Observe a real cache notification before advancing the clock. That
	// ensures the watcher has armed its first time-only deadline.
	ledger.Rows[0].ObservedOutputTokens = 13000
	write("perf.json", ledger)
	client.next(t, func(m map[string]json.RawMessage) bool {
		if string(m["method"]) != `"rows/changed"` {
			return false
		}
		got := parse(m["params"])
		return got != nil && got.tokens != nil && *got.tokens == 13000
	})

	// No filesystem write or other deadline occurs. The current source binding
	// becomes too old just after one hour and the subscribed total must vanish.
	clock.set(start.Add(time.Hour + time.Nanosecond))
	client.next(t, func(m map[string]json.RawMessage) bool {
		if string(m["method"]) != `"rows/changed"` {
			return false
		}
		got := parse(m["params"])
		return got != nil && got.tokens == nil && got.running == nil
	})
}

type rowsTodayResult struct {
	tokens  *int64
	running *int
}

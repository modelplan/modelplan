// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestHistoryRevokeAndForgetEraseAllLedgersAndDesktop(t *testing.T) {
	for _, forget := range []bool{false, true} {
		t.Run(map[bool]string{false: "revoke-with-retry", true: "forget"}[forget], func(t *testing.T) {
			consentFixtureHome(t)
			t.Setenv("MODELPLAN_HISTORY", "")
			t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
			t.Setenv("MODELPLAN_CODEXBAR", "off")
			st, err := store.Locate()
			if err != nil {
				t.Fatal(err)
			}
			state, err := consent.EnsureStore(consent.Path())
			if err != nil {
				t.Fatal(err)
			}
			hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) { return consent.Record{}, nil }, Cleanup: func(scope string, forget bool) error {
				return quota.EraseScope(quota.Paths{Cache: st.Dir}, scope, forget)
			}}
			_, err = consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "allow", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCodexLocalHistory, consent.ScopeClaudeLocalHistory}}, hooks)
			if err != nil {
				t.Fatal(err)
			}
			now := time.Now().UTC()
			day := now.Local().Format("2006-01-02")
			ledger := speed.Ledger{SchemaVersion: 1, Rows: []speed.Row{{Source: "codex", Day: day, Model: "synthetic", Requests: 5, OutputTokens: 100, GenMs: 1000}, {Source: "claude-code", Day: day, Model: "synthetic", Requests: 5, OutputTokens: 100, GenMs: 1000}}}
			perf := speed.PerfLedger{SchemaVersion: 1, Since: now.Add(-time.Hour), Rows: []speed.PerfRow{{Source: "codex", Day: day, Model: "synthetic", ObservedRequests: 1, ObservedOutputTokens: 50}, {Source: "claude-code", Day: day, Model: "synthetic", ObservedRequests: 1, ObservedOutputTokens: 50}}, Live: []speed.LiveRecord{{Ref: "1111111111111111", Source: "codex", Model: "synthetic", LastAt: now.Add(-time.Second)}, {Ref: "2222222222222222", Source: "claude-code", Model: "synthetic", LastAt: now.Add(-time.Second)}}}
			long := speed.LongLedger{SchemaVersion: 1, Since: now.Add(-time.Hour), Rows: []speed.Daily{{Source: "codex", Day: day, Model: "synthetic", ObservedOutputTokens: 50, ObservedRequests: 1}, {Source: "claude-code", Day: day, Model: "synthetic", ObservedOutputTokens: 50, ObservedRequests: 1}}}
			if err := os.MkdirAll(filepath.Join(st.Dir, "observed"), 0700); err != nil {
				t.Fatal(err)
			}
			for path, value := range map[string]any{speed.Path(st.Dir): ledger, speed.PerfPath(st.Dir): perf, speed.LongPath(st.Dir): long} {
				b, err := json.Marshal(value)
				if err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(path, b, 0600); err != nil {
					t.Fatal(err)
				}
			}
			desktop := func() snapshot.Snapshot {
				var output bytes.Buffer
				if code := desktopCmd(&output, st, common{offline: true}, true); code != 0 {
					t.Fatalf("desktop exit %d", code)
				}
				var result snapshot.Snapshot
				if err := json.Unmarshal(output.Bytes(), &result); err != nil {
					t.Fatal(err)
				}
				return result
			}
			check := func(result snapshot.Snapshot, codex bool) {
				b, err := json.Marshal([]any{result.Measured, result.LiveSessions, result.TodayTotals, result.Hourly, result.PerfStats, result.Daily, result.DailyLong, result.SessionRanking, result.ProjectRanking})
				if err != nil {
					t.Fatal(err)
				}
				if strings.Contains(string(b), `"source":"codex"`) != codex || !strings.Contains(string(b), `"source":"claude-code"`) {
					t.Fatalf("unexpected desktop sources: %s", b)
				}
			}
			check(desktop(), true)
			lock := filepath.Join(st.Dir, "observed", "perf.lock")
			if !forget {
				if err := os.WriteFile(lock, nil, 0600); err != nil {
					t.Fatal(err)
				}
			}
			state = consent.Capture().State()
			grant := consent.Grant{RequestID: "remove", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation}
			if forget {
				grant.Forget = []string{consent.ScopeCodexLocalHistory}
			} else {
				grant.Deny = []string{consent.ScopeCodexLocalHistory}
			}
			receipt, err := consent.ApplyGrant(consent.Path(), grant, hooks)
			if err != nil && !receipt.Committed {
				t.Fatal(err)
			}
			if !forget && len(receipt.CleanupPending) == 0 {
				t.Fatal("busy cleanup was not retained")
			}
			check(desktop(), false)
			if !forget {
				if err := os.Remove(lock); err != nil {
					t.Fatal(err)
				}
				if err := consent.RetryCleanup(consent.Path(), hooks.Cleanup); err != nil {
					t.Fatal(err)
				}
			}
			for _, path := range []string{speed.Path(st.Dir), speed.PerfPath(st.Dir), speed.LongPath(st.Dir)} {
				b, err := os.ReadFile(path)
				if err != nil || strings.Contains(string(b), `"source":"codex"`) || !strings.Contains(string(b), `"source":"claude-code"`) {
					t.Fatalf("ledger cleanup %s: %s, %v", path, b, err)
				}
			}
			state = consent.Capture().State()
			_, err = consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "regrant", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCodexLocalHistory}}, hooks)
			if err != nil {
				t.Fatal(err)
			}
			check(desktop(), false)
		})
	}
}

func TestHistoryCleanupRecoversAbandonedWriterLocks(t *testing.T) {
	for _, name := range []string{"speed.lock", "perf.lock"} {
		for _, forget := range []bool{false, true} {
			t.Run(name+map[bool]string{false: "-revoke", true: "-forget"}[forget], func(t *testing.T) {
				consentFixtureHome(t)
				st, err := store.Locate()
				if err != nil {
					t.Fatal(err)
				}
				state, err := consent.EnsureStore(consent.Path())
				if err != nil {
					t.Fatal(err)
				}
				hooks := consent.GrantHooks{Admit: func(consent.ScopeDefinition) (consent.Record, error) { return consent.Record{}, nil }, Cleanup: func(scope string, forget bool) error {
					return quota.EraseScope(quota.Paths{Cache: st.Dir}, scope, forget)
				}}
				_, err = consent.ApplyGrant(consent.Path(), consent.Grant{RequestID: "allow", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation, ConsentTextVersion: consent.TextVersion, Allow: []string{consent.ScopeCodexLocalHistory}}, hooks)
				if err != nil {
					t.Fatal(err)
				}
				dir := filepath.Join(st.Dir, "observed")
				if err := os.MkdirAll(dir, 0700); err != nil {
					t.Fatal(err)
				}
				for _, file := range []string{"speed.json", "perf.json", "daily-long.json"} {
					b := []byte(`{"schemaVersion":1,"rows":[{"source":"codex"},{"source":"claude-code"}]}`)
					if file == "perf.json" {
						b = []byte(`{"schemaVersion":1,"rows":[{"source":"codex"},{"source":"claude-code"}],"live":[{"source":"codex"},{"source":"claude-code"}]}`)
					}
					if err := os.WriteFile(filepath.Join(dir, file), b, 0600); err != nil {
						t.Fatal(err)
					}
				}
				lock := filepath.Join(dir, name)
				if err := os.WriteFile(lock, []byte("active"), 0600); err != nil {
					t.Fatal(err)
				}
				state = consent.Capture().State()
				request := consent.Grant{RequestID: "remove", ExpectStoreEpoch: state.StoreEpoch, ExpectGeneration: state.Generation}
				if forget {
					request.Forget = []string{consent.ScopeCodexLocalHistory}
				} else {
					request.Deny = []string{consent.ScopeCodexLocalHistory}
				}
				receipt, err := consent.ApplyGrant(consent.Path(), request, hooks)
				if err != nil && !receipt.Committed {
					t.Fatal(err)
				}
				if len(receipt.CleanupPending) != 1 {
					t.Fatalf("fresh lock stolen: %#v", receipt)
				}
				if err := consent.RetryCleanup(consent.Path(), hooks.Cleanup); err != nil {
					t.Fatal(err)
				}
				if !consent.Capture().CleanupPending(consent.ScopeCodexLocalHistory) {
					t.Fatal("fresh lock did not preserve pending cleanup")
				}
				if b, err := os.ReadFile(lock); err != nil || string(b) != "active" {
					t.Fatalf("fresh lock changed: %q, %v", b, err)
				}
				old := time.Now().Add(-time.Minute)
				if err := os.Chtimes(lock, old, old); err != nil {
					t.Fatal(err)
				}
				if err := consent.RetryCleanup(consent.Path(), hooks.Cleanup); err != nil {
					t.Fatal(err)
				}
				if consent.Capture().CleanupPending(consent.ScopeCodexLocalHistory) {
					t.Fatal("stale lock left cleanup pending")
				}
				if _, err := os.Stat(lock); !os.IsNotExist(err) {
					t.Fatalf("stale lock survived: %v", err)
				}
				for _, file := range []string{"speed.json", "perf.json", "daily-long.json"} {
					b, err := os.ReadFile(filepath.Join(dir, file))
					if err != nil || strings.Contains(string(b), `"source":"codex"`) || !strings.Contains(string(b), `"source":"claude-code"`) {
						t.Fatalf("bad cleanup for %s: %s, %v", file, b, err)
					}
				}
			})
		}
	}
}

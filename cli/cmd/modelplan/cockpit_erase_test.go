//go:build darwin || linux

// SPDX-License-Identifier: MIT
package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
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
			var held *os.File
			if !forget {
				held = holdTestLedgerLock(t, lock)
				defer held.Close()
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
				if err := syscall.Flock(int(held.Fd()), syscall.LOCK_UN); err != nil {
					t.Fatal(err)
				}
				if err := held.Close(); err != nil {
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

// holdTestLedgerLock holds a real advisory lock on the persistent inode.
func holdTestLedgerLock(t *testing.T, path string) *os.File {
	t.Helper()
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		t.Fatal(err)
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		f.Close()
		t.Fatal(err)
	}
	return f
}

func TestHistoryCleanupNeverStealsSlowWriterLocks(t *testing.T) {
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
				path := filepath.Join(dir, name)
				held := holdTestLedgerLock(t, path)
				defer held.Close()
				inode, err := os.Stat(path)
				if err != nil {
					t.Fatal(err)
				}
				old := time.Now().Add(-time.Hour)
				if err := os.Chtimes(path, old, old); err != nil {
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
					t.Fatalf("slow live lock stolen: %#v", receipt)
				}
				if err := consent.RetryCleanup(consent.Path(), hooks.Cleanup); err != nil {
					t.Fatal(err)
				}
				if !consent.Capture().CleanupPending(consent.ScopeCodexLocalHistory) {
					t.Fatal("live lock did not preserve pending cleanup")
				}
				after, err := os.Stat(path)
				if err != nil || !os.SameFile(inode, after) {
					t.Fatal("live lock inode replaced", err)
				}
				// Simulate the writer completing its delayed read-modify-write while
				// still holding the lock. Cleanup must run only after this write.
				target := "speed.json"
				if name == "perf.lock" {
					target = "perf.json"
				}
				if err := os.WriteFile(filepath.Join(dir, target), []byte(`{"rows":[{"source":"codex"},{"source":"claude-code"}]}`), 0600); err != nil {
					t.Fatal(err)
				}
				if err := syscall.Flock(int(held.Fd()), syscall.LOCK_UN); err != nil {
					t.Fatal(err)
				}
				if err := held.Close(); err != nil {
					t.Fatal(err)
				}
				if err := consent.RetryCleanup(consent.Path(), hooks.Cleanup); err != nil {
					t.Fatal(err)
				}
				if consent.Capture().CleanupPending(consent.ScopeCodexLocalHistory) {
					t.Fatal("released lock left cleanup pending")
				}
				after, err = os.Stat(path)
				if err != nil || !os.SameFile(inode, after) {
					t.Fatal("cleanup removed persistent lock", err)
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

func TestHistoryLedgerLockChildProcess(t *testing.T) {
	path := os.Getenv("MODELPLAN_TEST_LEDGER_LOCK_CHILD")
	if path == "" {
		return
	}
	f := holdTestLedgerLock(t, path)
	defer f.Close()
	fmt.Println("locked")
	time.Sleep(time.Hour)
}

func TestKilledWriterReleasesLedgerLockForCleanup(t *testing.T) {
	for _, name := range []string{"speed.lock", "perf.lock"} {
		t.Run(name, func(t *testing.T) {
			t.Setenv("HOME", t.TempDir())
			cache := t.TempDir()
			dir := filepath.Join(cache, "observed")
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			for _, file := range []string{"speed.json", "perf.json", "daily-long.json"} {
				if err := os.WriteFile(filepath.Join(dir, file), []byte(`{"rows":[{"source":"codex"},{"source":"claude-code"}]}`), 0600); err != nil {
					t.Fatal(err)
				}
			}
			exe, err := os.Executable()
			if err != nil {
				t.Fatal(err)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			path := filepath.Join(dir, name)
			cmd := exec.CommandContext(ctx, exe, "-test.run=^TestHistoryLedgerLockChildProcess$")
			cmd.Env = append(os.Environ(), "MODELPLAN_TEST_LEDGER_LOCK_CHILD="+path)
			out, err := cmd.StdoutPipe()
			if err != nil {
				t.Fatal(err)
			}
			if err := cmd.Start(); err != nil {
				t.Fatal(err)
			}
			defer func() {
				if cmd.ProcessState == nil {
					_ = cmd.Process.Kill()
					_ = cmd.Wait()
				}
			}()
			scanner := bufio.NewScanner(out)
			if !scanner.Scan() || scanner.Text() != "locked" {
				t.Fatal("child did not acquire ledger lock")
			}
			inode, err := os.Stat(path)
			if err != nil {
				t.Fatal(err)
			}
			if err := quota.EraseScope(quota.Paths{Cache: cache}, consent.ScopeCodexLocalHistory, false); err == nil {
				t.Fatal("live child lock was ignored")
			}
			if err := cmd.Process.Kill(); err != nil {
				t.Fatal(err)
			}
			_ = cmd.Wait()
			if err := quota.EraseScope(quota.Paths{Cache: cache}, consent.ScopeCodexLocalHistory, false); err != nil {
				t.Fatal("dead child left cleanup locked", err)
			}
			after, err := os.Stat(path)
			if err != nil || !os.SameFile(inode, after) {
				t.Fatal("lock inode changed", err)
			}
			for _, file := range []string{"speed.json", "perf.json", "daily-long.json"} {
				b, err := os.ReadFile(filepath.Join(dir, file))
				if err != nil || strings.Contains(string(b), `"source":"codex"`) || !strings.Contains(string(b), `"source":"claude-code"`) {
					t.Fatalf("bad cleanup %s: %s, %v", file, b, err)
				}
			}
		})
	}
}

// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func codexScript(t *testing.T, body string) string {
	t.Helper()
	bin := filepath.Join(t.TempDir(), "codex")
	if err := os.WriteFile(bin, []byte("#!/bin/sh\n"+body), 0o700); err != nil {
		t.Fatal(err)
	}
	return bin
}

// D87 slice 4: every Codex failure path stores its own fixed cause code.
func TestD87CodexFailurePathsStoreTheirOwnCauseCode(t *testing.T) {
	rpcError := codexScript(t, `[ "$1" = app-server ] || exit 2
while IFS= read -r line; do
  echo '{"id":1,"error":{"message":"secret provider text"}}'
done
`)
	cases := []struct{ name, bin, want string }{
		{"binary missing", "", "not_found"},
		{"service closed", failingCodex(t), "closed"},
		{"service rpc error", rpcError, "rpc_error"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			isolateHome(t)
			cache := t.TempDir()
			_ = RefreshCodexAccount(context.Background(), cache, c.bin, acctNow)
			s := loadAccount(cache)
			if s == nil || s.Status == "ok" || s.ErrorCode != c.want || s.failureCode() != c.want {
				t.Fatalf("snapshot %+v, want cause %q", s, c.want)
			}
			if got := codexFailureState(s); got != "unavailable:reader_error:"+c.want {
				t.Fatalf("state %q", got)
			}
			if diagnosticCause(codexFailureState(s)) != c.want {
				t.Fatalf("diagnostic cause %q", diagnosticCause(codexFailureState(s)))
			}
		})
	}
}

func TestD87DiagnosticCauseOnlyForFailedStates(t *testing.T) {
	for _, c := range [][2]string{
		{"unavailable:binary_found_but_runtime_missing", "runtime_missing"},
		{"unavailable:reader_error:timeout", "timeout"},
		{"unavailable:reader_error:secret", "other"},
		{"unavailable:not_admitted", ""},
		{"ok", ""},
		{"stale", ""},
	} {
		if got := diagnosticCause(c[0]); got != c[1] {
			t.Errorf("%q: %q, want %q", c[0], got, c[1])
		}
	}
	for _, code := range []string{"not_found", "rpc_error", "closed", "no_key", "region_refused"} {
		if ReaderErrorCode(code) != code {
			t.Errorf("%s is not in the reader vocabulary", code)
		}
	}
}

// The ring keeps the last failures with their streak, survives a good read, and is bounded.
func TestD87FailureRingKeepsCausesAcrossAGoodRead(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	failing := failingCodex(t)
	good, _ := fakeCodex(t, acctResponse)
	hour := time.Hour
	_ = RefreshCodexAccount(context.Background(), cache, failing, acctNow)
	_ = RefreshCodexAccount(context.Background(), cache, "", acctNow.Add(hour))
	if err := RefreshCodexAccount(context.Background(), cache, good, acctNow.Add(2*hour)); err != nil {
		t.Fatal(err)
	}
	s := loadAccount(cache)
	if s.Status != "ok" || len(s.Failures) != 2 {
		t.Fatalf("after a good read: status %q, ring %+v", s.Status, s.Failures)
	}
	if f := s.Failures[0]; f.Code != "closed" || f.StreakSeconds != 0 || !f.At.Equal(acctNow) {
		t.Fatalf("first failure %+v", f)
	}
	if f := s.Failures[1]; f.Code != "not_found" || f.StreakSeconds != 3600 {
		t.Fatalf("second failure %+v", f)
	}
	_ = RefreshCodexAccount(context.Background(), cache, failing, acctNow.Add(3*hour))
	s = loadAccount(cache)
	if len(s.Failures) != 3 || s.Failures[2].Code != "closed" || s.Failures[2].StreakSeconds != 0 {
		t.Fatalf("a new streak starts at zero: %+v", s.Failures)
	}
	if s.Good != nil && len(s.Good.Failures) != 0 {
		t.Fatalf("the retained reading must not carry its own ring: %+v", s.Good.Failures)
	}
	for i := 4; i < 16; i++ {
		_ = RefreshCodexAccount(context.Background(), cache, failing, acctNow.Add(time.Duration(i)*hour))
	}
	s = loadAccount(cache)
	if len(s.Failures) != accountFailureRing {
		t.Fatalf("ring holds %d, want %d", len(s.Failures), accountFailureRing)
	}
	last := s.Failures[len(s.Failures)-1]
	if last.StreakSeconds != int64(12*3600) { // streak began at hour 3
		t.Fatalf("streak %d", last.StreakSeconds)
	}
}

// A newer ok snapshot never reports reader_error because of earlier failures, and a failure
// too old to describe anything current is stale, with its cause kept in the ring.
func TestD87StaleSnapshotDoesNotReportReaderErrorOnceNewerOkExists(t *testing.T) {
	failed := accountSnap{SchemaVersion: 1, Status: "error", ErrorCode: "timeout", ObservedAt: acctNow,
		Failures: []accountFailure{{Code: "timeout", At: acctNow}}}
	if got := codexAccountState(&failed, acctNow.Add(time.Minute)); got != "unavailable:reader_error:timeout" {
		t.Fatalf("recent failure: %q", got)
	}
	if got := codexAccountState(&failed, acctNow.Add(accountKeep+time.Minute)); got != "stale" {
		t.Fatalf("old failure: %q", got)
	}
	ok := accountSnap{SchemaVersion: 1, Status: "ok", ObservedAt: acctNow.Add(time.Hour), Failures: failed.Failures}
	if got := codexAccountState(&ok, acctNow.Add(2*time.Hour)); got != "ok" {
		t.Fatalf("newer ok: %q", got)
	}
	if got := codexAccountState(&ok, acctNow.Add(accountKeep+2*time.Hour)); got != "stale" {
		t.Fatalf("old ok: %q", got)
	}
}

// A relay base URL is refused with its own cause; an official host with no key says no_key.
func TestD87ZaiRelayAndMissingKeyCauses(t *testing.T) {
	isolateHome(t)
	code := func(base, token string) string {
		b, _ := json.Marshal(map[string]any{"env": map[string]string{"ANTHROPIC_BASE_URL": base, "ANTHROPIC_AUTH_TOKEN": token}})
		_, _, _, c := zaiConfiguredKeyCode(ZaiConfigSource{Tool: "claude-code", SettingsPath: zaiConfigTestFile(t, string(b))})
		return c
	}
	if got := code("https://relay.example.test/api/anthropic", "key-canary"); got != "region_refused" {
		t.Fatalf("relay: %q", got)
	}
	if got := code("https://api.z.ai/api/anthropic", ""); got != "no_key" {
		t.Fatalf("no key: %q", got)
	}
	if got := code("https://api.z.ai/api/anthropic", "key-canary"); got != "" {
		t.Fatalf("official host with a key: %q", got)
	}
}

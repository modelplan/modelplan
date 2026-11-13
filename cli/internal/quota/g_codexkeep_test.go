// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/toolcli"
)

func goodAccount(t *testing.T, cache string, at time.Time) {
	t.Helper()
	var resp rlResponse
	if err := json.Unmarshal([]byte(acctResponse), &resp); err != nil {
		t.Fatal(err)
	}
	if err := save(cache, snapFrom(&resp, at)); err != nil {
		t.Fatal(err)
	}
}

// A failed refresh right after a good reading keeps its windows, marks the row stale and names
// the failure; the back-off still holds the next read back.
func TestFailedRefreshKeepsTheLastGoodWindowsStale(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	goodAccount(t, cache, acctNow)
	at := acctNow.Add(10 * time.Minute)
	if err := RefreshCodexAccount(context.Background(), cache, failingCodex(t), at); err == nil {
		t.Fatal("a failing Codex reported success")
	}
	s := loadAccount(cache)
	if s.Status != "error" || s.Good == nil || len(s.Good.Windows) != 2 || s.ErrorCode == "" {
		t.Fatalf("snapshot %+v", s)
	}
	if AccountDue(cache, at.Add(29*time.Minute)) || !AccountDue(cache, at.Add(accountRetryAfter)) {
		t.Fatal("the failure no longer schedules the ordinary retry")
	}
	r := Report{}
	applyAccount(&r, cache, at.Add(time.Minute))
	Evaluate(&r.Accounts[0], at.Add(time.Minute))
	a := r.Accounts[0]
	if len(a.Windows) != 2 || !a.Stale || !a.ObservedAt.Equal(acctNow) {
		t.Fatalf("account %+v", a)
	}
	if len(r.Sources) != 1 || r.Sources[0].Status != "stale" || r.Sources[0].ErrorCode != s.ErrorCode || r.Sources[0].Reason == "" {
		t.Fatalf("sources %+v", r.Sources)
	}
	// A second failure keeps carrying the same good reading.
	if err := RefreshCodexAccount(context.Background(), cache, failingCodex(t), at.Add(accountRetryAfter)); err == nil {
		t.Fatal("a failing Codex reported success")
	}
	if g := loadAccount(cache).Good; g == nil || !g.ObservedAt.Equal(acctNow) {
		t.Fatalf("good reading lost on a second failure: %+v", g)
	}
	// A later good read clears the failure and the stale mark.
	bin, _ := fakeCodex(t, acctResponse)
	if err := RefreshCodexAccount(context.Background(), cache, bin, at.Add(2*accountRetryAfter)); err != nil {
		t.Fatal(err)
	}
	r = Report{}
	applyAccount(&r, cache, at.Add(2*accountRetryAfter))
	Evaluate(&r.Accounts[0], at.Add(2*accountRetryAfter))
	if r.Accounts[0].Stale || loadAccount(cache).Good != nil {
		t.Fatal("stale mark kept after a good reading")
	}
}

// Past accountKeep a failure has nothing to keep: no windows, an error.
func TestFailedRefreshAfterAccountKeepKeepsNothing(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	goodAccount(t, cache, acctNow)
	at := acctNow.Add(accountKeep + time.Minute)
	if err := RefreshCodexAccount(context.Background(), cache, failingCodex(t), at); err == nil {
		t.Fatal("a failing Codex reported success")
	}
	if s := loadAccount(cache); s.Status != "error" || s.Good != nil {
		t.Fatalf("snapshot %+v", s)
	}
	r := Report{}
	applyAccount(&r, cache, at)
	if len(r.Accounts) != 0 {
		t.Fatalf("accounts %+v", r.Accounts)
	}
	// A retained reading that ages past accountKeep after the failure also drops out.
	cache = t.TempDir()
	goodAccount(t, cache, acctNow)
	if err := RefreshCodexAccount(context.Background(), cache, failingCodex(t), acctNow.Add(10*time.Minute)); err == nil {
		t.Fatal("a failing Codex reported success")
	}
	r = Report{}
	applyAccount(&r, cache, acctNow.Add(accountKeep+time.Minute))
	if len(r.Accounts) != 0 {
		t.Fatalf("accounts %+v", r.Accounts)
	}
}

// A missing Codex binary keeps the windows too, and the state names the not_found cause.
func TestMissingCodexKeepsWindowsAndSaysNotFound(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	goodAccount(t, cache, acctNow)
	at := acctNow.Add(10 * time.Minute)
	if err := RefreshCodexAccount(context.Background(), cache, "", at); err != nil {
		t.Fatal(err)
	}
	r := Report{}
	applyAccount(&r, cache, at)
	if len(r.Accounts) != 1 || len(r.Accounts[0].Windows) != 2 {
		t.Fatalf("accounts %+v", r.Accounts)
	}
	if s := loadAccount(cache); codexFailureState(s) != "unavailable:reader_error:not_found" {
		t.Fatalf("state %q", codexFailureState(s))
	}
}

func TestCodexFailureStateMatchesTheOtherReaders(t *testing.T) {
	cases := []struct {
		s    accountSnap
		want string
	}{
		{accountSnap{Status: toolcli.RuntimeMissing}, "unavailable:" + toolcli.RuntimeMissing},
		{accountSnap{Status: "error", Error: "codex not found"}, "unavailable:reader_error:not_found"},
		{accountSnap{Status: "error", ErrorCode: "not_found"}, "unavailable:reader_error:not_found"},
		{accountSnap{Status: "error", ErrorCode: "rpc_error"}, "unavailable:reader_error:rpc_error"},
		{accountSnap{Status: "error", ErrorCode: "closed"}, "unavailable:reader_error:closed"},
		{accountSnap{Status: "error", ErrorCode: "runtime_missing"}, "unavailable:" + toolcli.RuntimeMissing},
		{accountSnap{Status: "error", ErrorCode: "timeout"}, "unavailable:reader_error:timeout"},
		{accountSnap{Status: "error", ErrorCode: "secret text"}, "unavailable:reader_error:other"},
		{accountSnap{Status: "error"}, "unavailable:reader_error:other"},
	}
	for _, c := range cases {
		if got := codexFailureState(&c.s); got != c.want {
			t.Errorf("%+v: %q, want %q", c.s, got, c.want)
		}
	}
}

// With session logs present the log reading wins, so the failure source must not claim the
// retained windows are shown, and the retained windows are not merged.
func TestFailedRefreshWithSessionLogsDoesNotClaimRetainedWindows(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	goodAccount(t, cache, acctNow)
	at := acctNow.Add(10 * time.Minute)
	if err := RefreshCodexAccount(context.Background(), cache, failingCodex(t), at); err == nil {
		t.Fatal("a failing Codex reported success")
	}
	used := 5.0
	r := Report{Accounts: []Account{{Source: "codex", ObservedAt: at, Windows: []Window{{Kind: "five_hour", UsedPercent: &used, ObservedAt: at}}}}}
	applyAccount(&r, cache, at.Add(time.Minute))
	if len(r.Accounts) != 1 || r.Accounts[0].Via != "" || len(r.Accounts[0].Windows) != 1 {
		t.Fatalf("accounts %+v", r.Accounts)
	}
	if len(r.Sources) != 1 || r.Sources[0].Status != "stale" || strings.Contains(r.Sources[0].Reason, "showing") || !strings.Contains(r.Sources[0].Reason, "session-log") {
		t.Fatalf("sources %+v", r.Sources)
	}
}

// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"github.com/modelplan/modelplan/cli/internal/store"
)

type nativeRefreshTransport func(*http.Request) (*http.Response, error)

func (f nativeRefreshTransport) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }

func nativeRefreshHome(t *testing.T) string {
	t.Helper()
	home := consentAPIHome(t)
	for _, name := range []string{"ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX", "CLAUDE_CODE_USE_FOUNDRY", "MODELPLAN_CODEX_ACCOUNT"} {
		t.Setenv(name, "")
	}
	t.Setenv("MODELPLAN_HISTORY", "off")
	old := startNativeDetached
	t.Cleanup(func() { startNativeDetached = old })
	startNativeDetached = func(string, ...string) error { t.Fatal("unexpected native worker"); return nil }
	st, err := store.Open()
	if err != nil {
		t.Fatal(err)
	}
	// Suppress public syncs, including the hook's initial synchronous sync.
	if err := st.SaveState(store.State{LastAttemptAt: time.Now(), CheckedAt: time.Now()}); err != nil {
		t.Fatal(err)
	}
	return home
}

func TestDesktopJSONConsentSchedulesFirstNativeReadThenShowsValues(t *testing.T) {
	home := nativeRefreshHome(t)
	credential := fmt.Sprintf(`{"claudeAiOauth":{"accessToken":"synthetic-desktop-token","expiresAt":%d,"scopes":["user:profile"],"subscriptionType":"max"}}`, time.Now().Add(24*time.Hour).UnixMilli())
	if err := os.WriteFile(filepath.Join(home, ".claude", ".credentials.json"), []byte(credential), 0600); err != nil {
		t.Fatal(err)
	}
	grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude", "codex"}, nil, nil))
	if !consent.Allowed("codex", consent.Runtime) {
		t.Fatal("JSON grant failed to admit the Codex runtime")
	}
	st, _ := store.Locate()
	if !quota.NativeDue(quotaPaths(st), time.Now()) {
		t.Fatal("first admitted read was not immediately due")
	}
	requests := []string{}
	oldTransport := http.DefaultTransport
	http.DefaultTransport = nativeRefreshTransport(func(r *http.Request) (*http.Response, error) {
		if r.URL.Host != "api.anthropic.com" || r.Method != "GET" || r.Header.Get("Authorization") != "Bearer synthetic-desktop-token" {
			t.Fatal("unexpected request", r.URL.Host, r.URL.Path)
		}
		requests = append(requests, r.URL.Path)
		body := `{"account":{"uuid":"synthetic-account-001"},"organization":{"uuid":"synthetic-org-001"}}`
		if r.URL.Path == "/api/oauth/usage" {
			body = fmt.Sprintf(`{"five_hour":{"utilization":23,"resets_at":%q},"seven_day":{"utilization":42,"resets_at":%q}}`, time.Now().Add(time.Hour).UTC().Format(time.RFC3339), time.Now().Add(7*24*time.Hour).UTC().Format(time.RFC3339))
		} else if r.URL.Path != "/api/oauth/profile" {
			t.Fatal("unexpected provider path", r.URL.Path)
		}
		return &http.Response{StatusCode: 200, Header: make(http.Header), Body: io.NopCloser(strings.NewReader(body))}, nil
	})
	t.Cleanup(func() { http.DefaultTransport = oldTransport })
	nativeStarts, accountStarts := 0, 0
	var worker []string
	startNativeDetached = func(lock string, args ...string) error {
		if lock != filepath.Join(st.Dir, "observed", "native-refresh.lock") {
			t.Fatal("wrong shared lock", lock)
		}
		nativeStarts++
		worker = append([]string{}, args...)
		return nil
	}
	startDetached = func(args ...string) error {
		if reflect.DeepEqual(args, []string{"quota", "--refresh-account", "--quiet"}) {
			accountStarts++
		} else {
			t.Fatal("unexpected child", args)
		}
		return nil
	}
	poll := func() snapshot.Snapshot {
		t.Helper()
		code, out, stderr := consentRun([]string{"desktop", "--json"}, "")
		var s snapshot.Snapshot
		if code != 0 || stderr != "" || json.Unmarshal([]byte(out), &s) != nil {
			t.Fatal(code, out, stderr)
		}
		return s
	}
	first := poll()
	if nativeStarts != 1 || accountStarts != 1 || len(first.Accounts) != 0 || len(requests) != 0 || !reflect.DeepEqual(worker, []string{"connections", "refresh", "--quiet", "--scheduled"}) {
		t.Fatal("first poll did not schedule cache fill", nativeStarts, accountStarts, first.Accounts, worker, requests)
	}
	// A concurrent Codex/helper read can hold admission beyond its ordinary
	// two-second wait. The already scheduled child must eventually fill the
	// cache rather than requiring another desktop poll to launch a retry.
	unlock, err := consent.ReaderLock()
	if err != nil {
		t.Fatal(err)
	}
	released := make(chan struct{})
	time.AfterFunc(2250*time.Millisecond, func() { unlock(); close(released) })
	t.Cleanup(func() { <-released })
	started := time.Now()
	code, out, stderr := consentRun(worker, "")
	if code != 0 || out != "" || stderr != "" || len(requests) != 2 {
		t.Fatal("quiet background worker failed", code, out, stderr, requests)
	}
	if time.Since(started) >= time.Minute {
		t.Fatal("first native cache fill exceeded the first-minute budget")
	}
	if quota.NativeDue(quotaPaths(st), time.Now()) {
		t.Fatal("provider floor/budget lost after first read")
	}
	second := poll()
	found := false
	for _, account := range second.Accounts {
		if account.Source == "claude-code" && account.Via == "native" {
			for _, window := range account.Windows {
				if window.UsedPercent != nil && *window.UsedPercent == 42 {
					found = true
				}
			}
		}
	}
	if !found || nativeStarts != 1 || len(requests) != 2 {
		t.Fatal("next poll lost reading or refreshed a not-due reader", second.Accounts, nativeStarts, requests)
	}
	// A delayed child rechecks due state and stays silent even without --quiet.
	code, out, stderr = consentRun([]string{"connections", "refresh", "--scheduled"}, "")
	if code != 0 || out != "" || stderr != "" || len(requests) != 2 {
		t.Fatal("scheduled worker bypassed due/budget or quiet policy", code, out, stderr, requests)
	}
}

func TestNativeRefreshOfflineReadOnlyAndNotDueStartNothing(t *testing.T) {
	for _, args := range [][]string{{"desktop", "--json", "--offline"}, {"desktop", "--json", "--read-only"}, {"desktop", "--json", "--read-only", "--offline"}, {"connections", "refresh", "--scheduled", "--offline"}} {
		t.Run(strings.Join(args, " "), func(t *testing.T) {
			nativeRefreshHome(t)
			grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude", "codex"}, nil, nil))
			if code, out, stderr := consentRun(args, ""); code != 0 || stderr != "" {
				t.Fatal(code, out, stderr)
			}
		})
	}
	t.Run("provider reservation without a capture", func(t *testing.T) {
		nativeRefreshHome(t)
		grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
		st, _ := store.Locate()
		file := filepath.Join(st.Dir, "observed", "reader-attempts", "claude.json")
		if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
			t.Fatal(err)
		}
		b, _ := json.Marshal(map[string]any{"schemaVersion": 1, "nextAttemptAt": time.Now().Add(5 * time.Minute)})
		if err := os.WriteFile(file, b, 0600); err != nil {
			t.Fatal(err)
		}
		refreshNativeLater(st)
	})
}

func TestOtherOnlineBackgroundPathsScheduleNativeAndOfflinePathsDoNot(t *testing.T) {
	for _, args := range [][]string{{"quota", "--json"}, {"advise", "--json"}, {"advise", "--hook", "claude-code"}, {"advise", "--hook", "codex"}} {
		for _, offline := range []bool{false, true} {
			t.Run(fmt.Sprint(args, offline), func(t *testing.T) {
				nativeRefreshHome(t)
				grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
				starts := 0
				startNativeDetached = func(string, ...string) error { starts++; return nil }
				startDetached = func(...string) error {
					if offline {
						t.Fatal("offline path started a child")
					}
					return nil
				}
				argv := append([]string{}, args...)
				if offline {
					argv = append(argv, "--offline")
				}
				code, _, stderr := consentRun(argv, `{"session_id":"synthetic-thread"}`)
				want := 1
				if offline {
					want = 0
				}
				if code != 0 || starts != want {
					t.Fatal(code, starts, want, stderr)
				}
			})
		}
	}
}

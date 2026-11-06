// SPDX-License-Identifier: MIT
package appserver

// Built with go test -c; this fixture is never part of the CLI.
import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

type r03Control struct {
	Sequence int `json:"sequence"`
	Minute   int `json:"minute"`
}
type r03Snapshot struct {
	Sequence int                  `json:"sequence"`
	Minute   int                  `json:"minute"`
	Attempts map[string]int       `json:"attempts"`
	Next     map[string]time.Time `json:"next"`
	Pending  int                  `json:"pending"`
}

func TestR03FixtureProcess(t *testing.T) {
	dir := os.Getenv("MODELPLAN_R03_FIXTURE_DIR")
	if dir == "" {
		t.Skip("test-only stdio fixture")
	}
	if !filepath.IsAbs(dir) {
		t.Fatal("fixture directory must be absolute")
	}
	const codex = consent.ScopeCodexRuntimeUsage
	const kimi = consent.ScopeKimiAccountUsageSavedLogin
	_, paths, _ := refreshFixture(t, codex)
	if err := consent.Change(consent.Path(), func(state *consent.State) error {
		if err := consent.Set(state, "kimi", true, "native:kimi", quota.BackendNative, time.Now()); err != nil {
			return err
		}
		state.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
		state.Scopes[codex] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		state.Scopes[kimi] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	backend, err := NewSharedBackend(SharedConfig{
		Paths: paths,
		Detect: func() detect.Report {
			return detect.Report{Tools: []detect.Tool{
				{Entry: detect.Entry{ProviderID: "codex", ReaderID: "codex", Preferred: "native"}, Detected: true, Status: "detected"},
				{Entry: detect.Entry{ProviderID: "kimi", ReaderID: "kimi", Preferred: "native"}, Detected: true, Status: "detected"},
			}}
		},
		Cleanup: func(string, bool) error { return nil },
	})
	if err != nil {
		t.Fatal(err)
	}
	start := time.Now().UTC().Truncate(time.Second)
	clock := &syntheticRefreshClock{now: start}
	var mu sync.Mutex
	attempts := map[string]int{codex: 0, kimi: 0}
	plan := func(_ quota.Paths, scope string, now time.Time) (quota.ScopeRefreshPlan, error) {
		mu.Lock()
		n := attempts[scope]
		mu.Unlock()
		at := start
		if n > 0 {
			if scope == codex {
				at = start.Add(5 * time.Minute)
			} else {
				at = start.Add(time.Duration(n) * 10 * time.Minute)
			}
		}
		if at.Before(now) {
			at = now
		}
		return quota.ScopeRefreshPlan{At: at, Admitted: true, BudgetKnown: true}, nil
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	scheduler := NewRefreshScheduler(ctx, RefreshConfig{Backend: backend, Paths: paths, Now: clock.read, Plan: plan,
		Run: func(_ context.Context, _ quota.Paths, scope string, _ time.Time) error {
			mu.Lock()
			attempts[scope]++
			n := attempts[scope]
			mu.Unlock()
			if scope == codex && n == 2 {
				return errors.New("synthetic failure")
			}
			return nil
		}})
	defer scheduler.Close()
	done := make(chan struct{})
	go func() {
		defer close(done)
		ticker := time.NewTicker(20 * time.Millisecond)
		defer ticker.Stop()
		current := r03Control{}
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
			}
			if data, err := os.ReadFile(filepath.Join(dir, "control.json")); err == nil {
				var c r03Control
				if json.Unmarshal(data, &c) == nil && c.Sequence > current.Sequence && c.Minute >= current.Minute && c.Minute <= 40 {
					current = c
					clock.set(start.Add(time.Duration(c.Minute) * time.Minute))
					signalAutomatic(scheduler)
				}
			}
			mu.Lock()
			copied := map[string]int{codex: attempts[codex], kimi: attempts[kimi]}
			mu.Unlock()
			scheduler.mu.Lock()
			next := map[string]time.Time{}
			for k, v := range scheduler.autoNext {
				next[k] = v
			}
			pending := len(scheduler.pending)
			scheduler.mu.Unlock()
			data, _ := json.Marshal(r03Snapshot{Sequence: current.Sequence, Minute: current.Minute, Attempts: copied, Next: next, Pending: pending})
			temp := filepath.Join(dir, "snapshot.tmp")
			if os.WriteFile(temp, data, 0600) == nil {
				_ = os.Rename(temp, filepath.Join(dir, "snapshot.json"))
			}
		}
	}()
	server := New(Config{Version: "r03-test", Backend: backend, SessionStarted: scheduler.StartAutomatic, RefreshDecisions: scheduler.Decisions})
	_ = server.Serve(ctx, os.Stdin, os.Stdout)
	cancel()
	<-done
}

func TestR03FixtureStdio(t *testing.T) {
	if os.Getenv("MODELPLAN_R03_FIXTURE_DIR") != "" {
		t.Skip("child")
	}
	dir := t.TempDir()
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	cmd := exec.Command(exe, "-test.run=^TestR03FixtureProcess$")
	cmd.Env = append(os.Environ(), "MODELPLAN_R03_FIXTURE_DIR="+dir)
	in, err := cmd.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	out, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		t.Fatal(err)
	}
	if err = cmd.Start(); err != nil {
		t.Fatal(err)
	}
	go io.Copy(io.Discard, stderr)
	defer func() { _ = in.Close(); _ = cmd.Wait() }()
	_, err = fmt.Fprintln(in, `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"sessionId":"r03-test","protocolVersion":"1.0","appVersion":"test","capabilities":["rows","diagnostics"]}}`)
	if err != nil {
		t.Fatal(err)
	}
	replies := make(chan string, 1)
	go func() {
		scanner := bufio.NewScanner(out)
		for scanner.Scan() {
			var m map[string]json.RawMessage
			if json.Unmarshal(scanner.Bytes(), &m) == nil && string(m["id"]) == "1" {
				replies <- string(scanner.Bytes())
				return
			}
		}
		close(replies)
	}()
	select {
	case response := <-replies:
		if response == "" {
			t.Fatal("stdio closed before initialize")
		}
		var m map[string]json.RawMessage
		_ = json.Unmarshal([]byte(response), &m)
		if m["result"] == nil {
			t.Fatalf("initialize: %s", response)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("initialize timed out")
	}
	wait := func(seq, codex, kimi int, codexAfter time.Time) r03Snapshot {
		t.Helper()
		deadline := time.Now().Add(5 * time.Second)
		for time.Now().Before(deadline) {
			var s r03Snapshot
			b, e := os.ReadFile(filepath.Join(dir, "snapshot.json"))
			if e == nil && json.Unmarshal(b, &s) == nil && s.Sequence == seq && s.Attempts[consent.ScopeCodexRuntimeUsage] == codex && s.Attempts[consent.ScopeKimiAccountUsageSavedLogin] == kimi && !s.Next["kimi"].IsZero() && s.Next["codex"].After(codexAfter) {
				return s
			}
			time.Sleep(10 * time.Millisecond)
		}
		data, _ := os.ReadFile(filepath.Join(dir, "snapshot.json"))
		t.Fatalf("snapshot seq=%d codex=%d kimi=%d timed out: %s", seq, codex, kimi, data)
		return r03Snapshot{}
	}
	advance := func(seq, minute int) {
		t.Helper()
		b, _ := json.Marshal(r03Control{Sequence: seq, Minute: minute})
		if err := os.WriteFile(filepath.Join(dir, "control.json"), b, 0600); err != nil {
			t.Fatal(err)
		}
	}
	initial := wait(0, 1, 1, time.Time{})
	advance(1, 5)
	failed := wait(1, 2, 1, initial.Next["codex"])
	if failed.Next["codex"].Sub(initial.Next["codex"]) < 25*time.Minute {
		t.Fatalf("failure backoff not extended: before=%v after=%v", initial.Next, failed.Next)
	}
	advance(2, 10)
	wait(2, 2, 2, initial.Next["codex"])
}

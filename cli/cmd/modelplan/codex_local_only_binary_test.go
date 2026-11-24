// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func TestCodexLocalOnlyAdmissionRealBinary(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	if out, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, out)
	}
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "cache"))
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	now := time.Now().UTC().Truncate(time.Second)
	log := filepath.Join(home, ".codex", "sessions", "2026", "11", "05", "rollout-synthetic.jsonl")
	if err := os.MkdirAll(filepath.Dir(log), 0700); err != nil {
		t.Fatal(err)
	}
	line, err := json.Marshal(map[string]any{"timestamp": now.Add(-time.Hour), "type": "event_msg", "payload": map[string]any{"type": "token_count", "rate_limits": map[string]any{"limit_id": "codex", "plan_type": "plus", "primary": map[string]any{"used_percent": 80, "window_minutes": 10080, "resets_at": now.Add(24 * time.Hour).Unix()}}}})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(log, append(line, '\n'), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := changeConsentWhenFree(func(s *consent.State) error {
		if err := consent.Set(s, "codex", true, "native:codex", "native", now); err != nil {
			return err
		}
		s.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		s.Scopes[consent.ScopeCodexRuntimeUsage] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	// Read-only prevents scheduler writes or automatic refresh from waking the
	// subscription; only the already-admitted local observation changes.
	p := startQueryBinaryCapsArgs(t, binary, []string{"rows", "windowSourcesV1"}, "--read-only")
	response := p.call("rows/subscribe", map[string]any{})
	var snapshot wire.Envelope[wire.RowsSnapshot]
	if err := json.Unmarshal(response["result"], &snapshot); err != nil {
		t.Fatalf("subscribe: %s %v", response["error"], err)
	}
	found := false
	for _, row := range snapshot.Data.Projection.Rows {
		if row.ID != "codex" {
			continue
		}
		if row.State == rows.StateOff || row.Reason.Code == rows.CodePrivacyBlocked {
			t.Fatalf("local grant incorrectly blocked: state=%s reason=%s response=%s", row.State, row.Reason.Code, response["result"])
		}
		for _, a := range row.Accounts {
			if a.Route == "runtime_rpc" {
				t.Fatal("denied runtime account exposed")
			}
			if a.Route == "local_log" {
				for _, w := range a.Windows {
					if w.RemainingPercent != nil && *w.RemainingPercent == 20 {
						found = true
					}
				}
			}
		}
	}
	if !found {
		t.Fatalf("permitted local window missing: %s", response["result"])
	}
	// Allow the background watcher to establish its initial metadata sample.
	// No RPC is sent after the append; the deadline is a deadlock watchdog.
	time.Sleep(2 * time.Second)
	newLine, err := json.Marshal(map[string]any{"timestamp": time.Now().UTC(), "type": "event_msg", "payload": map[string]any{"type": "token_count", "rate_limits": map[string]any{"limit_id": "codex", "plan_type": "plus", "primary": map[string]any{"used_percent": 30, "window_minutes": 10080, "resets_at": now.Add(24 * time.Hour).Unix()}}}})
	if err != nil {
		t.Fatal(err)
	}
	f, err := os.OpenFile(log, os.O_WRONLY|os.O_APPEND, 0)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.Write(append(newLine, '\n')); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	deadline := time.After(6 * time.Second)
	updated := false
	for !updated {
		select {
		case raw := <-p.frames:
			var msg map[string]json.RawMessage
			if json.Unmarshal(raw, &msg) != nil || string(msg["method"]) != `"rows/changed"` {
				continue
			}
			var change wire.Envelope[wire.RowsSnapshot]
			if err := json.Unmarshal(msg["params"], &change); err != nil {
				t.Fatal(err)
			}
			for _, row := range change.Data.Projection.Rows {
				if row.ID != "codex" {
					continue
				}
				for _, account := range row.Accounts {
					if account.Route != "local_log" {
						continue
					}
					for _, window := range account.Windows {
						if window.RemainingPercent != nil && *window.RemainingPercent == 70 {
							updated = true
						}
					}
				}
			}
		case <-deadline:
			t.Fatal("local rollout append did not publish the updated window")
		}
	}
	assertNoCodexValues := func(client *queryBinary, label string) {
		t.Helper()
		response, open := client.callUnlessEnded("rows/subscribe", map[string]any{})
		if !open {
			// A consent change that lands while a private frame is being written ends the
			// session cleanly (the frame lost its fence; outbound.go). The host reconnects;
			// the denial must hold on the new session too.
			client = startQueryBinaryCapsArgs(t, binary, []string{"rows", "windowSourcesV1"}, "--read-only")
			response = client.call("rows/subscribe", map[string]any{})
		}
		var snapshot wire.Envelope[wire.RowsSnapshot]
		if err := json.Unmarshal(response["result"], &snapshot); err != nil {
			t.Fatalf("%s subscribe: %s %v", label, response["error"], err)
		}
		for _, row := range snapshot.Data.Projection.Rows {
			if row.ID == "codex" && len(row.Accounts) != 0 {
				t.Fatalf("%s exposed Codex accounts: %+v", label, row.Accounts)
			}
		}
	}
	if err := changeConsentWhenFree(func(s *consent.State) error {
		record := s.Scopes[consent.ScopeCodexLocalHistory]
		record.Allowed = false
		s.Scopes[consent.ScopeCodexLocalHistory] = record
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	assertNoCodexValues(p, "local denial")
	if err := changeConsentWhenFree(func(s *consent.State) error {
		record := s.Scopes[consent.ScopeCodexLocalHistory]
		record.Allowed = true
		s.Scopes[consent.ScopeCodexLocalHistory] = record
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if err := changeConsentWhenFree(func(s *consent.State) error {
		record := s.Tools["codex"]
		record.Allowed = false
		s.Tools["codex"] = record
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	assertNoCodexValues(p, "tool denial")
	if err := changeConsentWhenFree(func(s *consent.State) error {
		record := s.Tools["codex"]
		record.Allowed = true
		s.Tools["codex"] = record
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_READERS", "off")
	off := startQueryBinaryCaps(t, binary, []string{"rows"})
	assertNoCodexValues(off, "global readers off")
}

// changeConsentWhenFree retries while the running app server holds the consent lock for a read.
func changeConsentWhenFree(change func(*consent.State) error) error {
	deadline := time.Now().Add(5 * time.Second)
	for {
		err := consent.Change(consent.Path(), change)
		if err == nil || err.Error() != "consent busy; retry" || time.Now().After(deadline) {
			return err
		}
		time.Sleep(20 * time.Millisecond)
	}
}

// callUnlessEnded is call, except that a session the server ended cleanly (exit 0, nothing on
// stderr) before answering reports false instead of failing the test.
func (p *queryBinary) callUnlessEnded(method string, params any) (map[string]json.RawMessage, bool) {
	p.t.Helper()
	p.id++
	body, err := json.Marshal(map[string]any{"jsonrpc": "2.0", "id": p.id, "method": method, "params": params})
	if err != nil {
		p.t.Fatal(err)
	}
	if _, err := p.in.Write(append(body, '\n')); err != nil {
		return nil, p.endedCleanly()
	}
	timer := time.NewTimer(5 * time.Second)
	defer timer.Stop()
	for {
		select {
		case raw, ok := <-p.frames:
			if !ok {
				return nil, p.endedCleanly()
			}
			var msg map[string]json.RawMessage
			if json.Unmarshal(raw, &msg) != nil {
				p.t.Fatal("invalid server frame")
			}
			var id int
			if json.Unmarshal(msg["id"], &id) == nil && id == p.id {
				return msg, true
			}
			p.notifications = append(p.notifications, raw)
		case <-timer.C:
			p.t.Fatalf("timed out waiting for %s", method)
		}
	}
}

// endedCleanly waits for the server to exit and fails the test unless it exited with status 0.
// It returns false (the session is over); the exit stays available to the cleanup.
func (p *queryBinary) endedCleanly() bool {
	p.t.Helper()
	select {
	case err := <-p.done:
		p.done <- err
		if err != nil {
			p.t.Fatalf("app-server exited: %v", err)
		}
	case <-time.After(5 * time.Second):
		p.t.Fatal("app-server stdout closed but the process kept running")
	}
	return false
}

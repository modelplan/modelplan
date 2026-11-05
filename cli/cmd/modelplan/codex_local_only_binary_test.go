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
	line, err := json.Marshal(map[string]any{"timestamp": now, "type": "event_msg", "payload": map[string]any{"type": "token_count", "rate_limits": map[string]any{"limit_id": "codex", "plan_type": "plus", "primary": map[string]any{"used_percent": 80, "window_minutes": 10080, "resets_at": now.Add(24 * time.Hour).Unix()}}}})
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(log, append(line, '\n'), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		if err := consent.Set(s, "codex", true, "native:codex", "native", now); err != nil {
			return err
		}
		s.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		s.Scopes[consent.ScopeCodexRuntimeUsage] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	p := startQueryBinaryCaps(t, binary, []string{"rows", "windowSourcesV1"})
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
	assertNoCodexValues := func(client *queryBinary, label string) {
		t.Helper()
		response := client.call("rows/subscribe", map[string]any{})
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
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		record := s.Scopes[consent.ScopeCodexLocalHistory]
		record.Allowed = false
		s.Scopes[consent.ScopeCodexLocalHistory] = record
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	assertNoCodexValues(p, "local denial")
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		record := s.Scopes[consent.ScopeCodexLocalHistory]
		record.Allowed = true
		s.Scopes[consent.ScopeCodexLocalHistory] = record
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		record := s.Tools["codex"]
		record.Allowed = false
		s.Tools["codex"] = record
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	assertNoCodexValues(p, "tool denial")
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
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

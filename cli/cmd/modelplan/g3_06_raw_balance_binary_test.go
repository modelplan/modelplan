// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// V-07: the public CLI JSON retains the source's balance; display rounding is separate.
func TestV07RealCLIQuotaRetainsRawSyntheticBalance(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	if out, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, out)
	}
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "cache"))
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	path := filepath.Join(home, ".codex", "sessions", "2026", "11", "05", "rollout-v07.jsonl")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	for _, balance := range []float64{3, 3.5, 3.456, 0.004, 1234567.891} {
		now := time.Now().UTC()
		fixture := map[string]any{"timestamp": now, "type": "event_msg", "payload": map[string]any{"type": "token_count", "rate_limits": map[string]any{
			"limit_id": "codex", "plan_type": "plus", "primary": map[string]any{"used_percent": 30, "window_minutes": 300, "resets_at": now.Add(time.Hour).Unix()},
			"credits": map[string]any{"has_credits": true, "unlimited": false, "balance": balance},
		}}}
		b, err := json.Marshal(fixture)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, append(b, '\n'), 0600); err != nil {
			t.Fatal(err)
		}
		cmd := exec.Command(binary, "quota", "--offline", "--json")
		out, err := cmd.Output()
		if err != nil {
			t.Fatalf("quota: %v", err)
		}
		var report quota.Report
		if err := json.Unmarshal(out, &report); err != nil {
			t.Fatal(err)
		}
		found := false
		for _, account := range report.Accounts {
			if account.Source == "codex" && account.Credits != nil && account.Credits.Balance != nil {
				found = true
				if *account.Credits.Balance != balance || account.Credits.Unit != "" || account.Credits.Currency != "" {
					t.Fatalf("source %.12g became %+v", balance, account.Credits)
				}
			}
		}
		if !found {
			t.Fatalf("Codex balance %.12g missing: %s", balance, out)
		}
	}
}

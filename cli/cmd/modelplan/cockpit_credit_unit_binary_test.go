// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appcontract"
	"github.com/modelplan/modelplan/cli/internal/consent"
)

// The unit belongs to the selected balance observation and must not be guessed.
func TestCockpitCreditUnitsRealBinary(t *testing.T) {
	home := setupQueryHome(t)
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "")
	t.Setenv("MODELPLAN_READERS", "passive")
	if err := os.MkdirAll(filepath.Join(home, ".codex"), 0700); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC().Truncate(time.Second)
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "codex", true, "native:codex", "native", now) }); err != nil {
		t.Fatal(err)
	}
	state, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	observed := filepath.Join(home, "cache", "observed")
	if err := os.MkdirAll(observed, 0700); err != nil {
		t.Fatal(err)
	}
	setUnit := func(unit string) {
		t.Helper()
		snapshot := map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": now, "admission": state.CaptureStamp(consent.ScopeCodexRuntimeUsage), "subscriptionRef": "0123456789abcdef", "usageRead": true, "usageCredits": map[string]any{"balance": 3.5, "unit": unit, "observedAt": now}, "windows": []any{map[string]any{"kind": "weekly", "usedPercent": 25, "windowMinutes": 10080, "resetsAt": now.Add(time.Hour), "observedAt": now}}}
		raw, err := json.Marshal(snapshot)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(observed, "codex-account.json"), raw, 0600); err != nil {
			t.Fatal(err)
		}
	}
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	validator, err := appcontract.NewValidator("../../..")
	if err != nil {
		t.Fatal(err)
	}
	query := func(caps []string) (map[string]any, *queryBinary) {
		t.Helper()
		client := startQueryBinaryCaps(t, binary, caps)
		r := client.call("cockpit/query", map[string]any{})
		encoded, err := json.Marshal(r)
		if err != nil {
			t.Fatal(err)
		}
		if err := validator.Validate("app-server", encoded); err != nil {
			t.Fatalf("wire schema: %v", err)
		}
		var envelope struct {
			Data struct {
				Details struct {
					Subscriptions []struct {
						Ref     string         `json:"subscriptionRef"`
						Credits map[string]any `json:"credits"`
					} `json:"subscriptions"`
				} `json:"details"`
			} `json:"data"`
		}
		if err := json.Unmarshal(r["result"], &envelope); err != nil {
			t.Fatalf("query: %s %s %v", r["result"], r["error"], err)
		}
		for _, s := range envelope.Data.Details.Subscriptions {
			if s.Ref == "0123456789abcdef" {
				return s.Credits, client
			}
		}
		t.Fatal("verified synthetic subscription absent")
		return nil, client
	}
	setUnit("credits")
	old, _ := query([]string{"rows", "cockpit", "cockpitDetailsV1"})
	if _, ok := old["unit"]; ok {
		t.Fatal("legacy received unit field")
	}
	known, client := query([]string{"rows", "cockpit", "cockpitDetailsV1", "cockpitCreditUnitsV1"})
	if !strings.Contains(string(client.initialize["result"]), `"cockpitCreditUnitsV1"`) {
		t.Fatal("unit capability not advertised")
	}
	if known["balance"] != 3.5 || known["unit"] != "credits" {
		t.Fatalf("observed unit lost: %+v", known)
	}
	setUnit("money")
	money, _ := query([]string{"rows", "cockpit", "cockpitDetailsV1", "cockpitCreditUnitsV1"})
	if money["unit"] != "money" || money["balance"] != 3.5 {
		t.Fatalf("money unit lost: %+v", money)
	}
	for _, unit := range []string{"", "synthetic-private-text"} {
		setUnit(unit)
		unknown, _ := query([]string{"rows", "cockpit", "cockpitDetailsV1", "cockpitCreditUnitsV1"})
		if _, ok := unknown["unit"]; ok {
			t.Fatalf("unknown unit leaked or guessed: %+v", unknown)
		}
		if unknown["balance"] != 3.5 {
			t.Fatalf("balance lost: %+v", unknown)
		}
	}
	setUnit("credits")
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		record := s.Scopes[consent.ScopeCodexRuntimeUsage]
		record.Allowed = false
		s.Scopes[consent.ScopeCodexRuntimeUsage] = record
		s.RevokeScope(consent.ScopeCodexRuntimeUsage)
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	revoked := startQueryBinaryCaps(t, binary, []string{"rows", "cockpit", "cockpitDetailsV1", "cockpitCreditUnitsV1"})
	response := revoked.call("cockpit/query", map[string]any{})
	if strings.Contains(string(response["result"]), "3.5") {
		t.Fatalf("revoked balance escaped: %s", response["result"])
	}

}

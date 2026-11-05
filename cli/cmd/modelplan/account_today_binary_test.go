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
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/speed"
)

func TestAccountTodayRowsRealBinary(t *testing.T) {
	home := setupQueryHome(t)
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "")
	t.Setenv("MODELPLAN_READERS", "passive")
	t.Setenv("MODELPLAN_IDENTITY", "")
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
	ref := "0123456789abcdef"
	epoch := &speed.GrantEpoch{StoreEpoch: state.StoreEpoch, RevokedGeneration: state.Revoked[consent.ScopeCodexLocalHistory]}
	observed := filepath.Join(home, "cache", "observed")
	if err := os.MkdirAll(observed, 0700); err != nil {
		t.Fatal(err)
	}
	save := func(name string, value any) {
		t.Helper()
		raw, err := json.Marshal(value)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(observed, name), raw, 0600); err != nil {
			t.Fatal(err)
		}
	}
	save("codex-account.json", map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": now, "admission": state.CaptureStamp(consent.ScopeCodexRuntimeUsage), "subscriptionRef": ref, "windows": []any{map[string]any{"kind": "weekly", "usedPercent": 25, "windowMinutes": 10080, "resetsAt": now.Add(time.Hour), "observedAt": now}}})
	save("perf.json", speed.PerfLedger{SchemaVersion: 1, Since: now.Add(-time.Hour), Rows: []speed.PerfRow{{GrantEpoch: epoch, Day: now.Local().Format("2006-01-02"), Source: "codex", ObservedRequests: 5, ObservedOutputTokens: 12000, EligibleRequests: 5, EligibleOutputTokens: 210, GenMs: 5000}}, Live: []speed.LiveRecord{{GrantEpoch: epoch, Ref: "1111111111111111", Source: "codex", SubscriptionRef: ref, LastAt: now, StartedAt: now.Add(-time.Minute), Running: true}}})
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	query := func(caps []string) (wire.Envelope[wire.RowsSnapshot], map[string]json.RawMessage, *queryBinary) {
		t.Helper()
		c := startQueryBinaryCaps(t, binary, caps)
		response := c.call("rows/subscribe", map[string]any{})
		var env wire.Envelope[wire.RowsSnapshot]
		if err := json.Unmarshal(response["result"], &env); err != nil {
			t.Fatalf("rows response: %s %s %v", response["result"], response["error"], err)
		}
		return env, response, c
	}
	legacy, _, _ := query([]string{"rows"})
	enabled, response, opted := query([]string{"rows", "cockpit", "accountTodayV1"})
	if !strings.Contains(string(opted.initialize["result"]), `"accountTodayV1"`) {
		t.Fatal("server did not advertise accountTodayV1")
	}
	find := func(env wire.Envelope[wire.RowsSnapshot]) *wire.RowsProjection { return &env.Data.Projection }
	for _, row := range find(legacy).Rows {
		for _, account := range row.Accounts {
			if account.Today != nil {
				t.Fatal("legacy received today")
			}
		}
	}
	var found bool
	for _, row := range find(enabled).Rows {
		if row.ID != "codex" {
			continue
		}
		for _, account := range row.Accounts {
			if account.SubscriptionRef == nil || *account.SubscriptionRef != ref {
				continue
			}
			x := account.Today
			if x == nil || x.ObservedOutputTokens == nil || *x.ObservedOutputTokens != 12000 || x.GenerationTps == nil || *x.GenerationTps != 42 || x.RunningSessions == nil || *x.RunningSessions != 1 {
				t.Fatalf("account today: %+v, row=%+v", x, row)
			}
			found = true
		}
	}
	if !found {
		t.Fatalf("bound codex account not found: %+v", enabled.Data.Projection.Rows)
	}
	cockpit := opted.call("cockpit/query", map[string]any{})
	var cockpitEnvelope wire.Envelope[wire.CockpitData]
	if err := json.Unmarshal(cockpit["result"], &cockpitEnvelope); err != nil {
		t.Fatalf("cockpit: %s %s %v", cockpit["result"], cockpit["error"], err)
	}
	found = false
	for _, row := range cockpitEnvelope.Data.Projection.Rows {
		for _, account := range row.Accounts {
			if row.ID == "codex" && account.SubscriptionRef != nil && *account.SubscriptionRef == ref && account.Today != nil && account.Today.RunningSessions != nil && *account.Today.RunningSessions == 1 {
				found = true
			}
		}
	}
	if !found {
		t.Fatal("cockpit projection omitted the negotiated account today")
	}
	validator, err := appcontract.NewValidator("../../..")
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := json.Marshal(response)
	if err := validator.Validate("app-server", raw); err != nil {
		t.Fatalf("schema: %v", err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		record := s.Scopes[consent.ScopeCodexLocalHistory]
		record.Allowed = false
		s.Scopes[consent.ScopeCodexLocalHistory] = record
		s.RevokeScope(consent.ScopeCodexLocalHistory)
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	revoked, _, _ := query([]string{"rows", "accountTodayV1"})
	for _, row := range revoked.Data.Projection.Rows {
		for _, account := range row.Accounts {
			if row.ID == "codex" && account.Today != nil {
				t.Fatalf("revoked local history exposed today: %+v", account.Today)
			}
		}
	}
}

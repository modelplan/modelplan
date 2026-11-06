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
	"github.com/modelplan/modelplan/cli/internal/speed"
)

func TestCockpitTodayUnknownAndObservedZeroRealBinary(t *testing.T) {
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
	ref := "0123456789abcdef"
	epoch := &speed.GrantEpoch{StoreEpoch: state.StoreEpoch, RevokedGeneration: state.Revoked[consent.ScopeCodexLocalHistory]}
	observed := filepath.Join(home, "cache", "observed")
	if err := os.MkdirAll(observed, 0700); err != nil {
		t.Fatal(err)
	}
	write := func(name string, value any) {
		t.Helper()
		raw, err := json.Marshal(value)
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(observed, name), raw, 0600); err != nil {
			t.Fatal(err)
		}
	}
	write("codex-account.json", map[string]any{"schemaVersion": 1, "status": "ok", "observedAt": now, "admission": state.CaptureStamp(consent.ScopeCodexRuntimeUsage), "subscriptionRef": ref, "windows": []any{map[string]any{"kind": "weekly", "usedPercent": 25, "windowMinutes": 10080, "resetsAt": now.Add(time.Hour), "observedAt": now}}})
	ledger := speed.PerfLedger{SchemaVersion: 1, Since: now.Add(-time.Hour), Rows: []speed.PerfRow{{GrantEpoch: epoch, Day: now.Local().Format("2006-01-02"), Source: "codex"}}}
	write("perf.json", ledger)
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, raw)
	}
	query := func(caps []string) wire.Envelope[wire.CockpitData] {
		t.Helper()
		c := startQueryBinaryCaps(t, binary, caps)
		response := c.call("cockpit/query", map[string]any{})
		var result wire.Envelope[wire.CockpitData]
		if err := json.Unmarshal(response["result"], &result); err != nil {
			t.Fatalf("query: %s %s %v", response["result"], response["error"], err)
		}
		return result
	}
	legacy := query([]string{"rows", "cockpit"})
	if legacy.Data.Details != nil {
		t.Fatal("unnegotiated client received details")
	}
	find := func(data wire.Envelope[wire.CockpitData]) []wire.CockpitToday {
		t.Helper()
		if data.Data.Details == nil {
			t.Fatal("negotiated details missing")
		}
		for _, sub := range data.Data.Details.Subscriptions {
			if sub.SubscriptionRef == ref {
				return sub.Today
			}
		}
		t.Fatal("verified account missing")
		return nil
	}
	if today := find(query([]string{"rows", "cockpit", "cockpitDetailsV1"})); len(today) != 0 {
		t.Fatalf("unobserved zero emitted: %+v", today)
	}
	ledger.Rows[0].ObservedRequests = 1
	write("perf.json", ledger)
	today := find(query([]string{"rows", "cockpit", "cockpitDetailsV1"}))
	if len(today) != 1 || today[0].ObservedOutputTokens != 0 || today[0].GenerationTps != nil {
		t.Fatalf("observed zero must remain known, rate unknown: %+v", today)
	}
}

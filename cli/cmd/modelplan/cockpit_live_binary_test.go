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
	"github.com/modelplan/modelplan/cli/internal/speed"
)

// S15/S16: the normal server must not equate absent session facts with zero,
// and strict older clients must keep the original details shape.
func TestCockpitLiveSessionExtensionRealBinary(t *testing.T) {
	home := setupQueryHome(t)
	t.Setenv("MODELPLAN_READERS", "passive")
	now := time.Now().UTC().Truncate(time.Second)
	if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "codex", true, "native:codex", "native", now) }); err != nil {
		t.Fatal(err)
	}
	state, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	epoch := &speed.GrantEpoch{StoreEpoch: state.StoreEpoch, RevokedGeneration: state.Revoked[consent.ScopeCodexLocalHistory]}
	ledger := speed.PerfLedger{SchemaVersion: 1, Since: now.Add(-time.Hour), Live: []speed.LiveRecord{
		{GrantEpoch: epoch, Ref: "1111111111111111", Source: "codex", Model: "synthetic", Effort: "high", Speed: "priority", StartedAt: now.Add(-time.Minute), LastAt: now.Add(-time.Second), Running: true},
		{GrantEpoch: epoch, Ref: "2222222222222222", Source: "codex", Model: "synthetic", Effort: "private-unknown", Speed: "private-unknown", StartedAt: now.Add(time.Hour), LastAt: now.Add(-2 * time.Second)},
	}}
	path := speed.PerfPath(filepath.Join(home, "cache"))
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	raw, err := json.Marshal(ledger)
	if err != nil {
		t.Fatal(err)
	}
	if err = os.WriteFile(path, raw, 0600); err != nil {
		t.Fatal(err)
	}
	binary := filepath.Join(t.TempDir(), "modelplan")
	if out, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v %s", err, out)
	}
	validator, err := appcontract.NewValidator("../../..")
	if err != nil {
		t.Fatal(err)
	}
	query := func(caps []string) (map[string]any, *queryBinary) {
		t.Helper()
		c := startQueryBinaryCaps(t, binary, caps)
		r := c.call("cockpit/query", map[string]any{})
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
					Sessions []map[string]any `json:"sessions"`
				} `json:"details"`
			} `json:"data"`
		}
		if err := json.Unmarshal(r["result"], &envelope); err != nil {
			t.Fatalf("query: %s %s %v", r["result"], r["error"], err)
		}
		byRef := map[string]any{}
		for _, s := range envelope.Data.Details.Sessions {
			if ref, ok := s["sessionRef"].(string); ok {
				byRef[ref] = s
			}
		}
		return byRef, c
	}
	old, _ := query([]string{"rows", "cockpit", "cockpitDetailsV1"})
	oldData, ok := old["1111111111111111"].(map[string]any)
	if !ok {
		t.Fatal("legacy session missing")
	}
	for _, key := range []string{"startedAt", "observedSince", "effortStatus", "speedMode"} {
		if _, ok := oldData[key]; ok {
			t.Fatalf("legacy received %s", key)
		}
	}
	got, client := query([]string{"rows", "cockpit", "cockpitDetailsV1", "cockpitLiveSessionV1"})
	if !strings.Contains(string(client.initialize["result"]), `"cockpitLiveSessionV1"`) {
		t.Fatal("capability not advertised")
	}
	first, ok := got["1111111111111111"].(map[string]any)
	if !ok {
		t.Fatal("admitted session missing")
	}
	if _, ok := first["startedAt"]; ok {
		t.Fatal("bounded tail observation falsely presented as a session start")
	}
	if first["observedSince"] != now.Add(-time.Minute).Format(time.RFC3339) || first["effortStatus"] != "reported" || first["speedMode"] != "priority" {
		t.Fatalf("reported facts missing: %+v", first)
	}
	second, ok := got["2222222222222222"].(map[string]any)
	if !ok {
		t.Fatal("second session missing")
	}
	for _, key := range []string{"startedAt", "observedSince", "effortStatus", "speedMode"} {
		if _, ok := second[key]; ok {
			t.Fatalf("unknown %s escaped: %+v", key, second)
		}
	}
	if first["subscriptionRef"] != nil || second["subscriptionRef"] != nil {
		t.Fatal("unverified session binding was inferred")
	}
	t.Setenv("MODELPLAN_HISTORY", "off")
	off, _ := query([]string{"rows", "cockpit", "cockpitDetailsV1", "cockpitLiveSessionV1"})
	if len(off) != 0 {
		t.Fatalf("recording-off sessions escaped: %+v", off)
	}
	t.Setenv("MODELPLAN_HISTORY", "")
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		record := s.Scopes[consent.ScopeCodexLocalHistory]
		record.Allowed = false
		s.Scopes[consent.ScopeCodexLocalHistory] = record
		s.RevokeScope(consent.ScopeCodexLocalHistory)
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	revoked, _ := query([]string{"rows", "cockpit", "cockpitDetailsV1", "cockpitLiveSessionV1"})
	if len(revoked) != 0 {
		t.Fatalf("revoked sessions escaped: %+v", revoked)
	}
}

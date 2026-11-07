// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"

	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// The history projection is separately negotiated: an old client's cockpit/query payload must
// stay byte-compatible, a client that names cockpitHistoryV1 sees the versioned section.
func TestAppServerCockpitHistoryCapabilityNegotiation(t *testing.T) {
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	cache := filepath.Join(home, "cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	t.Setenv("MODELPLAN_READERS", "")
	// A fresh profile has no consent store, and cockpit/query refuses without one.
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	fixture, err := os.ReadFile(filepath.Join("testdata", "cockpit-history", "perf.json"))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(cache, "observed"), 0o700); err != nil {
		t.Fatal(err)
	}
	// The fixture's grant epoch cannot match the fresh store, so rows stay withheld; the
	// negotiation shape, not the figures, is what this test pins down.
	if err := os.WriteFile(filepath.Join(cache, "observed", "perf.json"), fixture, 0o600); err != nil {
		t.Fatal(err)
	}
	binary := filepath.Join(t.TempDir(), "modelplan")
	if raw, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, raw)
	}
	plain := startQueryBinaryCaps(t, binary, []string{"rows", "cockpit"})
	var handshake struct {
		Data struct {
			Capabilities []string `json:"capabilities"`
		} `json:"data"`
	}
	if err := json.Unmarshal(plain.initialize["result"], &handshake); err != nil {
		t.Fatal(err)
	}
	if !containsCapability(handshake.Data.Capabilities, "cockpitHistoryV1") {
		t.Fatalf("server did not advertise cockpitHistoryV1: %v", handshake.Data.Capabilities)
	}
	response := plain.call("cockpit/query", map[string]any{})
	if strings.Contains(string(response["result"]), `"history"`) {
		t.Fatal("client without cockpitHistoryV1 received the history section")
	}
	negotiated := startQueryBinaryCaps(t, binary, []string{"rows", "cockpit", "cockpitHistoryV1"})
	response = negotiated.call("cockpit/query", map[string]any{})
	var env struct {
		Data struct {
			History struct {
				Version       int      `json:"version"`
				Coverage      string   `json:"coverage"`
				Sources       []string `json:"sources"`
				Subscriptions []struct {
					SubscriptionRef string `json:"subscriptionRef"`
				} `json:"subscriptions"`
			} `json:"history"`
		} `json:"data"`
	}
	if err := json.Unmarshal(response["result"], &env); err != nil {
		t.Fatalf("cockpit result: %v %s", err, response["error"])
	}
	if env.Data.History.Version != 1 || len(env.Data.History.Subscriptions) != 0 {
		t.Fatalf("history section: %+v", env.Data.History)
	}
	if env.Data.History.Coverage != "local-history" && env.Data.History.Coverage != "unavailable" {
		t.Fatalf("coverage: %+v", env.Data.History)
	}
}

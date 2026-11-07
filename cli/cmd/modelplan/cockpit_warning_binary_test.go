// SPDX-License-Identifier: MIT
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func TestCockpitWarningBandRealBinary(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	if out, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, out)
	}
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	cache := filepath.Join(home, "cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	t.Setenv("MODELPLAN_IDENTITY", "")
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "")
	codex := filepath.Join(t.TempDir(), "codex")
	script := fmt.Sprintf(`#!/bin/sh
while IFS= read -r line; do
 case "$line" in
  *'"id":1,'*) echo '{"id":1,"result":{"userAgent":"test"}}' ;;
  *'"method":"account/rateLimits/read"'*) echo '{"id":2,"result":{"rateLimits":{"planType":"plus","secondary":{"usedPercent":50,"windowDurationMins":10080,"resetsAt":%d}}}}' ;;
  *'"method":"account/read"'*) echo '{"id":3,"result":{"account":{"type":"chatgpt","email":"synthetic@example.invalid"}}}' ;;
 esac
done
`, time.Now().Add(24*time.Hour).Unix())
	if err := os.WriteFile(codex, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_CODEX", codex)
	t.Setenv("PATH", filepath.Dir(codex)+string(os.PathListSeparator)+os.Getenv("PATH"))
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		if err := consent.Set(s, "codex", true, "native:codex", "native", time.Now()); err != nil {
			return err
		}
		s.Scopes[consent.ScopeCodexRuntimeUsage] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if err := quota.RefreshCodexAccount(context.Background(), cache, codex, time.Now()); err != nil {
		t.Fatal(err)
	}
	client := startQueryBinaryCaps(t, binary, []string{"rows", "cockpit", "cockpitDetailsV1"})
	for _, params := range []map[string]any{{}, {"redBelow": 10}} {
		response := client.call("cockpit/query", params)
		var result wire.Envelope[wire.CockpitData]
		if err := json.Unmarshal(response["result"], &result); err != nil {
			t.Fatalf("query %v: %s (%v)", params, response["error"], err)
		}
		if result.Data.Details == nil || len(result.Data.Details.Alerts) != 1 || result.Data.Details.Alerts[0].Severity != "warning" || result.Data.Details.Alerts[0].RemainingPercent != 50 {
			t.Fatalf("query %v: expected 50%% warning, got %+v", params, result.Data.Details)
		}
	}
}

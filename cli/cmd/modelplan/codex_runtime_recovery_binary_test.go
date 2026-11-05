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
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

// A fresh runtime response can recover the same verified account, without
// attributing an unbound local history observation to that account.
func TestCodexRuntimeRecoversSameAccountRealBinary(t *testing.T) {
	binary := filepath.Join(t.TempDir(), "modelplan")
	if out, err := exec.Command("go", "build", "-o", binary, ".").CombinedOutput(); err != nil {
		t.Fatalf("build: %v: %s", err, out)
	}
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	cache := filepath.Join(home, "cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "")
	t.Setenv("MODELPLAN_CODEXBAR", "off")
	t.Setenv("MODELPLAN_IDENTITY", "")
	codex := filepath.Join(t.TempDir(), "codex")
	payload := filepath.Join(t.TempDir(), "response.json")
	script := fmt.Sprintf(`#!/bin/sh
[ "$1" = app-server ] || exit 2
while IFS= read -r line; do
 case "$line" in
  *'"id":1,'*) echo '{"id":1,"result":{"userAgent":"test"}}' ;;
  *'"method":"account/rateLimits/read"'*) printf '{"id":2,"result":%%s}\n' "$(cat %q)" ;;
  *'"method":"account/read"'*) echo '{"id":3,"result":{"account":{"type":"chatgpt","email":"synthetic@example.invalid"}}}' ;;
 esac
done
`, payload)
	if err := os.WriteFile(codex, []byte(script), 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("MODELPLAN_CODEX", codex)
	setResponse := func(used int) {
		t.Helper()
		b, err := json.Marshal(map[string]any{"rateLimits": map[string]any{"planType": "plus", "secondary": map[string]any{"usedPercent": used, "windowDurationMins": 10080, "resetsAt": time.Now().Add(24 * time.Hour).Unix()}}})
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(payload, b, 0600); err != nil {
			t.Fatal(err)
		}
	}
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
	old := time.Now().UTC().Truncate(time.Second).Add(-3 * time.Hour)
	setResponse(80)
	if err := quota.RefreshCodexAccount(context.Background(), cache, codex, old); err != nil {
		t.Fatalf("seed runtime: %v", err)
	}
	setResponse(30)
	unlock, err := consent.ReaderLock()
	if err != nil {
		t.Fatal(err)
	}
	defer func() {
		if unlock != nil {
			unlock()
		}
	}()
	p := startQueryBinaryCaps(t, binary, []string{"rows", "windowSourcesV1"})
	first := p.call("rows/subscribe", map[string]any{})
	var initial wire.Envelope[wire.RowsSnapshot]
	if err := json.Unmarshal(first["result"], &initial); err != nil {
		t.Fatal(err)
	}
	var ref string
	for _, row := range initial.Data.Projection.Rows {
		if row.ID == "codex" {
			for _, a := range row.Accounts {
				if a.Route == "runtime_rpc" && a.SubscriptionRef != nil && a.ObservedAt != nil && a.ObservedAt.Equal(old) && a.ValueState == rows.ValueStateRetained {
					ref = *a.SubscriptionRef
				}
			}
		}
	}
	if ref == "" {
		t.Fatal("missing retained verified runtime account")
	}
	unlock()
	unlock = nil
	timeout := time.After(8 * time.Second)
	for {
		select {
		case raw := <-p.frames:
			var m map[string]json.RawMessage
			if json.Unmarshal(raw, &m) != nil || string(m["method"]) != `"rows/changed"` {
				continue
			}
			var update wire.Envelope[wire.RowsSnapshot]
			if err := json.Unmarshal(m["params"], &update); err != nil {
				t.Fatal(err)
			}
			for _, row := range update.Data.Projection.Rows {
				if row.ID == "codex" {
					for _, a := range row.Accounts {
						if a.Route != "runtime_rpc" || a.SubscriptionRef == nil || *a.SubscriptionRef != ref || a.ObservedAt == nil || !a.ObservedAt.After(old) || a.ValueState != rows.ValueStateCurrent {
							continue
						}
						for _, w := range a.Windows {
							if w.RemainingPercent != nil && *w.RemainingPercent == 70 && w.ObservedAt != nil && w.ObservedAt.After(old) && w.Source != nil && *w.Source == rows.WindowSourceRuntime {
								if row.State != rows.StateFresh {
									t.Fatalf("fresh runtime window has row state %q and reason %q", row.State, row.Reason.Code)
								}
								return
							}
						}
					}
				}
			}
		case <-timeout:
			t.Fatal("same runtime account did not receive its fresh observed weekly value")
		}
	}
}

// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/connections"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestDesktopPublicationFenceAfterReaderReport(t *testing.T) {
	for _, changes := range []int{1, 2} {
		t.Run(map[int]string{1: "revoke-after-read", 2: "two-changes"}[changes], func(t *testing.T) {
			home := consentAPIHome(t)
			now := time.Now().UTC()
			// Use a fixed future reset in the actual status-line recorder, which owns
			// the cache consumed by ReadPermitted. No hand-built provider cache.
			input := map[string]any{"session_id": "synthetic", "rate_limits": map[string]any{"five_hour": map[string]any{"used_percentage": 30, "resets_at": now.Add(time.Hour).Unix()}}}
			encoded, _ := json.Marshal(input)
			line := string(encoded)
			if code := run([]string{"statusline", "--record-only", "--offline"}, strings.NewReader(line), io.Discard, io.Discard); code != 0 {
				t.Fatal(code)
			}
			if err := os.MkdirAll(filepath.Join(home, ".config", "modelplan"), 0700); err != nil {
				t.Fatal(err)
			}
			if err := os.WriteFile(filepath.Join(home, ".config", "modelplan", "local.json"), []byte(`{"schemaVersion":1,"plans":[{"planId":"my-declared-plan"}]}`), 0600); err != nil {
				t.Fatal(err)
			}
			if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "claude", true, "native:claude", "native", now) }); err != nil {
				t.Fatal(err)
			}
			st, err := store.Open()
			if err != nil {
				t.Fatal(err)
			}
			type built struct {
				snapshot snapshot.Snapshot
				input    rows.Input
			}
			attempts := 0
			var output bytes.Buffer
			result := consent.BuildStable(func(a consent.Admission) built {
				attempts++
				paths := quota.ProductionPathsWithAdmission(st.Dir, "1.0.0", a)
				report := quota.ReadPermitted(paths, now)
				if attempts == 1 {
					found := false
					for _, account := range report.Accounts {
						found = found || account.Source == "claude-code"
					}
					if !found {
						t.Fatal("test did not exercise an admitted reader value", report)
					}
				}
				env := connections.Local(paths)
				original := env.Exists
				changed := false
				env.Exists = func(path string) bool {
					if !changed && attempts <= changes {
						changed = true
						if err := consent.Change(consent.Path(), func(s *consent.State) error { return consent.Set(s, "claude", false, "", "", now) }); err != nil {
							t.Fatal(err)
						}
					}
					return original(path)
				}
				complete := snapshot.Build(snapshot.Input{Report: report, Connections: connections.DiagnoseWithAdmission(env, report, a), Now: now, CLIVersion: "1.0.0"})
				if output.Len() != 0 {
					t.Fatal("discarded attempt was printed")
				}
				return built{complete, a.RowsInput(now)}
			}, func(a consent.Admission) built {
				report := quota.ReadDeclared(quota.Paths{LocalFile: filepath.Join(home, ".config", "modelplan", "local.json")}, now)
				in := a.ChangedRowsInput(now)
				for _, account := range report.Accounts {
					in.DeclaredPlanIDs = append(in.DeclaredPlanIDs, account.Plan)
				}
				return built{snapshot.Build(snapshot.Input{Report: report, Now: now, CLIVersion: "1.0.0"}), in}
			})
			if attempts != 2 || result.input.ConsentGeneration != uint64(changes+1) || result.input.ConsentChanged != (changes == 2) {
				t.Fatal(attempts, result.input)
			}
			for _, account := range result.snapshot.Accounts {
				if account.Source != "user" {
					t.Fatal("revoked tool account escaped", account)
				}
			}
			if changes == 2 && (len(result.input.DeclaredPlanIDs) != 1 || result.input.DeclaredPlanIDs[0] != "my-declared-plan" || len(result.snapshot.Connections) != 0) {
				t.Fatal("fail-closed declaration lost or tool diagnostics survived", result)
			}
			if code := printJSON(&output, result.snapshot); code != 0 {
				t.Fatal(code)
			}
			var wire snapshot.Snapshot
			if err := json.Unmarshal(output.Bytes(), &wire); err != nil {
				t.Fatal("publication is not one JSON document", err)
			}
			if len(wire.Accounts) != 1 || wire.Accounts[0].Source != "user" {
				t.Fatal("discarded account appeared in output", output.String())
			}
		})
	}
}

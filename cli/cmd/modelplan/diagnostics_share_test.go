// SPDX-License-Identifier: MIT
package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestDiagnosticsShareWholeOutputIsCopySafe(t *testing.T) {
	home := consentAPIHome(t)
	cache := filepath.Join(home, "SYNTHETIC-PRIVATE-PATH", "cache")
	t.Setenv("MODELPLAN_CACHE", cache)
	for _, name := range []string{"MODELPLAN_READERS", "MODELPLAN_HISTORY", "MODELPLAN_NATIVE", "MODELPLAN_CODEX_ACCOUNT"} {
		t.Setenv(name, "")
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		for _, tool := range []string{"codex", "kiro"} {
			if err := consent.Set(s, tool, true, "native:"+tool, "native", time.Now()); err != nil {
				return err
			}
		}
		return consent.Set(s, "gemini", false, "native:gemini", "native", time.Now())
	}); err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC().Format(time.RFC3339)
	canaries := []string{"SYNTHETIC-PRIVATE-PATH", "sk-SYNTHETIC-TOKEN-762ed", "Authorization: Bearer SYNTHETIC-BEARER-f943", "person.synthetic@example.invalid", "acct_SYNTHETIC_451ce", "/Users/synthetic/credentials.json", "arbitrary vendor prose"}
	poison := strings.Join(canaries, " | ")
	entries := map[string]any{"schemaVersion": 1, "providers": []any{
		map[string]any{"provider": "kiro", "status": "error", "errorCode": "http_403", "observedAt": now, "error": poison, "accountId": poison},
		map[string]any{"provider": "kiro", "status": "error", "errorCode": poison, "observedAt": now, "email": poison},
		map[string]any{"provider": poison, "status": "error", "errorCode": "network", "observedAt": now},
	}}
	data, err := json.Marshal(entries)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(cache, "observed"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(cache, "observed", "native.json"), data, 0600); err != nil {
		t.Fatal(err)
	}
	before := tree(t, home)
	code, out, stderr := consentRun([]string{"diagnostics", "--share", "--app-version", poison, "--base", poison}, "")
	if code != 0 || stderr != "" || !json.Valid([]byte(out)) {
		t.Fatalf("diagnostics failed: exit=%d stderr=%q", code, stderr)
	}
	for _, secret := range canaries {
		if strings.Contains(out, secret) || strings.Contains(stderr, secret) {
			t.Error("share output contained a synthetic secret")
		}
	}
	var report struct {
		AppVersion, CLIVersion, OSVersion string
		EnabledScopes, RecentErrors       []string
	}
	if err := json.Unmarshal([]byte(out), &report); err != nil {
		t.Fatal(err)
	}
	if report.AppVersion != "unknown" || report.CLIVersion == "" || report.OSVersion == "" {
		t.Fatal("version fields are missing or unsafe")
	}
	if !strings.Contains(strings.Join(report.EnabledScopes, ","), "kiro.runtime_usage") || strings.Contains(strings.Join(report.EnabledScopes, ","), "gemini.account_usage.saved_login") {
		t.Fatal("reader scopes do not reflect consent")
	}
	if !strings.Contains(strings.Join(report.RecentErrors, ","), "http_403") || !strings.Contains(strings.Join(report.RecentErrors, ","), "other") {
		t.Fatal("recent fixed error codes missing")
	}
	if !reflect.DeepEqual(before, tree(t, home)) {
		t.Fatal("share report modified user files")
	}
}

func TestDiagnosticsShareRequiresExplicitFlag(t *testing.T) {
	consentFixtureHome(t)
	for _, args := range [][]string{{"diagnostics"}, {"diagnostics", "--share", "unexpected"}} {
		code, _, _ := consentRun(args, "")
		if code != exitUsage {
			t.Fatalf("usage not enforced for %v", args)
		}
	}
}

// SPDX-License-Identifier: MIT
package connections

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
	"github.com/modelplan/modelplan/cli/internal/toolcli"
)

func claudeConnection(t *testing.T, env Env, report quota.Report) Connection {
	t.Helper()
	for _, c := range Diagnose(env, report) {
		if c.ID == "claude-code" {
			return c
		}
	}
	t.Fatal("missing Claude connection")
	return Connection{}
}
func TestNativeClaudeConsentKeychainAndAdmission(t *testing.T) {
	testenv.IsolateHome(t)
	home := os.Getenv("HOME")
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "")
	if err := os.MkdirAll(filepath.Join(home, ".claude"), 0700); err != nil {
		t.Fatal(err)
	}
	set := func(choice string, allowed bool) {
		t.Helper()
		if err := consent.Change(consent.Path(), func(s *consent.State) error {
			s.Tools["claude"] = consent.Record{Allowed: allowed, ConsentTextVersion: consent.TextVersion, Backend: "native", ReaderID: "native:claude", Keychain: choice}
			return nil
		}); err != nil {
			t.Fatal(err)
		}
	}
	check := func(platform string, report quota.Report) Connection {
		t.Helper()
		paths := quota.ProductionPaths(filepath.Join(home, "cache"), "1.0.0")
		env := Local(paths)
		env.GOOS = platform
		return claudeConnection(t, env, report)
	}
	set("unset", true)
	c := check("darwin", quota.Report{})
	if c.Authorization.Status != "yes" || c.Authorization.Via != "native:claude" || c.Keychain != "unset" || c.Authorization.Reason != "keychain_choice_needed" || c.Authorization.NextStep != consent.ClaudeKeychainNextStep || c.Admitted == nil || c.Admitted.Status != "yes" || c.Quota.Reason != "keychain_choice_needed" {
		t.Fatalf("unset=%+v", c)
	}
	if c := check("linux", quota.Report{}); c.Authorization.Reason != "" || c.Quota.NextStep != "" {
		t.Fatalf("non-Mac Keychain remedy=%+v", c)
	}
	set("allowed", true)
	report := quota.Report{Sources: []quota.SourceStatus{{Source: "native:claude", Status: "auth_expired"}}}
	c = check("darwin", report)
	if c.Keychain != "allowed" || c.Authorization.Status != "yes" || c.Quota.Reason != "auth_expired" || c.Quota.Status != "no" {
		t.Fatalf("failed read=%+v", c)
	}
	report.Sources[0].Status = "ok"
	at := time.Now().UTC()
	report.Accounts = []quota.Account{{Source: "claude-code", Via: "native", ObservedAt: at, Windows: []quota.Window{{Kind: "weekly"}}}}
	c = check("darwin", report)
	if c.Quota.Status != "yes" || c.Quota.At == nil || !c.Quota.At.Equal(at) {
		t.Fatalf("reading=%+v", c)
	}
	report.Sources[0].Status = "auth_expired"
	if c := check("darwin", report); c.Quota.Status != "no" || c.Quota.Reason != "auth_expired" {
		t.Fatalf("retained old reading hid the failed read=%+v", c)
	}
	// A status-line account is history, not evidence the native reader succeeded.
	report.Accounts[0].Via = ""
	if c := check("darwin", report); c.Quota.Status != "no" {
		t.Fatalf("status line claimed native reading=%+v", c)
	}
	set("denied", true)
	c = check("darwin", quota.Report{})
	if c.Keychain != "denied" || c.Quota.Reason != "keychain_denied" || c.Quota.NextStep == "" {
		t.Fatalf("deny=%+v", c)
	}
	set("allowed", false)
	c = check("darwin", report)
	if c.Authorization.Status != "off" || c.Admitted.Status != "no" || c.Quota.Status == "yes" {
		t.Fatalf("revoked=%+v", c)
	}
	set("allowed", true)
	t.Setenv("MODELPLAN_READERS", "passive")
	c = check("darwin", report)
	if c.Authorization.Status != "off" || c.Admitted.Status != "no" || c.Authorization.Reason != "privacy_blocked" {
		t.Fatalf("passive=%+v", c)
	}
	t.Setenv("MODELPLAN_READERS", "")
	t.Setenv("MODELPLAN_NATIVE", "off")
	c = check("darwin", report)
	if c.Authorization.Status != "off" || c.Admitted.Status != "no" {
		t.Fatalf("native off=%+v", c)
	}
}

func TestCodexRuntimeMissingConnectionHasNextStep(t *testing.T) {
	testenv.IsolateHome(t)
	r := quota.Report{Sources: []quota.SourceStatus{{Source: "codex-account", Status: toolcli.RuntimeMissing, Reason: toolcli.RuntimeNextStep}}}
	for _, c := range Diagnose(Env{}, r) {
		if c.ID == "codex" {
			if c.Quota.Reason != toolcli.RuntimeMissing || !strings.Contains(c.Quota.NextStep, "Node.js") {
				t.Fatal(c)
			}
			return
		}
	}
	t.Fatal("Codex missing")
}

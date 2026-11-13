// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/connections"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/contracttest"
)

func TestDesktopNativeClaudeConnectionAfterJSONGrant(t *testing.T) {
	home := consentAPIHome(t)
	t.Setenv("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
	t.Setenv("MODELPLAN_HISTORY", "off")
	// Presence only: this must never be parsed or emitted by desktop cache reads.
	canary := "SYNTHETIC CREDENTIAL MUST NOT BE READ OR OUTPUT"
	if err := os.WriteFile(filepath.Join(home, ".claude", ".credentials.json"), []byte(canary), 0600); err != nil {
		t.Fatal(err)
	}
	grantConsentAPI(t, apiRequest(t, 1, 0, []string{"claude"}, nil, nil))
	read := func() connections.Connection {
		t.Helper()
		var out, stderr bytes.Buffer
		if code := run([]string{"desktop", "--json", "--offline"}, nil, &out, &stderr); code != 0 {
			t.Fatal(code, stderr.String())
		}
		if err := contracttest.ValidateOutput("desktop", out.Bytes()); err != nil {
			t.Fatal(err)
		}
		if strings.Contains(out.String(), canary) {
			t.Fatal("desktop exposed credential")
		}
		var got struct {
			Connections []connections.Connection `json:"connections"`
		}
		if err := json.Unmarshal(out.Bytes(), &got); err != nil {
			t.Fatal(err)
		}
		for _, c := range got.Connections {
			if c.ID == "claude-code" {
				return c
			}
		}
		t.Fatal("Claude connection missing")
		return connections.Connection{}
	}
	for i := 0; i < 2; i++ {
		c := read()
		if c.Authorization.Status != "yes" || c.Authorization.Via != "native:claude" || c.Read != "native:claude" || c.Keychain != "unset" || c.Admitted == nil || c.Admitted.Status != "yes" || c.Quota.Status != "no" {
			t.Fatalf("native grant not reflected=%+v", c)
		}
		if runtime.GOOS == "darwin" {
			if c.Authorization.Reason != "keychain_choice_needed" || c.Authorization.NextStep != consent.ClaudeKeychainNextStep || c.Quota.NextStep != consent.ClaudeKeychainNextStep {
				t.Fatalf("missing Keychain next step=%+v", c)
			}
		} else if c.Authorization.NextStep != "" {
			t.Fatalf("Keychain next step on non-Mac=%+v", c)
		}
	}
	grantConsentAPI(t, apiRequest(t, 2, 1, []string{"claude"}, nil, map[string]string{"claude": "allow"}))
	if c := read(); c.Keychain != "allowed" || c.Authorization.Reason != "" || c.Authorization.NextStep != "" {
		t.Fatalf("allowed choice=%+v", c)
	}
	grantConsentAPI(t, apiRequest(t, 3, 2, nil, []string{"claude"}, nil))
	if c := read(); c.Authorization.Status != "off" || c.Admitted == nil || c.Admitted.Status != "no" || c.Quota.Status != "no" {
		t.Fatalf("revoked=%+v", c)
	}
}

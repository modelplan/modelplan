// SPDX-License-Identifier: MIT
package appserver

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// G3-19 / owner decision D27 (2026-11-06) through the normal entry: the real
// `modelplan app-server` binary on a fresh profile (no consent file, no first-run click)
// with a Claude Code saved login. Claude Code's own login is a standard reader, so the
// automatic refresh reads it without a consent click. The synthetic login has expired,
// so the reader stops at "Open Claude Code to refresh" before any network request; on
// main the route is never admitted and the row keeps asking for consent.
func TestG319FreshProfileReadsClaudeSavedLoginByDefault(t *testing.T) {
	bin := candidateBinary(t, "./cmd/modelplan")
	home := t.TempDir()
	if err := os.MkdirAll(filepath.Join(home, ".claude"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(home, "bin"), 0o700); err != nil {
		t.Fatal(err)
	}
	expired := time.Now().Add(-time.Hour).UnixMilli()
	credential := fmt.Sprintf(`{"claudeAiOauth":{"accessToken":"g319-synthetic-canary","expiresAt":%d,"scopes":["user:inference","user:profile"],"subscriptionType":"max"}}`, expired)
	if err := os.WriteFile(filepath.Join(home, ".claude", ".credentials.json"), []byte(credential), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(home, ".config", "modelplan", "consent.json")); !os.IsNotExist(err) {
		t.Fatal("fixture must start without consent decisions")
	}
	c, stderr := candidateClient(t, bin, home, nil, nil)
	c.initialize(t)
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	m := c.response(t, 2)
	var snapshot wire.Envelope[wire.RowsSnapshot]
	if err := json.Unmarshal(m["result"], &snapshot); err != nil {
		t.Fatalf("rows/subscribe: %s", m["error"])
	}
	deadline := time.Now().Add(20 * time.Second)
	var claude *rows.Row
	for {
		claude = nil
		for i := range snapshot.Data.Projection.Rows {
			if snapshot.Data.Projection.Rows[i].ID == "claude" {
				claude = &snapshot.Data.Projection.Rows[i]
			}
		}
		if claude != nil && savedLoginAttempted(claude) {
			break
		}
		next, ok := nextRowsChanged(t, c, deadline)
		if !ok {
			raw, _ := json.Marshal(claude)
			t.Fatalf("Claude Code's saved login was not read by default on a fresh profile: %s", raw)
		}
		snapshot = next
	}
	if claude.Consent == rows.ConsentDenied {
		t.Fatalf("fresh-profile Claude consent = %s", claude.Consent)
	}
	finishCandidate(t, c)
	if stderr.Len() != 0 {
		t.Fatalf("unexpected protocol stderr: %s", stderr.String())
	}
}

// savedLoginAttempted reports whether the saved-login reader ran: the expired synthetic
// login surfaces as "login expired, open the tool", which only the saved-login reader
// produces. Without the default the row waits for a first reading forever.
func savedLoginAttempted(row *rows.Row) bool {
	if row.State != rows.StateNeedsAction || row.Reason.Code != rows.CodeLoginExpired || row.NextStep == nil || row.NextStep.Action != rows.ActionOpenTool {
		return false
	}
	for _, a := range row.Accounts {
		if a.LastFailure != nil && a.LastFailure.Code == rows.CodeLoginExpired {
			return true
		}
	}
	return false
}

// D41 through the normal entry, on macOS: the real app-server on a fresh profile with a
// Keychain-only Claude Code login shows the Keychain step and never runs a reader.
func TestD41FreshKeychainOnlyClaudeRowAsksForKeychain(t *testing.T) {
	if runtime.GOOS != "darwin" {
		t.Skip("the Keychain step exists only on macOS")
	}
	bin := candidateBinary(t, "./cmd/modelplan")
	home := t.TempDir()
	if err := os.MkdirAll(filepath.Join(home, ".claude"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(home, "bin"), 0o700); err != nil {
		t.Fatal(err)
	}
	c, stderr := candidateClient(t, bin, home, nil, nil)
	c.initialize(t)
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	m := c.response(t, 2)
	var snapshot wire.Envelope[wire.RowsSnapshot]
	if err := json.Unmarshal(m["result"], &snapshot); err != nil {
		t.Fatalf("rows/subscribe: %s", m["error"])
	}
	deadline := time.Now().Add(20 * time.Second)
	for {
		var claude *rows.Row
		for i := range snapshot.Data.Projection.Rows {
			if snapshot.Data.Projection.Rows[i].ID == "claude" {
				claude = &snapshot.Data.Projection.Rows[i]
			}
		}
		if claude != nil && claude.State == rows.StateNeedsKeychain && claude.Reason.Code == rows.CodeKeychainUnset && claude.NextStep != nil && claude.NextStep.Action == rows.ActionOpenSettingsKeychain {
			break
		}
		next, ok := nextRowsChanged(t, c, deadline)
		if !ok {
			raw, _ := json.Marshal(claude)
			t.Fatalf("fresh Keychain-only Claude row did not ask for the Keychain: %s", raw)
		}
		snapshot = next
	}
	if _, err := os.Stat(filepath.Join(home, ".cache", "modelplan", "observed", "readers", "claude.json")); !os.IsNotExist(err) {
		t.Fatalf("a reader ran before Allow: %v", err)
	}
	finishCandidate(t, c)
	if stderr.Len() != 0 {
		t.Fatalf("unexpected protocol stderr: %s", stderr.String())
	}
}

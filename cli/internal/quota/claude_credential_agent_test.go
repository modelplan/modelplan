// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestStandaloneClaudeKeychainRequiresAppIdentity(t *testing.T) {
	p := claudeTestPaths(t)
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	root := filepath.Join(os.Getenv("HOME"), ".claude")
	if err := os.MkdirAll(root, 0700); err != nil {
		t.Fatal(err)
	}
	g := p.ReaderAccess.Grants["claude"]
	g.Profiles = []ReaderProfile{{Root: root}}
	g.Keychain, g.KeychainPriorGrant = true, true
	p.ReaderAccess.Grants["claude"] = g
	old := claudeSecurity
	claudeSecurity = nil
	t.Cleanup(func() { claudeSecurity = old })
	if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	s, err := loadReaderState(p.Cache, "claude")
	if err != nil || len(s.Entries) != 1 {
		t.Fatal("missing recovery state", err)
	}
	e := s.Entries[0]
	if e.NextStep != "Open the app, or use a credentials file" {
		t.Fatalf("standalone lost app recovery: entry=%+v", e)
	}
	if err := KeychainGrantRead(context.Background(), p, "claude", claudeTestNow.Add(time.Minute)); err == nil || err.Error() != claudeAppRequired {
		t.Fatal("standalone grant lost app recovery", err)
	}
}

func TestClaudeCredentialAgentStateCannotExposeCanary(t *testing.T) {
	p := claudeTestPaths(t)
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	root := filepath.Join(os.Getenv("HOME"), ".claude")
	os.MkdirAll(root, 0700)
	g := p.ReaderAccess.Grants["claude"]
	g.Profiles = []ReaderProfile{{Root: root}}
	g.Keychain = true
	const canary = "U7-private-status-canary"
	g.Credential = func(context.Context) ([]byte, string) { return nil, canary }
	p.ReaderAccess.Grants["claude"] = g
	if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	s, err := loadReaderState(p.Cache, "claude")
	if err != nil {
		t.Fatal(err)
	}
	report := ReadPermitted(p, claudeTestNow)
	diag := ReaderDiagnostics(p, claudeTestNow)
	b, _ := json.Marshal([]any{s, report, diag})
	if strings.Contains(string(b), canary) || strings.Contains(fmt.Sprintf("%+v", s), canary) {
		t.Fatal("untrusted credential state escaped")
	}
	filepath.WalkDir(p.Cache, func(path string, d os.DirEntry, err error) error {
		if err == nil && !d.IsDir() {
			b, _ := os.ReadFile(path)
			if strings.Contains(string(b), canary) {
				t.Error("credential canary persisted")
			}
		}
		return err
	})
}

func TestClaudeAppCredentialIsOneUseAndBudgeted(t *testing.T) {
	p := claudeTestPaths(t)
	t.Setenv("CLAUDE_CONFIG_DIR", "")
	root := filepath.Join(os.Getenv("HOME"), ".claude")
	os.MkdirAll(root, 0700)
	g := p.ReaderAccess.Grants["claude"]
	g.Profiles = []ReaderProfile{{Root: root}}
	g.Keychain = true
	p.ReaderAccess.Grants["claude"] = g
	status, paths := 200, []string{}
	claudeTestServer(t, &status, &paths)
	expires := claudeTestNow.Add(365 * 24 * time.Hour)
	bound, release := WithClaudeCredential(p, "ok", "synthetic-access-token", &expires)
	defer release()
	if p.ReaderAccess.Grants["claude"].Credential != nil {
		t.Fatal("mutated original admission")
	}
	if err := RefreshNative(context.Background(), bound, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 2 {
		t.Fatal("one fixed profile/usage reading missing", paths)
	}
	if value, _ := bound.ReaderAccess.Grants["claude"].Credential(context.Background()); len(value) != 0 {
		t.Fatal("credential reusable")
	}
	if err := RefreshNative(context.Background(), bound, claudeTestNow.Add(time.Minute)); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 2 {
		t.Fatal("credential result bypassed budget")
	}
	release()
	assertClaudeCachePrivate(t, p.Cache)
}

func TestClaudeAppCredentialOutcomeAndRelease(t *testing.T) {
	for _, outcome := range []string{"canceled", "denied", "not_found", "interaction_required", "timeout", "error"} {
		t.Run(outcome, func(t *testing.T) {
			p := claudeTestPaths(t)
			t.Setenv("CLAUDE_CONFIG_DIR", "")
			root := filepath.Join(os.Getenv("HOME"), ".claude")
			os.MkdirAll(root, 0700)
			g := p.ReaderAccess.Grants["claude"]
			g.Profiles = []ReaderProfile{{Root: root}}
			g.Keychain = true
			p.ReaderAccess.Grants["claude"] = g
			p, release := WithClaudeCredential(p, outcome, "U7-must-not-use-failed-token", nil)
			defer release()
			out := collectClaudeAccount(context.Background(), nativeClient, readerContext{Paths: p, Grant: p.ReaderAccess.Grants["claude"], Profile: g.Profiles[0], Now: claudeTestNow})
			if out.Entry.Account != nil || out.Entry.CredentialReadState == "" || out.Entry.NextStep == "" {
				t.Fatal("missing recoverable credential outcome", outcome)
			}
			raw, _ := json.Marshal(out)
			if strings.Contains(string(raw), "U7-must-not-use-failed-token") {
				t.Fatal("canary escaped")
			}
			release()
			if b, _ := p.ReaderAccess.Grants["claude"].Credential(context.Background()); len(b) != 0 {
				t.Fatal("released result reused")
			}
		})
	}
}

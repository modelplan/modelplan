package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestClaudeChangedInvalidBindingNeverInheritsAccount(t *testing.T) {
	for _, mode := range []string{"expired-B", "missing-scope-B", "malformed-B", "unsupported-B", "missing-B"} {
		t.Run(mode, func(t *testing.T) {
			p := claudeTestPaths(t)
			status := 200
			paths := []string{}
			claudeTestServer(t, &status, &paths)
			if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
				t.Fatal(err)
			}
			root := p.ReaderAccess.Grants["claude"].Profiles[0].Root
			path := filepath.Join(root, ".credentials.json")
			var err error
			switch mode {
			case "expired-B":
				writeClaudeCredential(t, root, "synthetic-B-access", claudeTestNow.Add(-time.Minute))
			case "missing-scope-B":
				b, _ := json.Marshal(map[string]any{"claudeAiOauth": map[string]any{"accessToken": "synthetic-B-access", "expiresAt": claudeTestNow.Add(time.Hour).UnixMilli(), "scopes": []string{"user:inference"}}})
				err = os.WriteFile(path, b, 0600)
			case "malformed-B":
				err = os.WriteFile(path, []byte(`{"claudeAiOauth":`), 0600)
			case "unsupported-B":
				err = os.WriteFile(path, []byte(`{"mcpOAuth":{"accessToken":"synthetic-B-access"}}`), 0600)
			case "missing-B":
				err = os.Remove(path)
			}
			if err != nil {
				t.Fatal(err)
			}
			if err := RefreshNative(context.Background(), p, claudeTestNow.Add(time.Minute)); err != nil {
				t.Fatal(err)
			}
			if len(paths) != 2 {
				t.Fatal("changed binding bypassed floor")
			}
			if err := RefreshNative(context.Background(), p, claudeTestNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "claude")
			if len(paths) != 2 || s.Entries[0].Account != nil || s.Entries[0].Metadata.CredentialKey != "" {
				t.Fatal("B inherited A or made a request")
			}
			r := Report{}
			applyManaged(&r, p, "claude", claudeTestNow.Add(6*time.Minute))
			if len(r.Accounts) != 0 {
				t.Fatal("A numbers still exposed")
			}
		})
	}
}

func TestClaudeSameGenerationEarlyFailuresRetainCapture(t *testing.T) {
	for _, mode := range []string{"expired", "missing-scope"} {
		t.Run(mode, func(t *testing.T) {
			p := claudeTestPaths(t)
			status := 200
			paths := []string{}
			claudeTestServer(t, &status, &paths)
			if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
				t.Fatal(err)
			}
			root := p.ReaderAccess.Grants["claude"].Profiles[0].Root
			if mode == "expired" {
				writeClaudeCredential(t, root, "synthetic-access-token", claudeTestNow.Add(-time.Minute))
			} else {
				b, _ := json.Marshal(map[string]any{"claudeAiOauth": map[string]any{"accessToken": "synthetic-access-token", "expiresAt": claudeTestNow.Add(time.Hour).UnixMilli(), "scopes": []string{"user:inference"}}})
				if err := os.WriteFile(filepath.Join(root, ".credentials.json"), b, 0600); err != nil {
					t.Fatal(err)
				}
			}
			if err := RefreshNative(context.Background(), p, claudeTestNow.Add(5*time.Minute)); err != nil {
				t.Fatal(err)
			}
			s, _ := loadReaderState(p.Cache, "claude")
			if len(paths) != 2 || s.Entries[0].Account == nil || !s.Entries[0].Account.ObservedAt.Equal(claudeTestNow) || NativeDue(p, claudeTestNow.Add(6*time.Minute)) {
				t.Fatal("same-generation capture age or backoff lost")
			}
		})
	}
}

func TestClaudeForgetReconnectRestartPreservesActualProviderFloor(t *testing.T) {
	p := claudeTestPaths(t)
	status := 200
	paths := []string{}
	claudeTestServer(t, &status, &paths)
	if err := RefreshNative(context.Background(), p, claudeTestNow); err != nil {
		t.Fatal(err)
	}
	if err := ForgetReader(p.Cache, "claude"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(readerPath(p.Cache, "claude")); !os.IsNotExist(err) {
		t.Fatal("personal reading not purged")
	}
	g := p.ReaderAccess.Grants["claude"]
	g.Generation = "reconnected-grant-B"
	p = Paths{Cache: p.Cache, ConnectionsFile: p.ConnectionsFile, ReaderAccess: &ReaderAccess{Grants: map[string]ReaderGrant{"claude": g}}}
	for _, seconds := range []int{60, 299} {
		at := claudeTestNow.Add(time.Duration(seconds) * time.Second)
		if NativeDue(p, at) {
			t.Fatal("Forget/restart reset floor")
		}
		if err := RefreshNative(context.Background(), p, at); err != nil {
			t.Fatal(err)
		}
	}
	if len(paths) != 2 {
		t.Fatal("second read before 300 seconds")
	}
	if err := RefreshNative(context.Background(), p, claudeTestNow.Add(300*time.Second)); err != nil {
		t.Fatal(err)
	}
	if len(paths) != 4 {
		t.Fatal("reservation not released at 300 seconds")
	}
	assertClaudeCachePrivate(t, p.Cache)
}

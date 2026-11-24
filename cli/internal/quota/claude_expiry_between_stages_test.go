// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"
)

// macrevb-1217-1: a Keychain login still valid at intake could expire while the profile stage
// ran, and the usage stage then sent it anyway. Invariant: a credential is never sent after its
// expiry; the read is dropped without any refresh.
func TestClaudeKeychainLoginExpiringBetweenStagesSendsNoUsageRequest(t *testing.T) {
	for name, tc := range map[string]struct {
		lifetime  time.Duration
		wantPaths []string
	}{
		"expires during profile": {time.Minute, []string{"/api/oauth/profile"}},
		"still valid control":    {time.Hour, []string{"/api/oauth/profile", "/api/oauth/usage"}},
	} {
		t.Run(name, func(t *testing.T) {
			var mu sync.Mutex
			now := time.Now()
			old := claudeClock
			claudeClock = func() time.Time { mu.Lock(); defer mu.Unlock(); return now }
			defer func() { claudeClock = old }()
			expires := now.Add(tc.lifetime)
			p := claudeTestPaths(t)
			t.Setenv("CLAUDE_CONFIG_DIR", "")
			root := filepath.Join(os.Getenv("HOME"), ".claude")
			os.MkdirAll(root, 0700)
			g := p.ReaderAccess.Grants["claude"]
			g.Profiles = []ReaderProfile{{Root: root}}
			g.Keychain = true
			p.ReaderAccess.Grants["claude"] = g
			var paths []string
			srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				paths = append(paths, r.URL.Path)
				name := "usage.json"
				if r.URL.Path == "/api/oauth/profile" {
					name = "profile.json"
					// The profile response arrives two minutes later.
					mu.Lock()
					now = now.Add(2 * time.Minute)
					mu.Unlock()
				}
				b, _ := os.ReadFile(filepath.Join("testdata", "claude-account", name))
				_, _ = w.Write(b)
			}))
			defer srv.Close()
			oldClient := nativeClient
			nativeClient = readerFixtureClient(t, srv, "api.anthropic.com")
			defer func() { nativeClient = oldClient }()
			bound, release := WithClaudeCredential(p, "ok", "synthetic-access-token", &expires)
			defer release()
			out := collectClaudeAccount(context.Background(), nativeClient, readerContext{Paths: bound, Grant: bound.ReaderAccess.Grants["claude"], Profile: g.Profiles[0], Now: now})
			if len(paths) != len(tc.wantPaths) {
				t.Fatalf("dispatched %v, want %v", paths, tc.wantPaths)
			}
			for i := range paths {
				if paths[i] != tc.wantPaths[i] {
					t.Fatalf("dispatched %v, want %v", paths, tc.wantPaths)
				}
			}
			if len(tc.wantPaths) == 1 && (out.Entry.Account != nil || out.Entry.Status != "expired") {
				t.Fatalf("expired login produced %q with account %v", out.Entry.Status, out.Entry.Account != nil)
			}
			if len(tc.wantPaths) == 2 && out.Entry.Account == nil {
				t.Fatalf("valid login produced no reading: %+v", out.Entry)
			}
		})
	}
}

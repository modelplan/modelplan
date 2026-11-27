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
			p := claudeTestPaths(t)
			var mu sync.Mutex
			now := time.Now()
			claudeClock = func() time.Time { mu.Lock(); defer mu.Unlock(); return now }
			expires := now.Add(tc.lifetime)
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

// macrevb-1217-1 round 2: the pre-request check measured elapsed time only from when the reader
// started its own clock, so time between intake and the first request was lost. Invariant: every
// check reads the same wall clock; a login that expires between intake and the first request
// sends nothing.
func TestClaudeKeychainLoginExpiringBeforeFirstRequestSendsNothing(t *testing.T) {
	p := claudeTestPaths(t)
	var mu sync.Mutex
	now := time.Now()
	claudeClock = func() time.Time { mu.Lock(); defer mu.Unlock(); return now }
	intake := now
	expires := now.Add(time.Minute)
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
		w.WriteHeader(500)
	}))
	defer srv.Close()
	oldClient := nativeClient
	nativeClient = readerFixtureClient(t, srv, "api.anthropic.com")
	defer func() { nativeClient = oldClient }()
	bound, release := WithClaudeCredential(p, "ok", "synthetic-access-token", &expires)
	defer release()
	// The read was admitted at intake; two minutes pass before the reader runs.
	mu.Lock()
	now = now.Add(2 * time.Minute)
	mu.Unlock()
	out := collectClaudeAccount(context.Background(), nativeClient, readerContext{Paths: bound, Grant: bound.ReaderAccess.Grants["claude"], Profile: g.Profiles[0], Now: intake})
	if len(paths) != 0 {
		t.Fatalf("sent an expired login: %v", paths)
	}
	if out.Entry.Account != nil || out.Entry.Status != "expired" {
		t.Fatalf("expired login produced %q", out.Entry.Status)
	}
}

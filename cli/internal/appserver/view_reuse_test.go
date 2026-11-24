// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// reuseBackend counts the views it builds and says whether the held one is still current.
type reuseBackend struct {
	*memoryBackend
	mu      sync.Mutex
	gets    int
	tokens  int
	current bool
}

func (b *reuseBackend) Get(ctx context.Context) (View, error) {
	b.mu.Lock()
	b.gets++
	b.mu.Unlock()
	return b.memoryBackend.Get(ctx)
}
func (b *reuseBackend) ViewToken() any {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.tokens++
	return b.tokens
}
func (b *reuseBackend) ViewCurrent(token any) bool {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.current && token == b.tokens
}
func (b *reuseBackend) count() int { b.mu.Lock(); defer b.mu.Unlock(); return b.gets }

// WP-17 (Fable perf plan 5.1 row 1): at start the client subscribes and asks for consent, and the
// app does both again: five views in a row from one handshake. While the backend says nothing the
// view depends on has changed, those requests answer from the view the handshake built; any change
// builds a new one. Every reply is still a full snapshot.
func TestStartupRequestsReuseTheHandshakeViewWhileNothingChanged(t *testing.T) {
	backend := &reuseBackend{memoryBackend: newMemoryBackend(), current: true}
	c := startClient(t, Config{Backend: backend})
	c.initialize(t)
	for id, method := range map[int]string{2: "rows/subscribe", 3: "consent/get", 4: "rows/subscribe", 5: "consent/get"} {
		c.send(t, id, method, wire.Empty{})
		if m := c.response(t, id); m["error"] != nil {
			t.Fatalf("%s: %s", method, m["error"])
		}
	}
	if got := backend.count(); got != 1 {
		t.Fatalf("startup built %d views, want 1 (the handshake's)", got)
	}
	backend.mu.Lock()
	backend.current = false // something the view depends on changed
	backend.mu.Unlock()
	c.send(t, 6, "consent/get", wire.Empty{})
	if m := c.response(t, 6); m["error"] != nil {
		t.Fatal(m["error"])
	}
	if got := backend.count(); got != 2 {
		t.Fatalf("a change did not build a new view (%d views)", got)
	}
}

// The shared backend's token: a held view stays current only while no change was notified, the
// consent fence, the watched files (Codex rollouts included) and the detected tools are the same,
// and it is younger than the reuse window.
func TestSharedViewTokenHoldsOnlyWhileNothingChanged(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_READERS", "automatic")
	codex := filepath.Join(home, ".codex")
	path := filepath.Join(codex, "sessions", "2026", "11", "20", "rollout-2026-11-20T10-00-00-0199a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b.jsonl")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("initial\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	allowCodexLocal := func(allowed bool) {
		t.Helper()
		if err := consent.Change(consent.Path(), func(s *consent.State) error {
			if err := consent.Set(s, "codex", true, "native:codex", "native", time.Now()); err != nil {
				return err
			}
			s.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: allowed, ConsentTextVersion: consent.TextVersion}
			return nil
		}); err != nil {
			t.Fatal(err)
		}
	}
	allowCodexLocal(true)
	var detectMu sync.Mutex
	detected := detect.Report{SchemaVersion: 1}
	b, err := NewSharedBackend(SharedConfig{Detect: func() detect.Report { detectMu.Lock(); defer detectMu.Unlock(); return detected }, Paths: func(a consent.Admission) quota.Paths {
		return quota.Paths{CodexHome: codex, Cache: filepath.Join(home, "cache"), Admission: &a}
	}, Cleanup: func(string, bool, consent.EraseGuard) error { return nil }})
	if err != nil {
		t.Fatal(err)
	}
	expect := func(want bool, token any, what string) {
		t.Helper()
		if got := b.ViewCurrent(token); got != want {
			t.Fatalf("%s: current=%v, want %v", what, got, want)
		}
	}
	token := b.ViewToken()
	expect(true, token, "nothing changed")

	f, _ := os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0)
	_, _ = f.WriteString("more\n")
	_ = f.Close()
	expect(false, token, "an admitted Codex rollout grew")

	token = b.ViewToken()
	b.Notify()
	expect(false, token, "a change was notified")

	token = b.ViewToken()
	allowCodexLocal(false)
	expect(false, token, "consent changed (revocation)")

	token = b.ViewToken()
	detectMu.Lock()
	detected = detect.Report{SchemaVersion: 1, CatalogueSource: "publication"}
	detectMu.Unlock()
	expect(false, token, "the detected tools changed")

	token = b.ViewToken()
	expect(true, token, "settled again")
	time.Sleep(viewReuseWindow + 20*time.Millisecond)
	expect(false, token, "older than the reuse window")
}

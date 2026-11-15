// SPDX-License-Identifier: MIT
package appserver

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/detect"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestCodexLocalRolloutAppendSignalsChanges(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_READERS", "automatic")
	codex := filepath.Join(home, ".codex")
	path := filepath.Join(codex, "sessions", "2026", "11", "05", "rollout-synthetic.jsonl")
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte("initial\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := consent.EnsureStore(consent.Path()); err != nil {
		t.Fatal(err)
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		if err := consent.Set(s, "codex", true, "native:codex", "native", time.Now()); err != nil {
			return err
		}
		s.Scopes[consent.ScopeCodexLocalHistory] = consent.Record{Allowed: true, ConsentTextVersion: consent.TextVersion}
		s.Scopes[consent.ScopeCodexRuntimeUsage] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	b, err := NewSharedBackend(SharedConfig{Detect: func() detect.Report { return detect.Report{} }, Paths: func(a consent.Admission) quota.Paths {
		return quota.Paths{CodexHome: codex, Cache: filepath.Join(home, "cache"), Admission: &a}
	}, Cleanup: func(string, bool) error { return nil }})
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	changes := b.Changes(ctx)
	select {
	case <-changes:
	case <-time.After(3 * time.Second):
		t.Fatal("initial observation missing")
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.WriteString("new observation\n"); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	select {
	case <-changes:
	case <-time.After(3 * time.Second):
		t.Fatal("appending the admitted rollout did not signal a change")
	}
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		record := s.Scopes[consent.ScopeCodexLocalHistory]
		record.Allowed = false
		s.Scopes[consent.ScopeCodexLocalHistory] = record
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	select {
	case <-changes:
	case <-time.After(3 * time.Second):
		t.Fatal("consent change not observed")
	}
	f, err = os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.WriteString("after denial\n"); err != nil {
		t.Fatal(err)
	}
	if err := f.Close(); err != nil {
		t.Fatal(err)
	}
	select {
	case <-changes:
		t.Fatal("denied local rollout still signalled a change")
	case <-time.After(1500 * time.Millisecond):
	}
}

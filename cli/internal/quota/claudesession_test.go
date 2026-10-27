package quota

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

var claudeSessionNow = time.Date(2026, 10, 27, 20, 0, 0, 0, time.UTC)

func TestClaudeSessionConfirmedFieldsAndOptionalOlderRows(t *testing.T) {
	isolateHome(t)
	key := bytes.Repeat([]byte{7}, 32)
	b, err := os.ReadFile(filepath.Join("testdata", "claude-sessions", "owner-confirmed.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	turn := parseClaudeSessionTurn(bytes.TrimSpace(b), key, "synthetic-session", claudeSessionNow, claudeSessionNow)
	if turn == nil || turn.Model != "claude-opus-5-5" || turn.Effort != "high" || turn.Fast == nil || *turn.Fast {
		t.Fatal("owner-confirmed fields not read")
	}
	b, err = os.ReadFile(filepath.Join("testdata", "claude-sessions", "older-optional.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	rows := bytes.Split(bytes.TrimSpace(b), []byte{'\n'})
	for i, row := range rows {
		turn = parseClaudeSessionTurn(row, key, "synthetic-session", claudeSessionNow, claudeSessionNow)
		if turn == nil {
			t.Fatal("optional fields rejected")
		}
		switch i {
		case 0:
			if turn.Model != "claude-opus-5-5" || turn.Effort != "" || turn.Fast != nil {
				t.Fatal("missing effort/speed guessed")
			}
		case 1:
			if turn.Model != "" || turn.Effort != "high" || turn.Fast == nil || *turn.Fast {
				t.Fatal("missing model guessed")
			}
		case 2:
			if turn.Model != "" || turn.Effort != "" || turn.Fast != nil {
				t.Fatal("unknown fields inherited")
			}
		}
	}
}

func sessionTestTree(t *testing.T) (string, string, ClaudeSessionAccess) {
	t.Helper()
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "")
	cache := filepath.Join(t.TempDir(), "cache")
	root := filepath.Join(t.TempDir(), "claude")
	project := filepath.Join(root, "projects", "private-project-name")
	if err := os.MkdirAll(project, 0o700); err != nil {
		t.Fatal(err)
	}
	return cache, project, ClaudeSessionAccess{Allowed: true, Root: root}
}

func writeSessionRow(t *testing.T, path, id, model, effort, speed string, at time.Time, appendRow bool, sidechain bool) {
	t.Helper()
	v := map[string]any{"type": "assistant", "timestamp": at.Format(time.RFC3339Nano), "sessionId": id, "isSidechain": sidechain, "effort": effort, "cwd": "/private/private-project-name", "message": map[string]any{"model": model, "content": []any{map[string]any{"type": "text", "text": "SYNTHETIC-MESSAGE-MUST-NOT-PERSIST"}}, "usage": map[string]any{"speed": speed, "service_tier": "not-a-speed-signal", "inference_geo": "not-a-model-signal", "iterations": []any{}}}}
	b, _ := json.Marshal(v)
	b = append(b, '\n')
	flags := os.O_CREATE | os.O_WRONLY | os.O_TRUNC
	if appendRow {
		flags = os.O_CREATE | os.O_WRONLY | os.O_APPEND
	}
	f, err := os.OpenFile(path, flags, 0o600)
	if err != nil {
		t.Fatal(err)
	}
	_, err = f.Write(b)
	closeErr := f.Close()
	if err != nil {
		t.Fatal(err)
	}
	if closeErr != nil {
		t.Fatal(closeErr)
	}
	if err := os.Chtimes(path, at, at); err != nil {
		t.Fatal(err)
	}
}

func TestClaudeSessionsIncrementalNewestInteractiveAndPrivacy(t *testing.T) {
	cache, project, access := sessionTestTree(t)
	first := filepath.Join(project, "synthetic-session-a.jsonl")
	second := filepath.Join(project, "synthetic-session-b.jsonl")
	writeSessionRow(t, first, "synthetic-session-a", "claude-opus-5-5", "high", "standard", claudeSessionNow.Add(-time.Hour), false, false)
	writeSessionRow(t, second, "synthetic-session-b", "claude-sonnet-4-6", "medium", "fast", claudeSessionNow.Add(-time.Minute), false, false)
	subdir := filepath.Join(project, "subagents")
	if err := os.MkdirAll(subdir, 0o700); err != nil {
		t.Fatal(err)
	}
	writeSessionRow(t, filepath.Join(subdir, "agent-private.jsonl"), "synthetic-sidechain", "claude-opus-5-5", "max", "fast", claudeSessionNow, false, true)
	if err := RefreshClaudeSessions(context.Background(), cache, access, claudeSessionNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadClaudeSessions(cache)
	if len(s.Files) != 2 {
		t.Fatal("subagent was discovered")
	}
	r := Report{}
	applyClaudeSessions(&r, cache, "")
	if len(r.Accounts) != 1 || r.Accounts[0].Harness.Model != "claude-sonnet-4-6" || r.Accounts[0].Harness.Attribution != "recent-thread" {
		t.Fatal("newest interactive session not selected")
	}
	before := map[string]int64{}
	for _, cp := range s.Files {
		before[cp.SourceKey] = cp.Offset
	}
	// Poison an already consumed span without changing its length or inode.
	// A full rescan would publish this newer timestamp; an incremental read must
	// preserve the original parsed turn and consume only appended bytes.
	poison, err := os.ReadFile(second)
	if err != nil {
		t.Fatal(err)
	}
	poison = bytes.ReplaceAll(poison, []byte("claude-sonnet-4-6"), []byte("claude-bogusx-4-6"))
	poison = bytes.ReplaceAll(poison, []byte(claudeSessionNow.Add(-time.Minute).Format(time.RFC3339Nano)), []byte(claudeSessionNow.Add(time.Minute).Format(time.RFC3339Nano)))
	if err := os.WriteFile(second, poison, 0o600); err != nil {
		t.Fatal(err)
	}
	// A newer assistant row has unknown fields. It must clear older values rather
	// than inherit or let an optional status-line source fill them in.
	writeSessionRow(t, first, "synthetic-session-a", "", "", "", claudeSessionNow, true, false)
	if err := RefreshClaudeSessions(context.Background(), cache, access, claudeSessionNow); err != nil {
		t.Fatal(err)
	}
	s, _ = loadClaudeSessions(cache)
	advanced := 0
	for _, cp := range s.Files {
		if cp.Offset > before[cp.SourceKey] {
			advanced++
		}
	}
	if advanced != 1 {
		t.Fatal("incremental offsets were rescanned or lost")
	}
	r = Report{Accounts: []Account{{Source: "claude-code", Harness: &Harness{Model: "optional-status-line-model", Effort: "max"}}}}
	applyClaudeSessions(&r, cache, "")
	h := r.Accounts[0].Harness
	if h.Model != "" || h.Effort != "" || h.FastMode != nil || h.Attribution != "recent-thread" || len(h.SessionKey) != 64 {
		t.Fatal("unknown session state overridden")
	}
	r = Report{}
	applyClaudeSessions(&r, cache, "synthetic-session-b")
	if r.Accounts[0].Harness.Attribution != "current-thread" || r.Accounts[0].Harness.Model != "claude-sonnet-4-6" {
		t.Fatal("explicit session not selected")
	}
	// A cache-only projection remains usable after the transcript tree disappears.
	if err := os.RemoveAll(access.Root); err != nil {
		t.Fatal(err)
	}
	b1, _ := os.ReadFile(claudeSessionPath(cache))
	r = Report{}
	applyClaudeSessions(&r, cache, "")
	b2, _ := os.ReadFile(claudeSessionPath(cache))
	if len(r.Accounts) != 1 || !bytes.Equal(b1, b2) {
		t.Fatal("cache projection touched collection")
	}
	assertSessionCachePrivate(t, cache)
}

type claudeFakeFileInfo struct {
	os.FileInfo
	sys any
}

func (f claudeFakeFileInfo) Sys() any { return f.sys }

func TestClaudeSessionFileIdentityDarwinSignedDevice(t *testing.T) {
	// Darwin's device field is signed, unlike Linux's. Both must support cursor
	// replacement detection without persisting the underlying device/inode.
	info := claudeFakeFileInfo{sys: &struct {
		Dev int32
		Ino uint64
	}{Dev: 23, Ino: 42}}
	if claudeSessionFileIdentity(info) != "17:2a" {
		t.Fatal("Darwin file identity unavailable")
	}
}

func TestClaudeSessionTruncationReplacementAndIncompleteLine(t *testing.T) {
	cache, project, access := sessionTestTree(t)
	path := filepath.Join(project, "synthetic-session.jsonl")
	writeSessionRow(t, path, "synthetic-session", "claude-opus-5-5", "high", "standard", claudeSessionNow.Add(-time.Minute), false, false)
	if err := RefreshClaudeSessions(context.Background(), cache, access, claudeSessionNow); err != nil {
		t.Fatal(err)
	}
	// Replace with a larger file on another inode; size alone cannot detect it.
	replacement := filepath.Join(project, "replacement.tmp")
	writeSessionRow(t, replacement, "synthetic-new-session", "claude-sonnet-4-6", "low", "fast", claudeSessionNow, false, false)
	f, err := os.OpenFile(replacement, os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = f.Write([]byte(strings.Repeat(" ", 512) + "\n"))
	_ = f.Close()
	if err := os.Rename(replacement, path); err != nil {
		t.Fatal(err)
	}
	if err := RefreshClaudeSessions(context.Background(), cache, access, claudeSessionNow); err != nil {
		t.Fatal(err)
	}
	r := Report{}
	applyClaudeSessions(&r, cache, "")
	if r.Accounts[0].Harness.Model != "claude-sonnet-4-6" {
		t.Fatal("replacement missed")
	}
	// A truncated incomplete row cannot be published until it gains a newline.
	if err := os.WriteFile(path, []byte(`{"type":"assistant","effort":"high","message":{"model":"claude-opus-5-5"}}`), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chtimes(path, claudeSessionNow, claudeSessionNow); err != nil {
		t.Fatal(err)
	}
	if err := RefreshClaudeSessions(context.Background(), cache, access, claudeSessionNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadClaudeSessions(cache)
	if s.Files[0].Offset != 0 || s.Files[0].Turn != nil {
		t.Fatal("incomplete row consumed")
	}
	f, err = os.OpenFile(path, os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = f.Write([]byte{'\n'})
	_ = f.Close()
	if err := RefreshClaudeSessions(context.Background(), cache, access, claudeSessionNow); err != nil {
		t.Fatal(err)
	}
	s, _ = loadClaudeSessions(cache)
	if s.Files[0].Turn == nil || s.Files[0].Turn.Model != "claude-opus-5-5" {
		t.Fatal("completed row not read")
	}
}

func TestClaudeSessionBoundedTailAndAdmission(t *testing.T) {
	cache, project, access := sessionTestTree(t)
	path := filepath.Join(project, "synthetic-session.jsonl")
	if err := os.WriteFile(path, []byte(strings.Repeat("x", 2*claudeSessionChunk)+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	writeSessionRow(t, path, "synthetic-session", "claude-opus-5-5", "high", "standard", claudeSessionNow, true, false)
	access.Allowed = false
	if RefreshClaudeSessions(context.Background(), cache, access, claudeSessionNow) == nil {
		t.Fatal("no consent accepted")
	}
	if _, err := os.Stat(claudeSessionPath(cache)); !os.IsNotExist(err) {
		t.Fatal("unadmitted read wrote state")
	}
	access.Allowed = true
	t.Setenv("MODELPLAN_READERS", "off")
	if RefreshClaudeSessions(context.Background(), cache, access, claudeSessionNow) == nil {
		t.Fatal("off ignored")
	}
	t.Setenv("MODELPLAN_READERS", "passive")
	if err := RefreshClaudeSessions(context.Background(), cache, access, claudeSessionNow); err != nil {
		t.Fatal(err)
	}
	s, _ := loadClaudeSessions(cache)
	if !s.Partial || len(s.Files) != 1 || s.Files[0].Turn == nil || s.Files[0].Offset < claudeSessionChunk {
		t.Fatal("bounded tail recovery failed")
	}
	assertSessionCachePrivate(t, cache)
}

func assertSessionCachePrivate(t *testing.T, cache string) {
	t.Helper()
	err := filepath.WalkDir(cache, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		for _, private := range []string{"SYNTHETIC-MESSAGE-MUST-NOT-PERSIST", "private-project-name", "synthetic-session", "synthetic-new-session", "synthetic-sidechain", "service_tier", "inference_geo", "iterations"} {
			if strings.Contains(string(b), private) {
				t.Fatal("private transcript field persisted")
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}

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

// largeSession writes a synthetic transcript: a header, padding records the
// projection ignores, and one complete reply. Record times never exceed mtime.
func largeSession(t *testing.T, root, project, session, entrypoint, model string, at time.Time, pad int) string {
	t.Helper()
	path := filepath.Join(root, "projects", project, session+".jsonl")
	header, _ := json.Marshal(map[string]any{"type": "system", "uuid": "root", "parentUuid": nil, "sessionId": session, "timestamp": at.Add(-time.Hour).Format(time.RFC3339Nano), "entrypoint": entrypoint})
	filler, _ := json.Marshal(map[string]any{"type": "file-history-snapshot", "snapshot": strings.Repeat("PRIVATE-CONTENT-CANARY", 64<<10/22)})
	prompt, _ := json.Marshal(map[string]any{"type": "user", "uuid": "raw-prompt", "parentUuid": "root", "sessionId": session, "timestamp": at.Add(-time.Second).Format(time.RFC3339Nano), "entrypoint": entrypoint, "message": map[string]any{"role": "user", "content": "PRIVATE-CONTENT-CANARY"}})
	rows := [][]byte{header}
	for n := 0; n < pad; n += len(filler) + 1 {
		rows = append(rows, filler)
	}
	rows = append(rows, prompt, sessionRow("raw-node-reply", "raw-prompt", session, model, "high", "standard", at, map[string]any{"entrypoint": entrypoint}))
	writeClaudeSession(t, path, rows...)
	if err := os.Chtimes(path, at, at); err != nil {
		t.Fatal(err)
	}
	return path
}

// A heavy user's history (hundreds of transcripts, the active one far over the
// per-file read) yields the newest session on the first pass, within the pass
// budget, and stays incremental afterwards.
func TestClaudeSessionLargeHistoryNewestOnFirstPass(t *testing.T) {
	a := sessionAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	now := claudeSessionNow
	for i := 0; i < 300; i++ {
		pad := 0
		if i%10 == 0 {
			pad = 1 << 20
		}
		largeSession(t, root, fmt.Sprintf("project-%02d", i%12), fmt.Sprintf("session-old-%03d", i), "cli", "claude-sonnet-4-6", now.Add(-time.Duration(i+2)*time.Hour), pad)
	}
	active := largeSession(t, root, "project-active", "session-active", "cli", "claude-opus-5-5", now.Add(-time.Minute), 12<<20)
	r := RefreshClaudeSessions(context.Background(), root, cache, a, now)
	if !r.Complete || r.Availability != "ok" || r.BytesRead > 32<<20 {
		t.Fatalf("first pass: %+v", r)
	}
	selected := sessionSelected(t, cache, a, "", now)
	if selected.Model != "claude-opus-5-5" || selected.Attribution != "recent-thread" || !selected.ObservedAt.Equal(now.Add(-time.Minute)) {
		t.Fatalf("first pass selected %+v", selected)
	}
	reply := sessionRow("raw-node-next", "raw-node-reply", "session-active", "claude-sonnet-4-6", "low", "fast", now.Add(30*time.Second), map[string]any{"entrypoint": "cli"})
	appendClaudeSession(t, active, append(reply, '\n'))
	at := now.Add(time.Minute)
	if err := os.Chtimes(active, at, at); err != nil {
		t.Fatal(err)
	}
	r = RefreshClaudeSessions(context.Background(), root, cache, a, at)
	if !r.Complete || r.BytesRead != int64(len(reply)+1) {
		t.Fatalf("append pass: %+v", r)
	}
	if selected := sessionSelected(t, cache, a, "", at); selected.Model != "claude-sonnet-4-6" || selected.FastMode == nil || !*selected.FastMode {
		t.Fatalf("append selected %+v", selected)
	}
	assertClaudeSessionCachePrivate(t, cache)
}

// When the newest transcripts exceed one pass's budget, the pass reports only
// the most recent session as unknown (the caller's own session is still
// selectable) and later passes converge to a complete reading.
func TestClaudeSessionLargeHistoryConvergesAcrossPasses(t *testing.T) {
	a := sessionAccess(t)
	root, cache := t.TempDir(), t.TempDir()
	now := claudeSessionNow
	// Twenty busy SDK transcripts are newer than the interactive one; their
	// bootstrap tails alone exceed the 32 MiB pass budget.
	for i := 0; i < 20; i++ {
		largeSession(t, root, "project-sdk", fmt.Sprintf("session-sdk-%02d", i), "sdk-cli", "claude-haiku-4-5", now.Add(-time.Duration(i+1)*time.Minute), 3<<20)
	}
	largeSession(t, root, "project-main", "session-main", "cli", "claude-opus-5-5", now.Add(-time.Hour), 64<<10)
	for i := 0; i < 40; i++ {
		largeSession(t, root, "project-old", fmt.Sprintf("session-old-%02d", i), "cli", "claude-sonnet-4-6", now.Add(-time.Duration(i+2)*time.Hour), 0)
	}
	r := RefreshClaudeSessions(context.Background(), root, cache, a, now)
	if r.Complete || r.Availability != "partial" || r.BytesRead > 32<<20 || len(r.Snapshot) == 0 {
		t.Fatalf("first pass: %+v", r)
	}
	if projection, _ := ReadClaudeSessions(cache, a, "", now); projection.Selected != nil {
		t.Fatalf("recency claimed from an unread window: %+v", projection.Selected)
	}
	if own, _ := ReadClaudeSessions(cache, a, "session-sdk-00", now); own.Selected == nil || own.Selected.Attribution != "current-thread" {
		t.Fatalf("caller's own session withheld: %+v", own)
	}
	passes := 1
	for at := now; !r.Complete; passes++ {
		if passes > 4 {
			t.Fatalf("did not converge: %+v", r)
		}
		at = at.Add(time.Minute)
		r = RefreshClaudeSessions(context.Background(), root, cache, a, at)
		if r.BytesRead > 32<<20 {
			t.Fatalf("pass budget exceeded: %+v", r)
		}
	}
	if passes != 2 || r.Availability != "ok" {
		t.Fatalf("converged in %d passes: %+v", passes, r)
	}
	if selected := sessionSelected(t, cache, a, "", now.Add(time.Minute)); selected.Model != "claude-opus-5-5" || selected.Attribution != "recent-thread" {
		t.Fatalf("converged selection %+v", selected)
	}
	assertClaudeSessionCachePrivate(t, cache)
}

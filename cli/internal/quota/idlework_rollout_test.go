// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/idlework"
)

// D397 / G3-147 (macrev2-1219-1): the production rollout reader counts the bytes of both of its
// bounded reads, the session_meta head and the tail, so the idle-work gate sees what a rollout
// costs. A reader that bypasses idlework.Reader would report one open and zero bytes.
func TestRolloutReadCountsHeadAndTailBytes(t *testing.T) {
	dir := t.TempDir()
	meta := `{"timestamp":"2026-11-20T10:00:00Z","type":"session_meta","payload":{"source":"cli"}}` + "\n"
	limits := `{"timestamp":"2026-11-20T10:00:02Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":10,"window_minutes":300,"resets_at":1795000000}}}}` + "\n"

	small := filepath.Join(dir, "rollout-small.jsonl")
	if err := os.WriteFile(small, []byte(meta+limits), 0o600); err != nil {
		t.Fatal(err)
	}
	size := int64(len(meta + limits))
	before := idlework.Snapshot()
	if _, ok := readRolloutEvents(small); !ok {
		t.Fatal("synthetic rollout unreadable")
	}
	got := idlework.Snapshot().Since(before)
	// The head reads the whole short file and the tail reads it again from the start.
	if got.Opens != 1 || got.Decodes != 1 || got.Bytes != 2*size {
		t.Fatalf("short rollout: %+v, want 1 open, 1 decode and %d bytes (head + tail)", got, 2*size)
	}

	// Past the tail bound: the head stops at its first buffer, the tail reads exactly codexTail.
	large := filepath.Join(dir, "rollout-large.jsonl")
	filler := `{"timestamp":"2026-11-20T10:00:01Z","type":"response_item","payload":{"text":"` + strings.Repeat("x", 900) + `"}}` + "\n"
	var b strings.Builder
	b.WriteString(meta)
	for int64(b.Len()) < codexTail+codexTail/4 {
		b.WriteString(filler)
	}
	b.WriteString(limits)
	if err := os.WriteFile(large, []byte(b.String()), 0o600); err != nil {
		t.Fatal(err)
	}
	before = idlework.Snapshot()
	scan, ok := readRolloutEvents(large)
	if !ok || len(scan.events) == 0 {
		t.Fatal("large synthetic rollout lost its tail event")
	}
	got = idlework.Snapshot().Since(before)
	if lo, hi := int64(codexTail+len(meta)), int64(codexTail+64<<10); got.Opens != 1 || got.Bytes < lo || got.Bytes > hi {
		t.Fatalf("large rollout: %+v, want 1 open and %d..%d bytes (bounded head + tail)", got, lo, hi)
	}
}

// SPDX-License-Identifier: MIT
package appserver

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// G3-36 through the normal entry: the real `modelplan app-server` on a fresh profile, with a
// Codex whose first start fails (a cold start on a new install). The reading must arrive by
// itself soon after, not half an hour later, and without any client refresh or cockpit query.
func TestG336FirstCodexReadRecoversSoonAfterAFailedStart(t *testing.T) {
	bin := candidateBinary(t, "./cmd/modelplan")
	runtimeHost := candidateBinary(t, "./internal/appserver/testdata/runtime")
	home := t.TempDir()
	binDir := filepath.Join(home, "bin")
	if err := os.MkdirAll(filepath.Join(home, ".codex"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(binDir, 0o700); err != nil {
		t.Fatal(err)
	}
	marker := filepath.Join(home, "first-start-failed")
	script := fmt.Sprintf("#!/bin/sh\nif [ ! -e %q ]; then : > %q; exit 1; fi\nexec %q \"$@\"\n", marker, marker, runtimeHost)
	if err := os.WriteFile(filepath.Join(binDir, "codex"), []byte(script), 0o700); err != nil {
		t.Fatal(err)
	}
	reset := time.Now().Add(3 * time.Hour)
	trace := filepath.Join(home, "runtime.jsonl")
	c, stderr := candidateClient(t, bin, home, nil, []string{"MODELPLAN_U3B_RUNTIME_CALLS=" + trace, "MODELPLAN_U3B_RUNTIME_RESETS_AT=" + strconv.FormatInt(reset.Unix(), 10), "MODELPLAN_U3B_RUNTIME_PLAN=pro"})
	c.initialize(t)
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	var snapshot wire.Envelope[wire.RowsSnapshot]
	if err := json.Unmarshal(c.response(t, 2)["result"], &snapshot); err != nil {
		t.Fatal(err)
	}
	deadline := time.Now().Add(45 * time.Second)
	for {
		var codex *rows.Row
		for i := range snapshot.Data.Projection.Rows {
			if snapshot.Data.Projection.Rows[i].ID == "codex" {
				codex = &snapshot.Data.Projection.Rows[i]
			}
		}
		if codex != nil && hasRuntimeAccount(codex) {
			break
		}
		next, ok := nextRowsChanged(t, c, deadline)
		if !ok {
			_, failed := os.Stat(marker)
			t.Fatalf("no Codex reading %s after a failed first start (first start ran=%t, runtime reads=%d)", 45*time.Second, failed == nil, runtimeReadCount(t, trace))
		}
		snapshot = next
	}
	finishCandidate(t, c)
	if stderr.Len() != 0 {
		t.Fatalf("unexpected protocol stderr: %s", stderr.String())
	}
}

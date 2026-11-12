// SPDX-License-Identifier: MIT
package appserver

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// G3-21 through the normal entry: the real `modelplan app-server` binary on a fresh profile
// (no consent file, owner decision 2026-11-06) where ZCode is installed only under the
// zcode-app-cli layout (a `zcode-cli` launcher and ~/.local/share/zcode-community). The
// app's rows/subscribe must list ZCode as a row (no ring until it has a reading), not drop it as undetected. No provider
// key is written, so nothing is read or sent; the reading itself is covered in-process by
// TestG321FreshProfileReadsZCodeCodingPlanByDefault.
func TestG321FreshProfileZCodeIsARowThroughAppServer(t *testing.T) {
	bin := candidateBinary(t, "./cmd/modelplan")
	home := t.TempDir()
	binDir := filepath.Join(home, "bin")
	if err := os.MkdirAll(filepath.Join(home, ".local", "share", "zcode-community", "settings"), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(binDir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(binDir, "zcode-cli"), []byte("#!/bin/sh\nexit 0\n"), 0o700); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(home, ".config", "modelplan", "consent.json")); !os.IsNotExist(err) {
		t.Fatal("fixture must start without consent decisions")
	}
	c, stderr := candidateClient(t, bin, home, nil, nil)
	c.initialize(t)
	c.send(t, 2, "rows/subscribe", wire.Empty{})
	m := c.response(t, 2)
	var snapshot wire.Envelope[wire.RowsSnapshot]
	if err := json.Unmarshal(m["result"], &snapshot); err != nil {
		t.Fatalf("rows/subscribe: %s", m["error"])
	}
	var zcode *rows.Row
	for i := range snapshot.Data.Projection.Rows {
		if snapshot.Data.Projection.Rows[i].ID == "zai" {
			zcode = &snapshot.Data.Projection.Rows[i]
		}
	}
	if zcode == nil {
		ids := []string{}
		for _, r := range snapshot.Data.Projection.Rows {
			ids = append(ids, r.ID)
		}
		t.Fatalf("installed ZCode has no row on a fresh profile; rows=%v", ids)
	}
	// G3-38 (D76): no reading yet means no ring, but the row is listed in the menu and Settings.
	menu, dock := false, false
	for _, s := range zcode.Surfaces {
		menu = menu || s == rows.SurfaceMenu
		dock = dock || s == rows.SurfaceDock
	}
	if !menu || dock {
		t.Fatalf("installed ZCode with no reading must be listed without a ring: surfaces=%v consent=%s", zcode.Surfaces, zcode.Consent)
	}
	if zcode.Consent == rows.ConsentDenied {
		t.Fatalf("fresh-profile ZCode consent = %s", zcode.Consent)
	}
	finishCandidate(t, c)
	if stderr.Len() != 0 {
		t.Fatalf("unexpected protocol stderr: %s", stderr.String())
	}
}

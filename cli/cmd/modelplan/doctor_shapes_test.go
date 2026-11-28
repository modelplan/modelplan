// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestDoctorShapesRefusesUnknownToolAndNonEmptyOut(t *testing.T) {
	var o, e bytes.Buffer
	if doctorShapes(&o, &e, "nope", t.TempDir()) != exitUsage {
		t.Fatal("unknown tool accepted")
	}
	dir := t.TempDir()
	_ = os.WriteFile(filepath.Join(dir, "x"), []byte("x"), 0o600)
	if doctorShapes(&o, &e, "codex", dir) != exitUsage || !strings.Contains(e.String(), "empty") {
		t.Fatal("non-empty output accepted")
	}
}

func TestDoctorShapesWritesManifestOnly(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_CACHE", filepath.Join(home, "cache"))
	out := filepath.Join(t.TempDir(), "out")
	var o, e bytes.Buffer
	if rc := doctorShapes(&o, &e, "all", out); rc != 0 {
		t.Fatal(rc, e.String())
	}
	if _, err := os.Stat(filepath.Join(out, "manifest.json")); err != nil {
		t.Fatal(err)
	}
}

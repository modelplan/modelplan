//go:build windows

// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/speed"
	"github.com/modelplan/modelplan/cli/internal/store"
)

func TestWindowsProjectLabelsOffAndHistoryErasure(t *testing.T) {
	home, cache := t.TempDir(), t.TempDir()
	t.Setenv("USERPROFILE", home)
	t.Setenv("HOME", home)
	ledger := speed.PerfLedger{SchemaVersion: 1, Since: time.Now(), Sessions: []speed.PerfSession{{Ref: "synthetic", Source: "codex", ProjectLabel: "private-project"}}}
	b, err := json.Marshal(ledger)
	if err != nil {
		t.Fatal(err)
	}
	path := speed.PerfPath(cache)
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, b, 0600); err != nil {
		t.Fatal(err)
	}
	var out, stderr bytes.Buffer
	if code := projectLabelsCmd([]string{"off"}, &out, &stderr, &store.Store{Dir: cache}, common{json: true}); code != 0 {
		t.Fatalf("project-labels off exit %d: %s", code, &stderr)
	}
	b, err = os.ReadFile(path)
	if err != nil || strings.Contains(string(b), "private-project") || !strings.Contains(string(b), "synthetic") {
		t.Fatalf("label not removed: %s, %v", b, err)
	}
	if err := quota.EraseScope(quota.Paths{Cache: cache}, consent.ScopeCodexLocalHistory, false); err != nil {
		t.Fatal("Windows erase failed", err)
	}
	b, err = os.ReadFile(path)
	if err != nil || strings.Contains(string(b), "synthetic") {
		t.Fatalf("history not erased: %s, %v", b, err)
	}
}

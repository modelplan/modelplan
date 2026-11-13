// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"os/exec"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// The overlay changes only the cleanup hook: the real CLI/parser/transaction
// receives a directory permission failure after its first durable commit.
// Ordinary builds contain no fault flag, environment switch or fixture linkage.
func TestScopedCLIReportsDurableReceiptAfterReadOnlyCleanup(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("POSIX directory permissions required")
	}
	if os.Geteuid() == 0 {
		t.Skip("read-only-directory fault requires an unprivileged user")
	}
	_, source, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(source), "../../.."))
	original := filepath.Join(root, "cli/cmd/modelplan/consent_scopes.go")
	raw, err := os.ReadFile(original)
	if err != nil {
		t.Fatal(err)
	}
	patched := strings.Replace(string(raw), "import (", "import (\n \"os\"\n \"path/filepath\"", 1)
	needle := "return cleanupScope(st, scope, forget)"
	if !strings.Contains(patched, needle) {
		t.Fatal("cleanup hook moved; update fault overlay")
	}
	patched = strings.Replace(patched, needle, "err:=cleanupScope(st,scope,forget);if err!=nil{return err};return os.Chmod(filepath.Dir(consent.Path()),0500)", 1)
	dir := t.TempDir()
	replacement := filepath.Join(dir, "consent_scopes.go")
	if err := os.WriteFile(replacement, []byte(patched), 0600); err != nil {
		t.Fatal(err)
	}
	overlay, _ := json.Marshal(map[string]any{"Replace": map[string]string{original: replacement}})
	overlayFile := filepath.Join(dir, "overlay.json")
	os.WriteFile(overlayFile, overlay, 0600)
	binary := filepath.Join(dir, "modelplan")
	build := exec.Command("go", "build", "-overlay="+overlayFile, "-o", binary, "./cmd/modelplan")
	build.Dir = filepath.Join(root, "cli")
	if out, err := build.CombinedOutput(); err != nil {
		t.Fatal(err, string(out))
	}
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("MODELPLAN_READERS", "off")
	state, err := consent.EnsureStore(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	storeDir := filepath.Dir(consent.Path())
	t.Cleanup(func() { os.Chmod(storeDir, 0700) })
	input, _ := json.Marshal(map[string]any{"requestId": "00000000-0000-4000-8000-000000000999", "expectStoreEpoch": state.StoreEpoch, "expectGeneration": 0, "consentTextVersion": consent.TextVersion, "deny": []string{"retired.old_path"}})
	run := func() ([]byte, error) {
		cmd := exec.Command(binary, "consent", "grant", "--json")
		cmd.Env = append(os.Environ(), "MODELPLAN_CACHE="+filepath.Join(home, "cache"))
		cmd.Stdin = bytes.NewReader(input)
		return cmd.CombinedOutput()
	}
	out, err := run()
	if err == nil {
		t.Fatal("cleanup-pending exit status missing", string(out))
	}
	var got consent.GrantReceipt
	if err := json.Unmarshal(out, &got); err != nil {
		t.Fatal(err, string(out))
	}
	if !got.Committed || got.CommittedGeneration == nil || *got.CommittedGeneration != 1 || got.StoreEpoch != state.StoreEpoch || got.Code != "cleanup_pending" || got.CleanupError == "" {
		t.Fatal("committed outcome hidden", string(out))
	}
	durable, err := consent.Load(consent.Path())
	if err != nil {
		t.Fatal(err)
	}
	var stored consent.GrantReceipt
	if err := json.Unmarshal(durable.Requests[consent.ReceiptKey(state.StoreEpoch, got.RequestID)].Result, &stored); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got, stored) {
		t.Fatal("CLI/durable outcome differs", got, stored)
	}
	replay, _ := run()
	var repeated consent.GrantReceipt
	if err := json.Unmarshal(replay, &repeated); err != nil || !reflect.DeepEqual(repeated, stored) {
		t.Fatal("replay differs", string(replay), err)
	}
}

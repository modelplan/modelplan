//go:build darwin || linux

// SPDX-License-Identifier: MIT
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/advise"
)

func holdAdviceLock(t *testing.T, cache string) *os.File {
	t.Helper()
	dir := filepath.Join(cache, "observed")
	if err := os.MkdirAll(dir, 0700); err != nil {
		t.Fatal(err)
	}
	f, err := os.OpenFile(filepath.Join(dir, "advice.json.lock"), os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		t.Fatal(err)
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		f.Close()
		t.Fatal(err)
	}
	t.Cleanup(func() { f.Close() })
	return f
}

func TestHookAdviceSaveRetriesBusyLock(t *testing.T) {
	h := newQuotaHookTest(t, "claude-code", "en")
	now := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	h.reading("claude-code", now, hookWindow("weekly", 18, now.Add(72*time.Hour)))
	lock := holdAdviceLock(t, h.st.Dir)
	done := make(chan error, 1)
	go func() {
		time.Sleep(1500 * time.Millisecond) // exceeds the first one-second wait
		done <- syscall.Flock(int(lock.Fd()), syscall.LOCK_UN)
	}()
	start := time.Now()
	if got := h.prompt("synthetic-thread", now); !strings.Contains(got, "18% left") {
		t.Fatalf("first notice missing: %q", got)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
	if time.Since(start) < time.Second {
		t.Fatal("fixture did not hold the lock through the first attempt")
	}
	if got := h.prompt("synthetic-thread", now); strings.Contains(got, "18% left") {
		t.Fatalf("notice repeated after successful retry: %q", got)
	}
	if _, err := os.Stat(filepath.Join(h.st.Dir, "observed", "advice-save-error.json")); !os.IsNotExist(err) {
		t.Fatalf("successful retry recorded an error: %v", err)
	}
}

func TestHookAdviceSavePersistentBusyRecordsOnlyCode(t *testing.T) {
	h := newQuotaHookTest(t, "claude-code", "en")
	now := time.Date(2026, 10, 31, 12, 0, 0, 0, time.UTC)
	h.reading("claude-code", now, hookWindow("weekly", 18, now.Add(72*time.Hour)))
	holdAdviceLock(t, h.st.Dir)
	if got := h.prompt("synthetic-thread", now); !strings.Contains(got, "18% left") {
		t.Fatalf("notice missing: %q", got)
	}
	file := filepath.Join(h.st.Dir, "observed", "advice-save-error.json")
	b, err := os.ReadFile(file)
	if err != nil {
		t.Fatal(err)
	}
	var record map[string]string
	if json.Unmarshal(b, &record) != nil || len(record) != 1 || record["code"] != adviceStateBusy {
		t.Fatalf("unexpected error record: %s", b)
	}
	if info, err := os.Stat(file); err != nil || info.Mode().Perm() != 0600 {
		t.Fatalf("error record permissions: %v", err)
	}
}

func TestAdviceSaveOtherFailureRecordsOnlyCode(t *testing.T) {
	cache := t.TempDir()
	if err := os.MkdirAll(filepath.Join(cache, "observed", "advice.json"), 0700); err != nil {
		t.Fatal(err)
	}
	state := advise.Load(cache)
	state.Once("synthetic", time.Now())
	saveAdviceState(state, cache, time.Now())
	b, err := os.ReadFile(filepath.Join(cache, "observed", "advice-save-error.json"))
	if err != nil || string(b) != "{\"code\":\""+adviceStateSaveFailed+"\"}\n" {
		t.Fatalf("wrong fixed failure code: %s %v", b, err)
	}
}

func TestAdviceSaveFailureFallsBackToFixedCode(t *testing.T) {
	cache := filepath.Join(t.TempDir(), "not-a-directory")
	if err := os.WriteFile(cache, nil, 0600); err != nil {
		t.Fatal(err)
	}
	var fallback bytes.Buffer
	reportAdviceSaveError(cache, adviceStateSaveFailed, &fallback)
	if got := fallback.String(); got != adviceStateSaveFailed+"\n" {
		t.Fatalf("fallback exposed non-code details: %q", got)
	}
}

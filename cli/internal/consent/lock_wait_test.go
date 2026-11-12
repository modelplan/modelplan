// SPDX-License-Identifier: MIT
package consent

import (
	"errors"
	"path/filepath"
	"testing"
	"time"
)

// The app-server's observers save small writes under this lock every 30 seconds.
func TestResetWaitsOutABriefHoldAndGivesUpOnALongOne(t *testing.T) {
	file := filepath.Join(t.TempDir(), "consent.json")
	unlock, err := lockFile(file + ".lock")
	if err != nil {
		t.Fatal(err)
	}
	time.AfterFunc(100*time.Millisecond, unlock)
	if _, err := Reset(file); err != nil {
		t.Fatalf("reset during a brief hold: %v", err)
	}
	unlock, err = lockFile(file + ".lock")
	if err != nil {
		t.Fatal(err)
	}
	defer unlock()
	if _, err := Reset(file); !errors.Is(err, ErrBusy) {
		t.Fatalf("reset during a long hold: %v", err)
	}
}

// A revoke made while the app-server commits a local-history read must not fail
// its cleanup because the reader lock is briefly held.
func TestReaderLockWaitOutlastsABriefHoldAndGivesUpOnALongOne(t *testing.T) {
	t.Setenv("HOME", t.TempDir())
	unlock, err := ReaderLock()
	if err != nil {
		t.Fatal(err)
	}
	time.AfterFunc(100*time.Millisecond, unlock)
	release, err := ReaderLockWait()
	if err != nil {
		t.Fatalf("wait during a brief hold: %v", err)
	}
	// The lock is held again, now by the waiter.
	started := time.Now()
	if _, err := ReaderLockWait(); !errors.Is(err, ErrBusy) || time.Since(started) < time.Second {
		t.Fatalf("wait during a long hold: %v after %v", err, time.Since(started))
	}
	release()
}

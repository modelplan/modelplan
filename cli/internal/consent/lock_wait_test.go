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

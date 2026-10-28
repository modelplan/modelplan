//go:build darwin || linux

package detach

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"syscall"
	"testing"
	"time"
)

func TestLockedWorkerHelper(t *testing.T) {
	marker := os.Getenv("MODELPLAN_TEST_LOCKED_WORKER")
	if marker == "" {
		return
	}
	if err := os.WriteFile(marker, []byte(strconv.Itoa(os.Getpid())), 0600); err != nil {
		t.Fatal(err)
	}
	time.Sleep(30 * time.Second) // Parent kills this synthetic worker after checking the inherited lock.
}

func TestStartLockedDoesNotStackChildrenAndKilledWorkerReleasesLock(t *testing.T) {
	root := t.TempDir()
	t.Setenv("HOME", root)
	marker, path := filepath.Join(root, "ready"), filepath.Join(root, "native-refresh.lock")
	t.Setenv("MODELPLAN_TEST_LOCKED_WORKER", marker)
	if err := StartLocked(path, "-test.run=^TestLockedWorkerHelper$"); err != nil {
		t.Fatal(err)
	}
	var child *os.Process
	defer func() {
		if child != nil {
			_ = child.Kill()
			_, _ = child.Wait()
		}
	}()
	deadline := time.Now().Add(5 * time.Second)
	for time.Now().Before(deadline) {
		if b, err := os.ReadFile(marker); err == nil {
			pid, err := strconv.Atoi(string(b))
			if err != nil {
				t.Fatal(err)
			}
			child, err = os.FindProcess(pid)
			if err != nil {
				t.Fatal(err)
			}
			break
		}
		time.Sleep(10 * time.Millisecond)
	}
	if child == nil {
		t.Fatal("detached worker did not start")
	}
	for i := 0; i < 8; i++ {
		if err := StartLocked(path, "-test.run=^TestLockedWorkerHelper$"); err == nil {
			t.Fatal("spawned a second child while the detached worker held the lock")
		}
	}
	if err := child.Kill(); err != nil {
		t.Fatal(err)
	}
	_, _ = child.Wait()
	child = nil
	f, err := os.OpenFile(path, os.O_RDWR, 0600)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		t.Fatal(fmt.Errorf("killed child left scheduling locked: %w", err))
	}
	defer syscall.Flock(int(f.Fd()), syscall.LOCK_UN)
}

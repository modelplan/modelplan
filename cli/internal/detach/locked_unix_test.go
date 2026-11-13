//go:build darwin || linux

package detach

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
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
	KeepLockInWorker()
	exe, err := os.Executable()
	if err != nil {
		t.Fatal(err)
	}
	child := exec.Command(exe, "-test.run=^TestLockedGrandchildHelper$")
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	if err := child.Process.Release(); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(marker, []byte(strconv.Itoa(os.Getpid())), 0600); err != nil {
		t.Fatal(err)
	}
	time.Sleep(30 * time.Second) // Parent kills this synthetic worker after checking the inherited lock.
}

func TestLockedGrandchildHelper(t *testing.T) {
	marker := os.Getenv("MODELPLAN_TEST_LOCKED_GRANDCHILD")
	if marker == "" {
		return
	}
	if err := os.WriteFile(marker, []byte(strconv.Itoa(os.Getpid())), 0600); err != nil {
		t.Fatal(err)
	}
	time.Sleep(30 * time.Second)
}

func TestStartLockedDoesNotStackChildrenAndKilledWorkerReleasesLock(t *testing.T) {
	root := t.TempDir()
	t.Setenv("HOME", root)
	marker, path := filepath.Join(root, "ready"), filepath.Join(root, "native-refresh.lock")
	t.Setenv("MODELPLAN_TEST_LOCKED_WORKER", marker)
	grandchildMarker := filepath.Join(root, "grandchild-ready")
	t.Setenv("MODELPLAN_TEST_LOCKED_GRANDCHILD", grandchildMarker)
	if err := StartLocked(path, "-test.run=^TestLockedWorkerHelper$"); err != nil {
		t.Fatal(err)
	}
	var child *os.Process
	var grandchild *os.Process
	defer func() {
		if child != nil {
			_ = child.Kill()
			_, _ = child.Wait()
		}
		if grandchild != nil {
			_ = grandchild.Kill()
			_, _ = grandchild.Wait()
		}
	}()
	pid, err := waitPIDFile(marker, 5*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	child, err = os.FindProcess(pid)
	if err != nil {
		t.Fatal(err)
	}
	pid, err = waitPIDFile(grandchildMarker, 5*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	grandchild, err = os.FindProcess(pid)
	if err != nil {
		t.Fatal(err)
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
	if err := grandchild.Signal(syscall.Signal(0)); err != nil {
		t.Fatal("provider child did not outlive worker", err)
	}
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

// waitPIDFile is test-only: production retains a flock inode, not a PID file.
func waitPIDFile(path string, timeout time.Duration) (int, error) {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		b, err := os.ReadFile(path)
		if err == nil && len(b) > 0 {
			pid, err := strconv.Atoi(string(b))
			if err != nil {
				return 0, err
			}
			if pid <= 0 {
				return 0, fmt.Errorf("PID publication must be positive")
			}
			return pid, nil
		} else if err != nil && !os.IsNotExist(err) {
			return 0, err
		}
		time.Sleep(time.Millisecond)
	}
	return 0, fmt.Errorf("waiting for PID publication: %w", os.ErrDeadlineExceeded)
}

func TestWaitPIDFileDoesNotConsumeEmptyPublication(t *testing.T) {
	path := filepath.Join(t.TempDir(), "pid")
	// os.WriteFile creates/truncates the path before writing the bytes. Hold
	// exactly that publication window open while the reader starts.
	f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY, 0600)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	type result struct {
		pid int
		err error
	}
	read := make(chan result, 1)
	go func() {
		pid, err := waitPIDFile(path, time.Second)
		read <- result{pid, err}
	}()
	select {
	case r := <-read:
		t.Fatalf("reader consumed an empty publication: pid=%d err=%v", r.pid, r.err)
	case <-time.After(10 * time.Millisecond):
	}
	if _, err := f.WriteString(strconv.Itoa(os.Getpid())); err != nil {
		t.Fatal(err)
	}
	r := <-read
	if r.err != nil || r.pid != os.Getpid() {
		t.Fatalf("completed PID publication: pid=%d err=%v", r.pid, r.err)
	}
}

func TestWaitPIDFileRejectsMissingEmptyAndMalformedPublication(t *testing.T) {
	for _, content := range []string{"missing", "", "not-a-pid", "0", "-1"} {
		t.Run(content, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "pid")
			if content != "missing" {
				if err := os.WriteFile(path, []byte(content), 0600); err != nil {
					t.Fatal(err)
				}
			}
			_, err := waitPIDFile(path, 10*time.Millisecond)
			if err == nil {
				t.Fatal("accepted an unpublished or malformed PID")
			}
			if (content == "missing" || content == "") && !errors.Is(err, os.ErrDeadlineExceeded) {
				t.Fatalf("unpublished PID must wait for the deadline: %v", err)
			}
		})
	}
}

//go:build darwin || linux

package advise

import (
	"errors"
	"os"
	"syscall"
	"time"
)

// lockState serializes Save's read, merge and rename across processes (hooks and status lines
// run side by side). The lock is the open file's, so a killed holder releases it.
func lockState(path string) (func(), error) {
	f, err := os.OpenFile(path+".lock", os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	deadline := time.Now().Add(stateLockWait)
	for {
		if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err == nil {
			return func() { syscall.Flock(int(f.Fd()), syscall.LOCK_UN); f.Close() }, nil
		}
		if time.Now().After(deadline) {
			f.Close()
			return nil, errors.New("advice state busy")
		}
		time.Sleep(10 * time.Millisecond)
	}
}

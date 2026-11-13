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
func lockState(path string, wait time.Duration) (func(), error) {
	f, err := os.OpenFile(path+".lock", os.O_CREATE|os.O_RDWR, 0o600)
	if err != nil {
		return nil, err
	}
	deadline := time.Now().Add(wait)
	for {
		err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
		if err == nil {
			return func() { syscall.Flock(int(f.Fd()), syscall.LOCK_UN); f.Close() }, nil
		}
		if !errors.Is(err, syscall.EWOULDBLOCK) && !errors.Is(err, syscall.EAGAIN) && !errors.Is(err, syscall.EINTR) {
			f.Close()
			return nil, err
		}
		if time.Now().After(deadline) {
			f.Close()
			return nil, ErrStateBusy
		}
		time.Sleep(10 * time.Millisecond)
	}
}

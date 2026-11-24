//go:build darwin || linux

package consent

import (
	"errors"
	"os"
	"syscall"
)

// Kernel locks are released even when the App/hook kills a reader. Keep the
// lock inode in place; unlinking it would let a third process lock a new inode.
func lockFileOS(path string) (func(), error) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, err
	}
	if err = syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		f.Close()
		if errors.Is(err, syscall.EWOULDBLOCK) || errors.Is(err, syscall.EAGAIN) {
			return nil, ErrBusy
		}
		return nil, err
	}
	return func() { syscall.Flock(int(f.Fd()), syscall.LOCK_UN); f.Close() }, nil
}

// lockFileSharedOS takes a shared lock on an existing lock file opened read-only. It never
// creates the file and never conflicts with another shared holder; it waits out only a writer's
// exclusive lock.
func lockFileSharedOS(path string) (func(), error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	if err = syscall.Flock(int(f.Fd()), syscall.LOCK_SH|syscall.LOCK_NB); err != nil {
		f.Close()
		if errors.Is(err, syscall.EWOULDBLOCK) || errors.Is(err, syscall.EAGAIN) {
			return nil, ErrBusy
		}
		return nil, err
	}
	return func() { syscall.Flock(int(f.Fd()), syscall.LOCK_UN); f.Close() }, nil
}

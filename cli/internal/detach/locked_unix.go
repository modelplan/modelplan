//go:build darwin || linux

package detach

import (
	"os"
	"path/filepath"
	"syscall"
)

// StartLocked acquires a nonblocking cross-process lock before spawning. The
// detached child inherits the open file description as fd 3 and holds it until
// exit, including while it starts up. Close only the parent's descriptor here:
// an explicit LOCK_UN would also unlock the child's copy. Never unlink the
// lock inode. A crashed/killed worker releases the kernel lock automatically.
func StartLocked(path string, args ...string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return err
	}
	defer f.Close()
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		return err
	}
	return start([]*os.File{f}, args...)
}

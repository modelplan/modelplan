//go:build darwin || linux

// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"path/filepath"
	"syscall"
)

// lock keeps a stable inode: a live writer owns it until it closes the file,
// and the OS releases it on process death. Callers are intentionally nonblocking.
func lockPlatform(cache, name string) (func(), bool) {
	path := filepath.Join(cache, "observed", name)
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return nil, false
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, false
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		f.Close()
		return nil, false
	}
	return func() { _ = syscall.Flock(int(f.Fd()), syscall.LOCK_UN); _ = f.Close() }, true
}

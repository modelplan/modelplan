//go:build windows

// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"path/filepath"

	"golang.org/x/sys/windows"
)

// Keep the lock file in place so all writers and cleanup lock the same file.
func lock(cache, name string) (func(), bool) {
	path := filepath.Join(cache, "observed", name)
	if err := os.MkdirAll(filepath.Dir(path), 0700); err != nil {
		return nil, false
	}
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, false
	}
	var overlapped windows.Overlapped
	if err := windows.LockFileEx(windows.Handle(f.Fd()), windows.LOCKFILE_EXCLUSIVE_LOCK|windows.LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &overlapped); err != nil {
		f.Close()
		return nil, false
	}
	return func() {
		_ = windows.UnlockFileEx(windows.Handle(f.Fd()), 0, 1, 0, &overlapped)
		_ = f.Close()
	}, true
}

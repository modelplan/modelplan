//go:build windows

// SPDX-License-Identifier: MIT
package consent

import (
	"errors"
	"os"

	"golang.org/x/sys/windows"
)

func lockFileOS(path string) (func(), error) {
	f, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, err
	}
	var overlapped windows.Overlapped
	if err := windows.LockFileEx(windows.Handle(f.Fd()), windows.LOCKFILE_EXCLUSIVE_LOCK|windows.LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &overlapped); err != nil {
		f.Close()
		if errors.Is(err, windows.ERROR_LOCK_VIOLATION) {
			return nil, ErrBusy
		}
		return nil, err
	}
	return func() {
		_ = windows.UnlockFileEx(windows.Handle(f.Fd()), 0, 1, 0, &overlapped)
		_ = f.Close()
	}, nil
}

// lockFileSharedOS takes a shared lock on an existing lock file opened read-only. It never
// creates the file and never conflicts with another shared holder.
func lockFileSharedOS(path string) (func(), error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	var overlapped windows.Overlapped
	if err := windows.LockFileEx(windows.Handle(f.Fd()), windows.LOCKFILE_FAIL_IMMEDIATELY, 0, 1, 0, &overlapped); err != nil {
		f.Close()
		if errors.Is(err, windows.ERROR_LOCK_VIOLATION) {
			return nil, ErrBusy
		}
		return nil, err
	}
	return func() {
		_ = windows.UnlockFileEx(windows.Handle(f.Fd()), 0, 1, 0, &overlapped)
		_ = f.Close()
	}, nil
}

// SPDX-License-Identifier: MIT
package cliupdate

import (
	"errors"
	"os"
	"time"
)

// Older CLI versions use an exclusive-create file marker; the Skill installer
// uses an empty directory marker. A generous timeout
// permits recovery of abandoned legacy markers, but cannot prove an older CLI
// with an aged marker is dead. New updaters serialize on a persistent OS lock.
const legacyUpdateLockStale = 10 * time.Minute

func acquireUpdateLock(target string) (func(), error) {
	unlock, err := lockPlatform(target + ".update.guard")
	if err != nil {
		return nil, ErrBusy
	}
	marker := target + ".update.lock"
	info, err := os.Lstat(marker)
	if err == nil && (info.Mode().IsRegular() || info.IsDir()) && time.Since(info.ModTime()) > legacyUpdateLockStale {
		if err = os.Remove(marker); err != nil {
			unlock()
			return nil, errors.New("cannot recover stale CLI update lock")
		}
	} else if err != nil && !errors.Is(err, os.ErrNotExist) {
		unlock()
		return nil, errors.New("cannot inspect CLI update lock")
	}
	f, err := os.OpenFile(marker, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		unlock()
		if errors.Is(err, os.ErrExist) {
			return nil, ErrBusy
		}
		return nil, errors.New("cannot lock CLI for updating")
	}
	if err = f.Close(); err != nil {
		_ = os.Remove(marker)
		unlock()
		return nil, errors.New("cannot lock CLI for updating")
	}
	return func() { _ = os.Remove(marker); unlock() }, nil
}

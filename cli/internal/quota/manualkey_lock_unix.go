// SPDX-License-Identifier: MIT
//go:build darwin || linux

package quota

import (
	"os"
	"path/filepath"
	"sync"
	"syscall"
)

var manualKeyMu sync.Mutex

// Lock order (T5): consent.ReaderLock, then the observed/*.lock files and the speed ledger lock, then
// lockManualKeys. lockManualKeys is innermost: nothing that holds it takes ReaderLock or any other
// lock. A refresh (quota_native.go) takes it twice, briefly, under ReaderLock; a Forget cleanup
// (forgetTool) takes it under ReaderLock while it filters native.json; SetManualKey and
// RemoveManualKey take it alone, without ReaderLock, because a refresh holds ReaderLock across its
// network reads and a key change must not wait for those.
// lockManualKeys serializes a whole read-modify-replace of the key file, across goroutines and across processes
// that share the directory (two app-servers). The kernel drops the lock on exit.
func lockManualKeys(dir string) (func(), error) {
	manualKeyMu.Lock()
	if err := os.MkdirAll(dir, 0o700); err != nil {
		manualKeyMu.Unlock()
		return nil, err
	}
	f, err := os.Open(filepath.Clean(dir)) // the directory itself is the lock: no extra file is left behind
	if err != nil {
		manualKeyMu.Unlock()
		return nil, err
	}
	if err := syscall.Flock(int(f.Fd()), syscall.LOCK_EX); err != nil {
		f.Close()
		manualKeyMu.Unlock()
		return nil, err
	}
	return func() { syscall.Flock(int(f.Fd()), syscall.LOCK_UN); f.Close(); manualKeyMu.Unlock() }, nil
}

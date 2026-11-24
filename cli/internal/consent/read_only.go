// SPDX-License-Identifier: MIT
package consent

import (
	"errors"
	"os"
	"sync/atomic"
)

// ReadOnly returns the same scope decisions as a schema-one migration without
// writing a backup, epoch, lock or consent file. It is for cache-only views;
// mutations and capture stamps still require the ordinary authoritative Load.
func ReadOnly(file string) (State, error) {
	s, err := readOnlyRaw(file)
	if err != nil {
		return Empty(), err
	}
	return narrowForVerification(s), nil
}

func readOnlyRaw(file string) (State, error) {
	s, _, err := loadRaw(file)
	if err != nil {
		return Empty(), err
	}
	if s.SchemaVersion == 1 {
		// No epoch: a legacy store stays unavailable for capture and publication until a
		// writable launch migrates it.
		s.SchemaVersion = 2
		s.Scopes = map[string]Record{}
		for tool, record := range s.Tools {
			setToolScopes(&s, tool, record)
		}
	}
	return s, nil
}

// readOnlyProcess is set for a read-only (cache-only) app-server (review 11-24 #9,
// macrevb-1218-3). Every consent read in the process then goes through readOnlyRaw, so stamps,
// views, the watcher and readers never migrate a legacy store or write a backup; every writer
// (transactions, migration, cleanup, Reset, the reader lock) is refused before it creates a
// directory or a lock; and publication takes only a shared lock on an existing lock file.
var readOnlyProcess atomic.Bool

// ErrReadOnly is returned to any consent write attempted in a read-only process.
var ErrReadOnly = errors.New("consent is read-only in this process")

// SetReadOnlyProcess switches the whole process to read-only consent access, or back.
func SetReadOnlyProcess(on bool) { readOnlyProcess.Store(on) }

func writable() error {
	if readOnlyProcess.Load() {
		return ErrReadOnly
	}
	return nil
}

func lockFile(path string) (func(), error) {
	if err := writable(); err != nil {
		return nil, err
	}
	return lockFileOS(path)
}

// lockPublication fences a publication against consent writers. A read-only process takes a
// shared lock on the existing lock file and creates nothing; with no lock file it cannot be
// serialized with a writer, so it publishes nothing (fail closed).
func lockPublication(path string) (func(), error) {
	if !readOnlyProcess.Load() {
		return lockFile(path)
	}
	unlock, err := lockFileSharedOS(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, ErrChanged
	}
	return unlock, err
}

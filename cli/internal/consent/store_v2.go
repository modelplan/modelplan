// SPDX-License-Identifier: MIT
package consent

import (
	"bytes"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"os"
	"path/filepath"
)

func newEpoch() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic("consent epoch entropy unavailable")
	}
	return hex.EncodeToString(b[:])
}
func validEpoch(s string) bool {
	b, err := hex.DecodeString(s)
	return err == nil && len(b) == 16
}

// Load migrates schema 1 exactly once while holding the same lock as mutations.
// A missing store has no epoch and no grants until the first transaction.
func Load(file string) (State, error) {
	s, _, err := loadRaw(file)
	if err != nil || s.SchemaVersion != 1 {
		return s, err
	}
	unlock, err := lockFile(file + ".lock")
	if err != nil {
		return Empty(), errors.New("consent busy; retry")
	}
	defer unlock()
	return loadLocked(file)
}

func loadLocked(file string) (State, error) {
	s, raw, err := loadRaw(file)
	if err != nil || s.SchemaVersion != 1 {
		return s, err
	}
	// Preserve the original bytes before committing v2. Never use the backup as
	// authority or overwrite it on a later recovery.
	backup := filepath.Join(filepath.Dir(file), "consent.v1.bak")
	f, err := os.CreateTemp(filepath.Dir(file), ".consent-v1-*")
	if err != nil {
		return Empty(), errors.New("consent backup unavailable")
	}
	defer os.Remove(f.Name())
	if err = f.Chmod(0600); err == nil {
		_, err = f.Write(raw)
	}
	if err == nil {
		err = f.Sync()
	}
	closeErr := f.Close()
	if err == nil {
		err = closeErr
	}
	if err == nil {
		err = os.Link(f.Name(), backup)
		if os.IsExist(err) {
			prior, readErr := os.ReadFile(backup)
			if readErr == nil && bytes.Equal(prior, raw) {
				err = nil
			}
		}
	}
	if err != nil {
		return Empty(), errors.New("consent backup unavailable")
	}
	s.SchemaVersion, s.StoreEpoch = 2, newEpoch()
	s.Scopes = map[string]Record{}
	requests := map[string]Receipt{}
	for id, receipt := range s.Requests {
		requests[ReceiptKey(s.StoreEpoch, id)] = receipt
	}
	s.Requests = requests
	for tool, record := range s.Tools {
		setToolScopes(&s, tool, record)
	}
	for scope := range s.Revoked {
		s.Revoked[scope] = s.Generation
	}
	if err := save(file, s); err != nil {
		return Empty(), err
	}
	return s, nil
}

// Reset is an explicit confirmed recovery action. Load errors never invoke it.
// It leaves the damaged store available for diagnosis and creates a fresh epoch;
// no receipt, grant or generation from the old epoch becomes authoritative.
func Reset(file string) (State, error) {
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		return Empty(), err
	}
	unlock, err := lockFile(file + ".lock")
	if err != nil {
		return Empty(), err
	}
	defer unlock()
	if raw, err := os.ReadFile(file); err == nil {
		if err := os.WriteFile(file+".unreadable.bak", raw, 0600); err != nil {
			return Empty(), err
		}
	} else if !os.IsNotExist(err) {
		return Empty(), err
	}
	s := Empty()
	s.StoreEpoch, s.Generation = newEpoch(), 1
	s.RequireConsent = true
	return s, save(file, s)
}

package quota

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"time"
)

// This reservation contains no reading, identity, profile or consent data. Keep
// it across Forget/disconnect so a new grant or process cannot reset the budget.
type readerAttempt struct {
	SchemaVersion int       `json:"schemaVersion"`
	NextAttemptAt time.Time `json:"nextAttemptAt"`
}

func readerAttemptPath(cache, provider string) string {
	return filepath.Join(cache, "observed", "reader-attempts", provider+".json")
}

func loadReaderAttempt(cache, provider string) (time.Time, error) {
	b, status := readBounded(readerAttemptPath(cache, provider), 4096)
	if status == "missing" {
		return time.Time{}, nil
	}
	var s readerAttempt
	if status != "" || json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 {
		return time.Time{}, errors.New("reader budget unavailable")
	}
	return s.NextAttemptAt, nil
}

func readerAttemptDue(cache, provider string, now time.Time) bool {
	next, err := loadReaderAttempt(cache, provider)
	return err == nil && !now.Before(next)
}

// Caller holds the provider lock. Reservations can only move forward, including
// during migration from the older combined reading/attempt file.
func reserveReaderAttempt(cache, provider string, next time.Time) error {
	previous, err := loadReaderAttempt(cache, provider)
	if err != nil {
		return err
	}
	if previous.After(next) {
		next = previous
	}
	path := readerAttemptPath(cache, provider)
	if os.MkdirAll(filepath.Dir(path), 0700) != nil {
		return errors.New("reader budget unavailable")
	}
	b, _ := json.Marshal(readerAttempt{SchemaVersion: 1, NextAttemptAt: next.UTC()})
	if writeAtomic(path, append(b, '\n')) != nil {
		return errors.New("reader budget unavailable")
	}
	return nil
}

// legacyNativeDue is shared by scheduling and every legacy dispatcher. Check
// the persisted provider reservation even without an aggregate capture. Older
// captures still enforce their own interval/backoff; unrelated session sweeps
// may update the aggregate envelope without postponing a provider's deadline.
func legacyNativeDue(cache, provider string, e codexbarEntry, now time.Time) bool {
	next, err := legacyNativeNext(cache, provider, e)
	return err == nil && !now.Before(next)
}

func legacyNativeNext(cache, provider string, e codexbarEntry) (time.Time, error) {
	next, err := loadReaderAttempt(cache, provider)
	if err != nil || !next.IsZero() {
		return next, err
	}
	if e.ObservedAt.IsZero() {
		return time.Time{}, nil
	}
	wait := NativeEvery
	if e.Status != "ok" {
		wait = nativeRetryAfter
	}
	return e.ObservedAt.Add(wait), nil
}

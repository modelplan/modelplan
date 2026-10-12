// Package store owns the shared local cache described in clients/README.md.
// Every write is temp-file + rename; state.json is written last so a reader
// sees either the previous or the next publication, never a mix.
package store

import (
	"bytes"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"time"
)

// State is the cache's index. It only ever names a fully verified publication.
type State struct {
	Base          string    `json:"base"`
	PublicationID string    `json:"publicationId,omitempty"`
	ManifestHash  string    `json:"manifestHash,omitempty"`
	PublishedAt   string    `json:"publishedAt,omitempty"`
	Component     string    `json:"component,omitempty"` // which component the digest was built from: "client" or "models"
	ComponentHash string    `json:"componentHash,omitempty"`
	ETag          string    `json:"etag,omitempty"`          // of current.json
	CheckedAt     time.Time `json:"checkedAt,omitempty"`     // last successful pointer check
	VerifiedAt    time.Time `json:"verifiedAt,omitempty"`    // last time a publication was verified and switched
	LastAttemptAt time.Time `json:"lastAttemptAt,omitempty"` // last sync attempt, successful or not
	LastError     string    `json:"lastError,omitempty"`
}

type Store struct{ Dir string }

// Open uses $MODELPLAN_CACHE, else os.UserCacheDir()/modelplan.
func Open() (*Store, error) {
	dir := os.Getenv("MODELPLAN_CACHE")
	if dir == "" {
		base, err := os.UserCacheDir()
		if err != nil {
			return nil, err
		}
		dir = filepath.Join(base, "modelplan")
	}
	if err := os.MkdirAll(filepath.Join(dir, "objects"), 0o755); err != nil {
		return nil, err
	}
	return &Store{Dir: dir}, nil
}

func (s *Store) statePath() string { return filepath.Join(s.Dir, "state.json") }

// State returns the zero State when nothing has been synced yet.
func (s *Store) State() (State, error) {
	var st State
	b, err := os.ReadFile(s.statePath())
	if errors.Is(err, os.ErrNotExist) {
		return st, nil
	}
	if err != nil {
		return st, err
	}
	return st, json.Unmarshal(b, &st)
}

func (s *Store) SaveState(st State) error {
	b, err := json.MarshalIndent(st, "", "  ")
	if err != nil {
		return err
	}
	return writeAtomic(s.statePath(), b)
}

func (s *Store) ObjectPath(hash string) string {
	return filepath.Join(s.Dir, "objects", hash+".json")
}

func (s *Store) ManifestPath(publicationID string) string {
	return filepath.Join(s.Dir, "releases", publicationID, "manifest.json")
}

// Object returns a cached, already verified object.
func (s *Store) Object(hash string) ([]byte, error) { return os.ReadFile(s.ObjectPath(hash)) }

// PutObject stores bytes whose hash the caller has verified. Objects are immutable.
func (s *Store) PutObject(hash string, b []byte) error {
	p := s.ObjectPath(hash)
	if existing, err := os.ReadFile(p); err == nil && bytes.Equal(existing, b) {
		return nil
	}
	return writeAtomic(p, b)
}

func (s *Store) PutManifest(publicationID string, b []byte) error {
	p := s.ManifestPath(publicationID)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	return writeAtomic(p, b)
}

func writeAtomic(path string, b []byte) error {
	f, err := os.CreateTemp(filepath.Dir(path), ".tmp-*")
	if err != nil {
		return err
	}
	tmp := f.Name()
	if _, err = f.Write(b); err == nil {
		err = f.Sync()
	}
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Rename(tmp, path)
	}
	if err != nil {
		os.Remove(tmp)
	}
	return err
}

// ErrBusy means another client holds sync.lock.
var ErrBusy = errors.New("another sync is running")

const lockStale = 2 * time.Minute

// Lock takes sync.lock with O_EXCL; a lock older than two minutes is treated as abandoned.
func (s *Store) Lock() (unlock func(), err error) {
	p := filepath.Join(s.Dir, "sync.lock")
	for attempt := 0; attempt < 2; attempt++ {
		f, err := os.OpenFile(p, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o644)
		if err == nil {
			f.Close()
			return func() { os.Remove(p) }, nil
		}
		if !errors.Is(err, os.ErrExist) {
			return nil, err
		}
		if fi, serr := os.Stat(p); serr == nil && time.Since(fi.ModTime()) > lockStale {
			os.Remove(p)
			continue
		}
		return nil, ErrBusy
	}
	return nil, ErrBusy
}

// Prune keeps objects referenced by the kept manifests and anything touched in the last 14 days.
func (s *Store) Prune(keep map[string]bool) {
	entries, err := os.ReadDir(filepath.Join(s.Dir, "objects"))
	if err != nil {
		return
	}
	for _, e := range entries {
		name := e.Name()
		if len(name) < 6 || keep[name[:len(name)-5]] {
			continue
		}
		if fi, err := e.Info(); err == nil && time.Since(fi.ModTime()) > 14*24*time.Hour {
			os.Remove(filepath.Join(s.Dir, "objects", name))
		}
	}
}

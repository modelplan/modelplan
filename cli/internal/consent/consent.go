// Package consent owns shared, versioned reader permissions. It reads no tool
// credentials and invokes no readers. All CLI/App/plugin copies use one file.
package consent

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

const TextVersion = 2
const Text = "Allow ModelPlan on this user account—App, plugins and all CLI copies—to read usage for the selected tools using their existing sign-in, through native readers or audited standard CodexBar access. CodexBar is downloaded automatically with a verified checksum; you do not install it. Your credential is sent only to the provider hosts shown for that tool; it is never sent to ModelPlan servers or stored by ModelPlan. macOS may ask for Keychain access for our own readers; standard CodexBar access has Keychain and browser-cookie import disabled. Browser-session access is excluded and requires separate per-provider consent. You can turn this off in Settings."

const (
	Automatic   = "automatic"
	Passive     = "passive"
	Off         = "off"
	Local       = "local"
	Runtime     = "runtime"
	ExplicitKey = "explicit-key"
	Credential  = "credential"
	Bridge      = "codexbar"
)

type Record struct {
	Allowed            bool      `json:"allowed"`
	ConsentTextVersion int       `json:"consentTextVersion"`
	At                 time.Time `json:"at"`
	ReaderID           string    `json:"readerId,omitempty"`
	Backend            string    `json:"backend,omitempty"`
	Region             string    `json:"region,omitempty"`
	KeyEnv             string    `json:"keyEnv,omitempty"`
	BrowserSession     bool      `json:"browserSession,omitempty"`
	BrowserCookieCache bool      `json:"browserCookieCache,omitempty"`
	// Profiles are opaque descriptors, never account identities or token paths.
	Profiles      []string        `json:"profiles,omitempty"`
	DeniedSources map[string]bool `json:"deniedSources,omitempty"`
}
type State struct {
	SchemaVersion int               `json:"schemaVersion"`
	Generation    uint64            `json:"generation"`
	Privacy       string            `json:"privacy"`
	Tools         map[string]Record `json:"tools"`
	Hinted        map[string]bool   `json:"hinted,omitempty"`
}

var toolID = regexp.MustCompile(`^[a-z][a-z0-9-]{0,47}$`)

func ValidTool(id string) bool { return toolID.MatchString(id) }
func Path() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".config", "modelplan", "consent.json")
}
func Empty() State {
	return State{SchemaVersion: 1, Privacy: Automatic, Tools: map[string]Record{}, Hinted: map[string]bool{}}
}
func Load(file string) (State, error) {
	s := Empty()
	f, err := os.Open(file)
	if errors.Is(err, os.ErrNotExist) {
		return s, nil
	}
	if err != nil {
		return s, errors.New("consent unavailable")
	}
	defer f.Close()
	b, err := io.ReadAll(io.LimitReader(f, (256<<10)+1))
	if err != nil || len(b) > 256<<10 {
		return s, errors.New("consent too large or unreadable")
	}
	if json.Unmarshal(b, &s) != nil || s.SchemaVersion != 1 || (s.Privacy != Automatic && s.Privacy != Passive) || s.Tools == nil {
		return Empty(), errors.New("invalid consent state")
	}
	for id, r := range s.Tools {
		if !ValidTool(id) || r.ConsentTextVersion < 1 {
			return Empty(), errors.New("invalid consent record")
		}
	}
	if s.Hinted == nil {
		s.Hinted = map[string]bool{}
	}
	return s, nil
}

// Effective lets environment settings only restrict a persisted privacy choice.
// An unknown nonempty override fails closed, rather than enabling imports.
func (s State) Effective(override string) string {
	switch strings.ToLower(override) {
	case "off":
		return Off
	case "passive":
		return Passive
	case "":
		return s.Privacy
	default:
		return Off
	}
}
func Current() (State, string) {
	s, err := Load(Path())
	if err != nil {
		return Empty(), Off
	}
	return s, s.Effective(os.Getenv("MODELPLAN_READERS"))
}

// Allows preserves legacy explicit grants when no new decision exists. A
// persisted refusal/revocation always wins. Passive permits only credential-free
// local/runtime reads and explicitly configured environment keys.
func (s State) Allows(tool, class, mode string) bool {
	if mode == Off {
		return false
	}
	if r, ok := s.Tools[tool]; ok {
		if !r.Allowed || r.ConsentTextVersion != TextVersion || r.DeniedSources[class] {
			return false
		}
	} else if class == Credential || class == Bridge || class == "keychain" {
		// A newly shipped import reader cannot treat an absent record as a
		// grant. Existing explicit legacy settings are handled by their owner.
		return false
	}
	if mode == Passive {
		return class == Local || class == Runtime || class == ExplicitKey
	}
	return mode == Automatic
}
func Allowed(tool, class string) bool { s, mode := Current(); return s.Allows(tool, class, mode) }

// Change serialises read/modify/rename across every CLI copy. Generation is the
// reader handoff fence: work started under an older generation is not admitted.
func Change(file string, change func(*State) error) error {
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		return err
	}
	unlock, err := lockFile(file + ".lock")
	if err != nil {
		return errors.New("consent busy; retry")
	}
	defer unlock()
	s, err := Load(file)
	if err != nil {
		return err
	}
	if err = change(&s); err != nil {
		return err
	}
	s.Generation++
	b, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	f, err := os.CreateTemp(filepath.Dir(file), ".consent-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	if err = f.Chmod(0600); err == nil {
		_, err = f.Write(append(b, '\n'))
	}
	if err == nil {
		err = f.Sync()
	}
	closeErr := f.Close()
	if err == nil {
		err = closeErr
	}
	if err == nil {
		err = os.Rename(f.Name(), file)
	}
	return err
}
func Set(s *State, id string, allowed bool, reader, backend string, now time.Time) error {
	if !ValidTool(id) {
		return fmt.Errorf("invalid tool ID")
	}
	r := s.Tools[id]
	r.Allowed = allowed
	r.ConsentTextVersion = TextVersion
	r.At = now.UTC()
	r.ReaderID = reader
	r.Backend = backend
	r.BrowserSession = false
	// Reconnecting does not clear a Keychain Deny. Only explicit Settings Retry
	// may clear that source after informing the user; no retry is offered here.
	s.Tools[id] = r
	return nil
}
func Deny(file, tool, source string) error {
	return Change(file, func(s *State) error {
		r, ok := s.Tools[tool]
		if !ok {
			return errors.New("tool has no consent")
		}
		if r.DeniedSources == nil {
			r.DeniedSources = map[string]bool{}
		}
		r.DeniedSources[source] = true
		s.Tools[tool] = r
		return nil
	})
}
func CurrentGeneration(g uint64) bool { s, err := Load(Path()); return err == nil && s.Generation == g }

// ReaderLock coordinates refresh/snapshot writers with Forget readings. A
// revoked provider is reselected only after this lock, never from a stale list.
func ReaderLock() (func(), error) {
	file := Path() + ".readers.lock"
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		return nil, err
	}
	return lockFile(file)
}

// Detached refreshes may briefly wait for a local snapshot/history commit. Do
// not make the foreground caller wait or let a fresh child starve on that race.
func ReaderLockContext(ctx context.Context) (func(), error) {
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	for {
		unlock, err := ReaderLock()
		if err == nil {
			return unlock, nil
		}
		select {
		case <-ctx.Done():
			return nil, err
		case <-time.After(50 * time.Millisecond):
		}
	}
}

func LocalWrite(tool string, write func() error) error {
	unlock, err := ReaderLock()
	if err != nil {
		return err
	}
	defer unlock()
	s, mode := Current()
	if !s.Allows(tool, Local, mode) {
		return errors.New("local reader not permitted")
	}
	return Publish(s.Generation, write)
}

// Publish serializes generation validation and the short cache commit with
// consent changes. No credential or provider I/O belongs inside this callback.
func Publish(g uint64, write func() error) error {
	file := Path() + ".lock"
	if err := os.MkdirAll(filepath.Dir(file), 0700); err != nil {
		return err
	}
	unlock, err := lockFile(file)
	if err != nil {
		return errors.New("consent busy; reading not published")
	}
	defer unlock()
	s, err := Load(Path())
	if err != nil || s.Generation != g {
		return errors.New("consent changed; reading not published")
	}
	return write()
}

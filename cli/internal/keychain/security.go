// Package keychain hosts the fixed-item injected credential adapter. Without
// an app capability it reports recovery and never starts a process.
package keychain

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"time"
)

const (
	BackgroundTimeout  = 2 * time.Second
	InteractiveTimeout = 30 * time.Second
	maxOutput          = 64 << 10
	Denied             = "denied"
	ConfirmationNeeded = "keychain-confirmation-needed"
)

// Result contains a secret only on success. Callers keep it in transient memory;
// only State and the fixed NextStep may reach logs, caches, doctor or the UI.
type Result struct {
	Value    []byte `json:"-"`
	State    string
	NextStep string
}

// Diagnostics must never serialize or format the transient credential bytes.
func (r Result) String() string   { return "keychain:" + r.State }
func (r Result) GoString() string { return r.String() }

// Policy comes from the shared consent layer. Interactive means an explicit
// Settings/App refresh or CLI action, never a timer, resume or ordinary JSON read.
type Policy struct {
	Allowed     bool
	PriorGrant  bool
	Interactive bool
	ProfileRef  string // keyed profile hash; never a path or account name
}

type ProcessResult struct {
	Output   []byte
	ExitCode int
}

// Execute is injectable: tests never invoke the real security binary/Keychain.
type Execute func(context.Context, string, ...string) (ProcessResult, error)

type Reader struct {
	Cache   string
	Execute Execute
}

var profilePattern = regexp.MustCompile(`^[a-f0-9]{64}$`)

// ClaudeCredentials is deliberately a fixed-item operation. There are no shell,
// arbitrary-item, directory-name derivation or whole-Keychain query interfaces.
func (r Reader) ClaudeCredentials(ctx context.Context, p Policy) Result {
	if r.Execute == nil {
		return Result{State: ConfirmationNeeded, NextStep: "Open the app, or use a credentials file"}
	}
	if !p.Allowed || !profilePattern.MatchString(p.ProfileRef) || r.Cache == "" {
		return Result{State: "consent-required"}
	}
	// Deny belongs to the provider/item, not an account metadata path. Switching
	// profiles must not turn a persisted Deny into another automatic OS prompt.
	path := filepath.Join(r.Cache, "observed", "keychain", "claude-code.json")
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return Result{State: "unavailable"}
	}
	// Cross-process exclusion prevents duplicate OS prompts from several copies.
	if info, err := os.Stat(path + ".lock"); err == nil && time.Since(info.ModTime()) > time.Minute {
		_ = os.Remove(path + ".lock")
	}
	lock, err := os.OpenFile(path+".lock", os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return Result{State: "busy"}
	}
	_ = lock.Close()
	defer os.Remove(path + ".lock")
	if info, err := os.Lstat(path); err == nil && (!info.Mode().IsRegular() || info.Size() > 1024) {
		return Result{State: ConfirmationNeeded, NextStep: "Allow in Settings"}
	}
	if b, err := os.ReadFile(path); err == nil {
		var saved struct {
			State string `json:"state"`
		}
		if json.Unmarshal(b, &saved) != nil {
			return Result{State: ConfirmationNeeded, NextStep: "Allow in Settings"}
		}
		if (saved.State == Denied || saved.State == ConfirmationNeeded) && !p.Interactive {
			return Result{State: saved.State, NextStep: "Allow in Settings"}
		}
	} else if !os.IsNotExist(err) {
		return Result{State: ConfirmationNeeded, NextStep: "Allow in Settings"}
	}
	if !p.Interactive && !p.PriorGrant {
		return Result{State: ConfirmationNeeded, NextStep: "Allow in Settings"}
	}
	duration := BackgroundTimeout
	if p.Interactive {
		duration = InteractiveTimeout
	}
	call, cancel := context.WithTimeout(ctx, duration)
	defer cancel()
	run := r.Execute
	out, err := run(call, "/usr/bin/security", "find-generic-password", "-s", "Claude Code-credentials", "-w")
	state := ""
	switch {
	case errors.Is(call.Err(), context.DeadlineExceeded):
		state = ConfirmationNeeded
	case errors.Is(call.Err(), context.Canceled):
		return Result{State: "canceled"}
	case out.ExitCode == 44:
		return Result{State: "not-found"}
	// security exits with the low byte of OSStatus: canceled=-128, auth=-25293,
	// and interaction-not-allowed=-25308. Never expose stderr or OS error text.
	case out.ExitCode == 128 || out.ExitCode == 51 || out.ExitCode == 36:
		state = Denied
	case err != nil || out.ExitCode != 0 || len(out.Output) > maxOutput:
		return Result{State: "unavailable"}
	default:
		value := bytes.TrimSpace(out.Output)
		if len(value) == 0 {
			return Result{State: "not-found"}
		}
		if p.Interactive {
			_ = os.Remove(path)
		}
		return Result{Value: value, State: "ok"}
	}
	// Only our safe status is persisted. No tool credential or process output.
	b, _ := json.Marshal(struct {
		State string `json:"state"`
	}{state})
	if err := saveState(path, append(b, '\n')); err != nil {
		return Result{State: ConfirmationNeeded, NextStep: "Allow in Settings"}
	}
	return Result{State: state, NextStep: "Allow in Settings"}
}

func saveState(path string, b []byte) error {
	f, err := os.CreateTemp(filepath.Dir(path), ".keychain-state-*")
	if err != nil {
		return err
	}
	defer os.Remove(f.Name())
	if _, err = f.Write(b); err != nil {
		_ = f.Close()
		return err
	}
	if err = f.Close(); err != nil {
		return err
	}
	return os.Rename(f.Name(), path)
}

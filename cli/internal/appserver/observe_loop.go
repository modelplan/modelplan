// SPDX-License-Identifier: MIT
package appserver

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// ObserveOutcome is what one local observer did on a pass. The codes carry no path, identity,
// provider value or error string.
type ObserveOutcome string

const (
	ObserveRan             ObserveOutcome = "ran"
	ObserveSkippedConsent  ObserveOutcome = "skipped_consent"
	ObserveSkippedNoLogs   ObserveOutcome = "skipped_no_logs" // no rollouts or session logs to read
	ObserveSkippedLockBusy ObserveOutcome = "skipped_lock_busy"
	ObserveSkippedOff      ObserveOutcome = "skipped_off" // MODELPLAN_HISTORY=off
	ObserveError           ObserveOutcome = "error"
)

// ObserveResult is one observer's outcome on a pass: Source is codex, claude, zai, opencodego or live.
type ObserveResult struct {
	Source  string
	Outcome ObserveOutcome
}

// ObserveDecision is a recorded outcome with the process-local time it was last seen.
type ObserveDecision struct {
	At      time.Time      `json:"at"`
	Source  string         `json:"source"`
	Outcome ObserveOutcome `json:"outcome"`
}

// ObserveLogFile is where the latest observation outcomes are kept beside the files the
// observers write, so "nothing was written" can be told apart from "never ran".
const ObserveLogFile = "observe-decisions.json"

// observeBusyRetry: the reader lock was held by another process; a read in this one wakes the loop
// as soon as it ends.
const observeBusyRetry = 15 * time.Second

func validObserveResult(r ObserveResult) bool {
	switch r.Source {
	case "codex", "claude", "zai", "opencodego", "live":
	default:
		return false
	}
	switch r.Outcome {
	case ObserveRan, ObserveSkippedConsent, ObserveSkippedNoLogs, ObserveSkippedLockBusy, ObserveSkippedOff, ObserveError:
		return true
	}
	return false
}

// observeLoop runs Observe at once and then every observeEvery, independent of pending refresh
// jobs. It is the only caller, so two observations never overlap. A busy reader lock is skipped,
// not waited for, so a refresh read is never queued behind an observation.
func (s *RefreshScheduler) observeLoop() {
	if s.config.Observe == nil || s.config.Offline || s.config.ReadOnly {
		return
	}
	for s.ctx.Err() == nil {
		now := s.now()
		results := s.config.Observe(now)
		busy := false
		for _, r := range results {
			s.observations.add(now, r)
			busy = busy || r.Outcome == ObserveSkippedLockBusy
		}
		s.writeObserveLog(now)
		if s.ctx.Err() == nil && s.config.Changed != nil {
			s.config.Changed()
		}
		wait, wake := observeEvery, (<-chan struct{})(nil)
		if s.config.ObserveEvery > 0 {
			wait = s.config.ObserveEvery
		}
		if busy {
			wait, wake = min(wait, observeBusyRetry), s.observeWake
		}
		timer := time.NewTimer(wait)
		select {
		case <-s.ctx.Done():
			timer.Stop()
			return
		case <-wake:
			timer.Stop()
		case <-timer.C:
		}
	}
}

// ObserveDecisions returns the bounded, code-only history of observation outcomes.
func (s *RefreshScheduler) ObserveDecisions() []ObserveDecision {
	return s.observations.snapshot()
}

func (s *RefreshScheduler) writeObserveLog(now time.Time) {
	if s.config.Paths == nil {
		return
	}
	cache := s.config.Paths(consent.Capture()).Cache
	if cache == "" {
		return
	}
	dir := filepath.Join(cache, "observed")
	if os.MkdirAll(dir, 0700) != nil {
		return
	}
	b, err := json.Marshal(struct {
		SchemaVersion int               `json:"schemaVersion"`
		WrittenAt     time.Time         `json:"writtenAt"`
		Decisions     []ObserveDecision `json:"decisions"`
	}{1, now.UTC(), s.observations.snapshot()})
	if err != nil {
		return
	}
	f, err := os.CreateTemp(dir, ".tmp-observe-*")
	if err != nil {
		return
	}
	tmp := f.Name()
	_, err = f.Write(append(b, '\n'))
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err == nil {
		err = os.Rename(tmp, filepath.Join(dir, ObserveLogFile))
	}
	if err != nil {
		_ = os.Remove(tmp)
	}
}

// observeRing keeps the last outcomes. An observer that keeps doing the same thing moves only its
// time, so a 30-second cadence does not push the other sources out.
type observeRing struct {
	mu    sync.Mutex
	items [20]ObserveDecision
	next  int
	count int
}

func (r *observeRing) add(at time.Time, result ObserveResult) {
	if !validObserveResult(result) {
		return
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	for i := 1; i <= r.count; i++ {
		at0 := (r.next - i + len(r.items)) % len(r.items)
		if r.items[at0].Source != result.Source {
			continue
		}
		if r.items[at0].Outcome == result.Outcome {
			r.items[at0].At = at.UTC()
			return
		}
		break
	}
	r.items[r.next] = ObserveDecision{At: at.UTC(), Source: result.Source, Outcome: result.Outcome}
	r.next = (r.next + 1) % len(r.items)
	if r.count < len(r.items) {
		r.count++
	}
}

func (r *observeRing) snapshot() []ObserveDecision {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]ObserveDecision, 0, r.count)
	for i := 0; i < r.count; i++ {
		out = append(out, r.items[(r.next-r.count+i+len(r.items))%len(r.items)])
	}
	return out
}

func (r *observeRing) clear() {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.items = [20]ObserveDecision{}
	r.next, r.count = 0, 0
}

// SPDX-License-Identifier: MIT
package speed

import (
	"encoding/json"
	"errors"
	"os"
)

// ForgetSource removes a tool's records from the mixed performance and live
// ledger. The caller holds the consent reader lock. File cursors are retained:
// they do not contain raw paths and must not cause old logs to be re-ingested.
// The ledger's own writer lock serializes this with performance writers.
func ForgetSource(cache, tool string) error {
	source := map[string]string{"claude": "claude-code", "codex": "codex", "zai": "zcode", "opencodego": "opencode"}[tool]
	if source == "" {
		return nil
	}
	return forgetSource(cache, source, write)
}

func forgetSource(cache, source string, replace func(string, []byte) error) error {
	unlock, ok := lock(cache, "perf.lock")
	if !ok {
		return errors.New("performance ledger busy")
	}
	defer unlock()
	if _, err := os.Stat(PerfPath(cache)); errors.Is(err, os.ErrNotExist) {
		return nil
	} else if err != nil {
		return err
	}
	l, ok := LoadPerf(cache)
	if !ok {
		return errors.New("performance ledger unreadable")
	}
	rows := l.Rows[:0]
	for _, r := range l.Rows {
		if r.Source != source {
			rows = append(rows, r)
		}
	}
	l.Rows = rows
	hours := l.Hourly[:0]
	for _, r := range l.Hourly {
		if r.Source != source {
			hours = append(hours, r)
		}
	}
	l.Hourly = hours
	sessions := l.Sessions[:0]
	for _, r := range l.Sessions {
		if r.Source != source {
			sessions = append(sessions, r)
		}
	}
	l.Sessions = sessions
	live := l.Live[:0]
	for _, r := range l.Live {
		if r.Source != source {
			live = append(live, r)
		}
	}
	l.Live = live
	b, err := json.Marshal(l)
	if err != nil {
		return err
	}
	return replace(PerfPath(cache), b)
}

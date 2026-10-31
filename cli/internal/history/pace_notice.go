// SPDX-License-Identifier: MIT
package history

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ClaimPaceWarning reserves one user notice per tool/window across concurrent
// hooks and status lines. Only a hashed event key and its expiry stay on disk;
// no quota reading, configuration or session identifier is stored here.
func ClaimPaceWarning(cache, key string, reset, now time.Time) bool {
	if Off() || key == "" || !reset.After(now) {
		return false
	}
	unlock, ok := lockNamed(cache, "pace-warning.lock")
	if !ok {
		return false
	}
	defer unlock()
	state := struct {
		SchemaVersion int                  `json:"schemaVersion"`
		Windows       map[string]time.Time `json:"windows"`
	}{SchemaVersion: 1, Windows: map[string]time.Time{}}
	path := filepath.Join(cache, "observed", "pace-warning.json")
	f, err := os.Open(path)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return false
	}
	if err == nil {
		b, readErr := io.ReadAll(io.LimitReader(f, (64<<10)+1))
		_ = f.Close()
		if readErr != nil || len(b) > 64<<10 || json.Unmarshal(b, &state) != nil || state.SchemaVersion != 1 || state.Windows == nil {
			return false
		}
	}
	for k, expiry := range state.Windows {
		if !expiry.Add(2 * time.Minute).After(now) {
			delete(state.Windows, k)
		}
	}
	// The reset supplied by a reader may jitter within the same cycle. Hash
	// the tool/window scope and compare its last claimed reset using the same
	// two-minute tolerance as quota history, rather than bucketing timestamps.
	scope := key
	if i := strings.LastIndex(key, "|"); i >= 0 {
		if _, err := time.Parse(time.RFC3339, key[i+1:]); err == nil {
			scope = key[:i]
		}
	}
	sum := sha256.Sum256([]byte(scope))
	id := hex.EncodeToString(sum[:])
	if previous, shown := state.Windows[id]; shown {
		if delta := reset.Sub(previous); delta > -2*time.Minute && delta < 2*time.Minute {
			return false
		}
	} else if len(state.Windows) >= 512 {
		return false
	}
	state.Windows[id] = reset.UTC()
	b, err := json.Marshal(state)
	return err == nil && write(path, b) == nil
}

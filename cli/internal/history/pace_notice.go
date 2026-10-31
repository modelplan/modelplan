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
		if !expiry.After(now) {
			delete(state.Windows, k)
		}
	}
	sum := sha256.Sum256([]byte(key))
	id := hex.EncodeToString(sum[:])
	if _, shown := state.Windows[id]; shown || len(state.Windows) >= 512 {
		return false
	}
	state.Windows[id] = reset.UTC()
	b, err := json.Marshal(state)
	return err == nil && write(path, b) == nil
}

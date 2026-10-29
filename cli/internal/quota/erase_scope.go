// SPDX-License-Identifier: MIT
package quota

import (
	"errors"
	"os"
	"path/filepath"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
)

// EraseScope is the engine's cleanup hook. It never reads tool credentials,
// starts a provider, or erases the independent shared request reservations.
func EraseScope(p Paths, scope string, forget bool) error {
	tool, path, ok := strings.Cut(scope, ".")
	if !ok || !consent.ValidScope(scope) {
		return errors.New("invalid scope")
	}
	if path == "local_history" {
		unlock, err := consent.ReaderLock()
		if err != nil {
			return err
		}
		defer unlock()
		if err := localusage.ForgetProductionHistoryLocked(p.Cache, tool); err != nil {
			return err
		}
		// Retired adapters can leave captures in the established cache namespace.
		// Remove those by validated tool ID even when no current parser owns them.
		entries, err := os.ReadDir(filepath.Join(p.Cache, "observed"))
		if err != nil && !os.IsNotExist(err) {
			return err
		}
		for _, entry := range entries {
			if owner, valid := localusage.HistoryCacheTool(entry.Name()); valid && owner == tool {
				if err := os.Remove(filepath.Join(p.Cache, "observed", entry.Name())); err != nil {
					return err
				}
			}
		}
		if tool == "claude" {
			if err := os.Remove(filepath.Join(p.Cache, "observed", "claude-code.json")); err != nil && !os.IsNotExist(err) {
				return err
			}
		}
		return nil
	}
	d, known := consent.Definition(scope)
	if !known {
		return forgetTool(p, tool, false, forget, "")
	} // Erase established cache formats even after a reader retires.
	return forgetTool(p, tool, false, forget, d.Class)
}

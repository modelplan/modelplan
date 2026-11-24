// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"path/filepath"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// ActivityDiscoveryInterval is the minimum time between background directory
// walks on unchanged admission. The two-second observer still checks known
// recent files and expires activity at the existing cadence.
const ActivityDiscoveryInterval = 6 * time.Second

// ActivityLogIndex belongs to the engine's serial activity observer. It
// retains only bounded filenames and forgets them on a change of admission.
type ActivityLogIndex struct {
	roots     [3]string
	fence     consent.Fence
	scannedAt time.Time
	logs      []LiveLog
}

func (i *ActivityLogIndex) Logs(claude, codex, zcode string, fence consent.Fence, now, elapsed time.Time) []LiveLog {
	homes := [3]string{claude, codex, zcode}
	roots := activityRoots(claude, codex, zcode)
	if i.roots != homes || i.fence != fence || i.scannedAt.IsZero() ||
		elapsed.Before(i.scannedAt) || elapsed.Sub(i.scannedAt) >= ActivityDiscoveryInterval {
		i.roots, i.fence, i.scannedAt = homes, fence, elapsed
		i.logs = activeLogs(roots, now)
	}

	// A remembered path doesn't authorize following a replacement ancestor.
	// Share the directory checks across the bounded recent files in this tick.
	directories := map[string]bool{}
	var valid []LiveLog
	for _, log := range i.logs {
		for _, root := range roots {
			if log.Source == root.source && checkedLogParents(log.Path, root.dir, directories) {
				valid = append(valid, log)
				break
			}
		}
	}
	return valid
}

func checkedLogParents(path, root string, checked map[string]bool) bool {
	dir := filepath.Dir(path)
	if valid, known := checked[dir]; known {
		return valid
	}
	if dir != root && (dir == filepath.Dir(dir) || !checkedLogParents(dir, root, checked)) {
		return false
	}
	info, err := os.Lstat(dir)
	valid := err == nil && info.IsDir()
	checked[dir] = valid
	return valid
}

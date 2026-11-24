// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"path/filepath"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/logindex"
)

// ActivityDiscoveryInterval is the longest a new log in a directory where logs appear (a
// history root, its immediate children, the newest directories and the recently changed ones)
// waits to be discovered. The two-second observer still checks known recent files and expires
// activity at the existing cadence; idle discovery stats metadata and lists nothing.
const ActivityDiscoveryInterval = logindex.HotInterval

// ActivityLogIndex belongs to the engine's serial activity observer. It reads the shared
// history inventory, which retains only bounded filenames and metadata and forgets them on a
// change of admission.
type ActivityLogIndex struct {
	// Inventory is shared with the rollout selection and the observation pass; nil keeps a
	// private one.
	Inventory *logindex.Inventory
	own       logindex.Inventory
}

func (i *ActivityLogIndex) inventory() *logindex.Inventory {
	if i.Inventory != nil {
		return i.Inventory
	}
	return &i.own
}

func (i *ActivityLogIndex) Logs(claude, codex, zcode string, fence consent.Fence, now, elapsed time.Time) []LiveLog {
	roots := activityRoots(claude, codex, zcode)
	logs := recentLogs(i.inventory(), fence, roots, now, elapsed)

	// A remembered path doesn't authorize following a replacement ancestor.
	// Share the directory checks across the bounded recent files in this tick.
	directories := map[string]bool{}
	var valid []LiveLog
	for _, log := range logs {
		for _, root := range roots {
			if root.enabled && log.Source == root.source && checkedLogParents(log.Path, root.dir, directories) {
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

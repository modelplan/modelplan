// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// ActivityDiscoveryInterval is the minimum time between background directory
// walks on unchanged admission. The two-second observer still checks known
// recent files and expires activity at the existing cadence.
const ActivityDiscoveryInterval = 6 * time.Second

// ActivityLogIndex is shared by the engine's activity and accounting observers. It
// retains only bounded filenames and forgets them on a change of admission.
type ActivityLogIndex struct {
	DirectoryReader func(consent.Admission, time.Time) func(string) ([]os.DirEntry, error)
	mu              sync.Mutex
	roots           [3]string
	fence           consent.Fence
	scannedAt       time.Time
	logs            []LiveLog
}

func (i *ActivityLogIndex) Logs(claude, codex, zcode string, fence consent.Fence, now, elapsed time.Time) []LiveLog {
	return i.logsFrom(claude, codex, zcode, fence, now, elapsed, os.ReadDir)
}

func (i *ActivityLogIndex) AdmittedLogs(claude, codex, zcode string, admission consent.Admission, now, elapsed time.Time) []LiveLog {
	readDir := os.ReadDir
	if i.DirectoryReader != nil {
		readDir = i.DirectoryReader(admission, elapsed)
	}
	return i.logsFrom(claude, codex, zcode, admission.Fence(), now, elapsed, readDir)
}

func (i *ActivityLogIndex) logsFrom(claude, codex, zcode string, fence consent.Fence, now, elapsed time.Time, readDir func(string) ([]os.DirEntry, error)) []LiveLog {
	i.mu.Lock()
	defer i.mu.Unlock()

	homes := [3]string{claude, codex, zcode}
	roots := activityRoots(claude, codex, zcode)
	if i.roots != homes || i.fence != fence || i.scannedAt.IsZero() ||
		elapsed.Before(i.scannedAt) || elapsed.Sub(i.scannedAt) >= ActivityDiscoveryInterval {
		i.roots, i.fence, i.scannedAt = homes, fence, elapsed
		i.logs = activeLogsFrom(roots, now, readDir)
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

// Reset discards cached paths when the engine's consent generation changes.
func (i *ActivityLogIndex) Reset() {
	i.mu.Lock()
	defer i.mu.Unlock()
	i.roots, i.fence, i.scannedAt, i.logs = [3]string{}, consent.Fence{}, time.Time{}, nil
}

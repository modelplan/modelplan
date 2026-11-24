// SPDX-License-Identifier: MIT
package localusage

import (
	"os"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

const (
	directoryInventoryLimit = 512
	directoryListingLimit   = 4096
	missingDirectoryDelay   = 30 * time.Second
)

// DirectoryInventory shares directory listings only. Readers still check current
// admission and file metadata before opening any history.
type DirectoryInventory struct {
	mu      sync.Mutex
	fence   consent.Fence
	mode    string
	consent os.FileInfo
	dirs    map[string]directoryListing
	entries int
	readDir func(string) ([]os.DirEntry, error)
}

type directoryListing struct {
	info    os.FileInfo
	entries []os.DirEntry
	retryAt time.Time
}

// ForAdmission returns a directory reader scoped to one admitted observation.
// Callers must pass only paths within their admitted history roots.
func (i *DirectoryInventory) ForAdmission(admission consent.Admission, now time.Time) func(string) ([]os.DirEntry, error) {
	if i == nil {
		return os.ReadDir
	}
	return func(dir string) ([]os.DirEntry, error) {
		i.mu.Lock()
		defer i.mu.Unlock()
		// A private lookup needs current admission. The consent store is atomically
		// replaced, so unchanged exact metadata reuses its last verified fence.
		consentInfo, err := os.Stat(consent.Path())
		if err != nil {
			i.adopt(consent.Admission{})
			i.consent = nil
			return nil, os.ErrPermission
		}
		if !sameDirectoryVersion(i.consent, consentInfo) {
			i.adopt(consent.Capture())
			i.consent = consentInfo
		}
		if i.mode == consent.Off || i.fence != admission.Fence() || i.mode != admission.Mode() {
			return nil, os.ErrPermission
		}
		old, known := i.dirs[dir]
		if known && old.info == nil && now.Before(old.retryAt) {
			return nil, os.ErrNotExist
		}
		info, err := os.Lstat(dir)
		if err != nil || !info.IsDir() {
			if os.IsNotExist(err) {
				i.remember(dir, directoryListing{retryAt: now.Add(missingDirectoryDelay)})
			} else {
				i.delete(dir)
			}
			return nil, os.ErrNotExist
		}
		if sameDirectoryVersion(old.info, info) {
			return old.entries, nil
		}
		readDir := i.readDir
		if readDir == nil {
			readDir = os.ReadDir
		}
		entries, err := readDir(dir)
		if err != nil {
			i.delete(dir)
			return nil, err
		}
		i.remember(dir, directoryListing{info: info, entries: entries})
		return entries, nil
	}
}

// Clear discards all discovered paths, including an outstanding root retry.
func (i *DirectoryInventory) Clear() {
	i.mu.Lock()
	defer i.mu.Unlock()
	i.consent = nil
	i.adopt(consent.Admission{})
}

func sameDirectoryVersion(previous, current os.FileInfo) bool {
	return previous != nil && current != nil && os.SameFile(previous, current) &&
		previous.ModTime().Equal(current.ModTime()) && previous.Mode() == current.Mode() &&
		previous.Size() == current.Size()
}

func (i *DirectoryInventory) adopt(admission consent.Admission) {
	if i.fence != admission.Fence() || i.mode != admission.Mode() {
		i.fence, i.mode = admission.Fence(), admission.Mode()
		i.dirs, i.entries = nil, 0
	}
}

func (i *DirectoryInventory) delete(dir string) {
	i.entries -= len(i.dirs[dir].entries)
	delete(i.dirs, dir)
}

func (i *DirectoryInventory) remember(dir string, listing directoryListing) {
	i.delete(dir)
	if len(i.dirs) >= directoryInventoryLimit || i.entries+len(listing.entries) > directoryListingLimit {
		return
	}
	if i.dirs == nil {
		i.dirs = make(map[string]directoryListing)
	}
	i.dirs[dir] = listing
	i.entries += len(listing.entries)
}

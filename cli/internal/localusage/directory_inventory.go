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
	coldDirectoryLimit      = 20_000
	coldDiscoveryBatch      = 16
	coldDiscoveryInterval   = 6 * time.Second
	missingDirectoryDelay   = 30 * time.Second
)

// DirectoryInventory shares directory listings only. Readers still check current
// admission and file metadata before opening any history.
type DirectoryInventory struct {
	mu           sync.Mutex
	fence        consent.Fence
	mode         string
	consent      os.FileInfo
	dirs         map[string]directoryListing
	entries      int
	cold         map[string]directoryListing
	firstPass    time.Time
	coldBudgetAt time.Time
	coldReads    int
	coldChildren int
	readDir      func(string) ([]os.DirEntry, error)
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
		if i.firstPass.IsZero() {
			i.firstPass = now
		}
		old, hot := i.dirs[dir]
		cold, watched := i.cold[dir]
		if !hot && watched {
			old = cold
		}
		if old.info == nil && now.Before(old.retryAt) {
			return nil, os.ErrNotExist
		}
		info, err := os.Lstat(dir)
		if err != nil || !info.IsDir() {
			if os.IsNotExist(err) {
				i.remember(dir, directoryListing{retryAt: now.Add(missingDirectoryDelay)}, now)
			} else {
				i.delete(dir)
			}
			return nil, os.ErrNotExist
		}

		same := sameDirectoryVersion(old.info, info)
		if hot && same {
			return old.entries, nil
		}
		if !hot {
			// Keep the cold subtree reachable using its compact directory names.
			// Content appends can leave the directory stamp unchanged, so cold
			// file names also get a bounded periodic reconciliation.
			if watched && same && now.Before(old.retryAt) {
				return old.entries, nil
			}
			atCapacity := len(i.cold) > 0 || len(i.dirs) >= directoryInventoryLimit || i.entries >= directoryListingLimit
			if (watched || atCapacity) && !now.Equal(i.firstPass) && !i.takeColdRead(now) {
				return old.entries, nil
			}
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
		i.remember(dir, directoryListing{info: info, entries: entries}, now)
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
		i.dirs, i.entries, i.cold = nil, 0, nil
		i.firstPass, i.coldBudgetAt, i.coldReads, i.coldChildren = time.Time{}, time.Time{}, 0, 0
	}
}

func (i *DirectoryInventory) delete(dir string) {
	i.entries -= len(i.dirs[dir].entries)
	delete(i.dirs, dir)
	i.coldChildren -= len(i.cold[dir].entries)
	delete(i.cold, dir)
}

// Cold listings share 16 directory opens per six seconds regardless of
// history size. The first discovery is complete, so the caller can seed its
// active candidates once. Later callers retain those candidates while each
// cold subtree reconciles in turn.
func (i *DirectoryInventory) takeColdRead(now time.Time) bool {
	if i.coldBudgetAt.IsZero() || now.Sub(i.coldBudgetAt) >= coldDiscoveryInterval {
		i.coldBudgetAt, i.coldReads = now, 0
	}
	if i.coldReads >= coldDiscoveryBatch {
		return false
	}
	i.coldReads++
	return true
}

func (i *DirectoryInventory) remember(dir string, listing directoryListing, now time.Time) {
	i.delete(dir)
	if len(i.dirs) < directoryInventoryLimit && i.entries+len(listing.entries) <= directoryListingLimit {
		if i.dirs == nil {
			i.dirs = make(map[string]directoryListing)
		}
		i.dirs[dir] = listing
		i.entries += len(listing.entries)
		return
	}
	if len(i.cold) >= coldDirectoryLimit {
		return
	}
	if i.cold == nil {
		i.cold = make(map[string]directoryListing)
	}
	var children []os.DirEntry
	for _, entry := range listing.entries {
		if entry.IsDir() && i.coldChildren+len(children) < coldDirectoryLimit {
			children = append(children, entry)
		}
	}
	listing.entries = children
	i.coldChildren += len(children)
	if listing.info != nil {
		round := time.Duration(1+len(i.cold)/coldDiscoveryBatch) * coldDiscoveryInterval
		listing.retryAt = now.Add(max(missingDirectoryDelay, round))
	}
	i.cold[dir] = listing
}

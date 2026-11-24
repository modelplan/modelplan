// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"slices"
	"sort"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/localusage"
)

const codexRolloutDiscoveryInterval = 6 * time.Second

// CodexRolloutIndex shares bounded rollout discovery between the app-server's
// metadata watcher and quota views. Contents and credentials are never cached here.
type CodexRolloutIndex struct {
	Directories  *localusage.DirectoryInventory
	mu           sync.Mutex
	home, thread string
	fence        consent.Fence
	scannedAt    time.Time
	files        []string
	own          string
}

func (p Paths) RecentCodexRollouts() ([]string, string) {
	if p.CodexIndex == nil {
		return discoverCodexRollouts(p.CodexHome, p.CodexThread, codexFiles)
	}
	admission := admissionFor(p)
	if !admission.Allows("codex", consent.Local) || admission.CleanupPending("codex") ||
		admission.CleanupPending(consent.ScopeCodexLocalHistory) || p.CodexHome == "" {
		p.CodexIndex.Reset()
		return nil, ""
	}
	now := time.Now()
	return p.CodexIndex.recentFrom(p.CodexHome, p.CodexThread, admission.Fence(), now, p.CodexIndex.Directories.ForAdmission(admission, now))
}

func (i *CodexRolloutIndex) Reset() {
	if i == nil {
		return
	}
	i.mu.Lock()
	defer i.mu.Unlock()
	i.home, i.thread, i.own, i.files, i.scannedAt = "", "", "", nil, time.Time{}
}

func (i *CodexRolloutIndex) recent(home, thread string, fence consent.Fence, now time.Time) ([]string, string) {
	return i.recentFrom(home, thread, fence, now, os.ReadDir)
}

func (i *CodexRolloutIndex) recentFrom(home, thread string, fence consent.Fence, now time.Time, readDir func(string) ([]os.DirEntry, error)) ([]string, string) {
	i.mu.Lock()
	defer i.mu.Unlock()
	root := filepath.Join(home, "sessions")
	checked := map[string]bool{}
	validParents := func(file string) bool {
		return checkedRolloutDirectory(filepath.Dir(file), root, checked)
	}
	sameSource := i.home == home && i.thread == thread && i.fence == fence
	if !sameSource || i.scannedAt.IsZero() || now.Before(i.scannedAt) || now.Sub(i.scannedAt) >= codexRolloutDiscoveryInterval {
		files, own := discoverCodexRolloutsFrom(home, thread, codexFiles, readDir)
		if sameSource && !i.scannedAt.IsZero() {
			// A cold-directory reconciliation observes a subset of the tree.
			// Keep previously admitted candidates in the current mtime ranking.
			files = rankKnownRollouts(append(files, i.files...), validParents)
			if own == "" {
				own = i.own
			}
			if own != "" && !slices.Contains(files, own) {
				files = append([]string{own}, files...)
			}
		}
		i.home, i.thread, i.fence, i.scannedAt = home, thread, fence, now
		i.files, i.own = files, own
	}

	// Reject replaced ancestors before accessing their file metadata.
	files := slices.DeleteFunc(slices.Clone(i.files), func(file string) bool {
		if !validParents(file) {
			return true
		}
		info, err := os.Lstat(file)
		return err != nil || !info.Mode().IsRegular()
	})
	own := i.own
	if !slices.Contains(files, own) {
		own = ""
	}
	return files, own
}

func rankKnownRollouts(files []string, validParents func(string) bool) []string {
	modified := make(map[string]time.Time, len(files))
	unique := make([]string, 0, len(files))
	for _, path := range files {
		if _, known := modified[path]; known || !validParents(path) {
			continue
		}
		if info, err := os.Lstat(path); err == nil && info.Mode().IsRegular() {
			modified[path] = info.ModTime()
			unique = append(unique, path)
		}
	}
	sort.SliceStable(unique, func(i, j int) bool { return modified[unique[i]].After(modified[unique[j]]) })
	return unique[:min(len(unique), codexFiles)]
}

func checkedRolloutDirectory(dir, root string, checked map[string]bool) bool {
	if valid, known := checked[dir]; known {
		return valid
	}
	if dir != root && (dir == filepath.Dir(dir) || !checkedRolloutDirectory(filepath.Dir(dir), root, checked)) {
		checked[dir] = false
		return false
	}
	info, err := os.Lstat(dir)
	valid := err == nil && info.IsDir()
	checked[dir] = valid
	return valid
}

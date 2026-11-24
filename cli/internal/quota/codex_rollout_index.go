// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"slices"
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
	if i.home != home || i.thread != thread || i.fence != fence || i.scannedAt.IsZero() ||
		now.Before(i.scannedAt) || now.Sub(i.scannedAt) >= codexRolloutDiscoveryInterval {
		i.home, i.thread, i.fence, i.scannedAt = home, thread, fence, now
		i.files, i.own = discoverCodexRolloutsFrom(home, thread, codexFiles, readDir)
	}

	// The older discovery rejected symlink date directories. Recheck that
	// property before returning a remembered filename, including after rename.
	root := filepath.Join(home, "sessions")
	files := slices.DeleteFunc(slices.Clone(i.files), func(file string) bool {
		info, err := os.Lstat(file)
		if err != nil || !info.Mode().IsRegular() {
			return true
		}
		for dir := filepath.Dir(file); ; dir = filepath.Dir(dir) {
			info, err := os.Lstat(dir)
			if err != nil || !info.IsDir() || dir == filepath.Dir(dir) {
				return true
			}
			if dir == root {
				break
			}
		}
		return false
	})
	own := i.own
	if !slices.Contains(files, own) {
		own = ""
	}
	return files, own
}

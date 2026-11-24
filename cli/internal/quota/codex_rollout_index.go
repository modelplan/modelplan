// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"slices"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

const codexRolloutDiscoveryInterval = 6 * time.Second

// CodexRolloutIndex shares bounded rollout discovery between the app-server's
// metadata watcher and quota views. Contents and credentials are never cached here.
type CodexRolloutIndex struct {
	// Clock replaces time.Now for the discovery interval (idle-work gates only).
	Clock        func() time.Time
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
		p.CodexIndex.clear()
		return nil, ""
	}
	now := time.Now()
	if p.CodexIndex.Clock != nil {
		now = p.CodexIndex.Clock()
	}
	return p.CodexIndex.recent(p.CodexHome, p.CodexThread, admission.Fence(), now)
}

func (i *CodexRolloutIndex) clear() {
	if i == nil {
		return
	}
	i.mu.Lock()
	defer i.mu.Unlock()
	i.home, i.thread, i.own, i.files, i.scannedAt = "", "", "", nil, time.Time{}
}

func (i *CodexRolloutIndex) recent(home, thread string, fence consent.Fence, now time.Time) ([]string, string) {
	i.mu.Lock()
	defer i.mu.Unlock()
	if i.home != home || i.thread != thread || i.fence != fence || i.scannedAt.IsZero() ||
		now.Before(i.scannedAt) || now.Sub(i.scannedAt) >= codexRolloutDiscoveryInterval {
		i.home, i.thread, i.fence, i.scannedAt = home, thread, fence, now
		i.files, i.own = discoverCodexRollouts(home, thread, codexFiles)
	}

	// The older discovery rejected symlink date directories. Recheck that
	// property before returning a remembered filename, including after rename.
	root := filepath.Join(home, "sessions")
	files := slices.DeleteFunc(slices.Clone(i.files), func(file string) bool {
		info, err := os.Lstat(file)
		if err != nil || !info.Mode().IsRegular() {
			return true
		}
		for dir := filepath.Dir(file); dir != root; dir = filepath.Dir(dir) {
			info, err := os.Lstat(dir)
			if err != nil || !info.IsDir() {
				return true
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

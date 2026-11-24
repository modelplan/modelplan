// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"slices"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/logindex"
)

// codexRolloutDiscoveryInterval is the longest a new rollout in today's directory waits to be
// discovered: the shared inventory's hot check (D397).
const codexRolloutDiscoveryInterval = logindex.HotInterval

// CodexRolloutIndex selects the bounded recent rollouts for the app-server's metadata watcher
// and quota views from the shared history inventory. Contents and credentials are never
// cached here.
type CodexRolloutIndex struct {
	// Clock replaces time.Now for the discovery interval (idle-work gates only).
	Clock func() time.Time
	// Inventory is shared with the activity observer and the observation pass; nil keeps a
	// private one.
	Inventory *logindex.Inventory
	own       logindex.Inventory
}

func (p Paths) RecentCodexRollouts() ([]string, string) {
	if p.CodexIndex == nil {
		return discoverCodexRollouts(p.CodexHome, p.CodexThread, codexFiles)
	}
	admission := admissionFor(p)
	if !admission.Allows("codex", consent.Local) || admission.CleanupPending("codex") ||
		admission.CleanupPending(consent.ScopeCodexLocalHistory) || p.CodexHome == "" {
		p.CodexIndex.clear(p.CodexHome)
		return nil, ""
	}
	now := time.Now()
	if p.CodexIndex.Clock != nil {
		now = p.CodexIndex.Clock()
	}
	return p.CodexIndex.recent(p.CodexHome, p.CodexThread, admission.Fence(), now)
}

func (i *CodexRolloutIndex) inventory() *logindex.Inventory {
	if i.Inventory != nil {
		return i.Inventory
	}
	return &i.own
}

func (i *CodexRolloutIndex) clear(home string) {
	if i == nil {
		return
	}
	if home == "" {
		home = CodexHome()
	}
	if home != "" {
		i.inventory().Drop(filepath.Join(home, "sessions"))
	}
}

func (i *CodexRolloutIndex) recent(home, thread string, fence consent.Fence, now time.Time) ([]string, string) {
	selected, selectedOwn := selectRollouts(i.inventory(), fence, home, thread, codexFiles, now)

	// The older discovery rejected symlink date directories. Recheck that
	// property before returning a remembered filename, including after rename.
	root := filepath.Join(home, "sessions")
	files := slices.DeleteFunc(selected, func(file string) bool {
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
	own := selectedOwn
	if !slices.Contains(files, own) {
		own = ""
	}
	return files, own
}

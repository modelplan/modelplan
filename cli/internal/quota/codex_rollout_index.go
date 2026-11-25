// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
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

	// The last selection and the inventory generation it was made under: while the generation
	// stands, the selection stands, so an idle watcher tick neither copies the inventory nor
	// matches and sorts it (#1222 sampling P2).
	mu    sync.Mutex
	cache rolloutSelection
}

type rolloutSelection struct {
	gen          uint64
	home, thread string
	fence        consent.Fence
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
		p.CodexIndex.clear(p.CodexHome, admission.Fence())
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

// clear forgets Codex under the withdrawing admission's fence: the cached selection (rollout
// paths and the own thread's) and the inventory's sessions root. Advancing the inventory to that
// fence makes any call still holding an older admission refused, so it cannot rebuild either
// (macrev2-1261-2). It runs under the selection's lock, so a selection in progress finishes
// before it and is discarded by it.
func (i *CodexRolloutIndex) clear(home string, fence consent.Fence) {
	if i == nil {
		return
	}
	i.mu.Lock()
	defer i.mu.Unlock()
	i.cache = rolloutSelection{}
	i.inventory().Advance(fence)
	if home == "" {
		home = CodexHome()
	}
	if home != "" {
		i.inventory().Drop(filepath.Join(home, "sessions"))
	}
}

func (i *CodexRolloutIndex) recent(home, thread string, fence consent.Fence, now time.Time) ([]string, string) {
	selected, selectedOwn := i.selection(home, thread, fence, now)

	// The older discovery rejected symlink date directories. Recheck that
	// property before returning a remembered filename, including after rename.
	files := ConfinedRollouts(home, selected)
	own := selectedOwn
	if !slices.Contains(files, own) {
		own = ""
	}
	return files, own
}

// selection is selectRollouts over the inventory, made again only when the inventory's
// generation, the home, the thread or the fence moved.
func (i *CodexRolloutIndex) selection(home, thread string, fence consent.Fence, now time.Time) ([]string, string) {
	i.mu.Lock()
	defer i.mu.Unlock()
	c := &i.cache
	have := uint64(0)
	if c.gen != 0 && c.home == home && c.thread == thread && c.fence == fence {
		have = c.gen
	}
	files, own, gen, changed := selectRolloutsIfChanged(i.inventory(), fence, home, thread, codexFiles, now, have)
	if changed && gen == 0 { // refused: an older fence than the inventory's, or no home
		*c = rolloutSelection{}
		return nil, ""
	}
	if changed {
		*c = rolloutSelection{gen: gen, home: home, thread: thread, fence: fence, files: files, own: own}
	}
	return slices.Clone(c.files), c.own
}

// ConfinedRollouts keeps the rollouts that are still regular files under home's sessions
// directory through real directories only. A path remembered by the inventory may have changed
// ancestry since it was listed (a date directory replaced by a symlink), so every content
// reader runs this right before it opens them (D397, macrevb-1222-4).
func ConfinedRollouts(home string, files []string) []string {
	if home == "" {
		return nil
	}
	root := filepath.Clean(filepath.Join(home, "sessions"))
	if info, err := os.Lstat(root); err != nil || !info.IsDir() {
		return nil
	}
	checked := map[string]bool{root: true}
	return slices.DeleteFunc(slices.Clone(files), func(file string) bool { return !rolloutConfined(root, file, checked) })
}

func rolloutConfined(root, file string, checked map[string]bool) bool {
	file = filepath.Clean(file)
	if !strings.HasPrefix(file, root+string(filepath.Separator)) {
		return false
	}
	info, err := os.Lstat(file)
	if err != nil || !info.Mode().IsRegular() {
		return false
	}
	for dir := filepath.Dir(file); dir != root; dir = filepath.Dir(dir) {
		if valid, known := checked[dir]; known {
			if !valid {
				return false
			}
			continue
		}
		info, err := os.Lstat(dir)
		checked[dir] = err == nil && info.IsDir()
		if !checked[dir] {
			return false
		}
	}
	return true
}

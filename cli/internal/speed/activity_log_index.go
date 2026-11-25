// SPDX-License-Identifier: MIT
package speed

import (
	"github.com/modelplan/modelplan/cli/internal/confine"
	"os"
	"path/filepath"
	"strings"
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

// ConfinedLogs keeps the logs that are still regular files under their source's admitted
// history root (Claude Code projects, Codex sessions) through real directories only. A path the
// inventory remembered may have changed ancestry since it was listed, so the observation pass
// runs this right before it opens the logs (D397, macrevb-1222-4). An empty home admits nothing.
func ConfinedLogs(logs []LiveLog, claudeHome, codexHome string) []LiveLog {
	roots := map[string]string{}
	if claudeHome != "" {
		roots["claude-code"] = filepath.Join(claudeHome, "projects")
	}
	if codexHome != "" {
		roots["codex"] = filepath.Join(codexHome, "sessions")
	}
	checked := map[string]bool{}
	out := []LiveLog{}
	for _, log := range logs {
		if root, ok := roots[log.Source]; ok && LogConfined(log.Path, root, checked) {
			out = append(out, log)
		}
	}
	return out
}

// LogConfined: path is a regular file below root, reached through real directories only.
// checked shares the directory checks between calls; nil checks afresh.
func LogConfined(path, root string, checked map[string]bool) bool {
	root, path = filepath.Clean(root), filepath.Clean(path)
	if !filepath.IsAbs(root) || !strings.HasPrefix(path, root+string(filepath.Separator)) {
		return false
	}
	if info, err := os.Lstat(path); err != nil || !info.Mode().IsRegular() {
		return false
	}
	if checked == nil {
		checked = map[string]bool{}
	}
	return checkedLogParents(path, root, checked)
}

// HistoryRoots are the admitted history roots a log can be found under: Claude Code's projects,
// Codex's sessions and ZCode's CLI logs, as the observers derive them.
func HistoryRoots() []string {
	home, _ := os.UserHomeDir()
	claude := os.Getenv("CLAUDE_CONFIG_DIR")
	if claude == "" && home != "" {
		claude = filepath.Join(home, ".claude")
	}
	codex := os.Getenv("CODEX_HOME")
	if codex == "" && home != "" {
		codex = filepath.Join(home, ".codex")
	}
	var roots []string
	for _, root := range []string{filepath.Join(claude, "projects"), filepath.Join(codex, "sessions"), filepath.Join(home, ".zcode", "cli", "log")} {
		if filepath.IsAbs(root) {
			roots = append(roots, root)
		}
	}
	return roots
}

// openLog opens a history log for its content. A log below an admitted history root is opened
// anchored to that root (confine.Open), so a check of its ancestry cannot be raced by swapping
// an ancestor for a symlink before the open (D397, macrevb-1222-4).
func openLog(path string) (*os.File, error) { return confine.OpenUnder(HistoryRoots(), path) }

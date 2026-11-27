package speed

import (
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/idlework"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// Codex's own workspaces: the folders it lists. config.toml keeps one [projects."<path>"] table per
// folder the user trusted (CLI and desktop app), and the desktop app keeps its saved workspace
// roots in .codex-global-state.json. A session belongs to the listed folder that contains its
// working directory, or the repository root of it (Codex resolves a worktree to its main
// checkout); the deepest such folder wins. No listed folder: no project.

const maxCodexProjectFile = 1 << 20

type codexProjects struct {
	roots                 []string
	projectless, assigned map[string]bool
}

var codexProjectTable = regexp.MustCompile(`^\s*\[\s*projects\s*\.\s*("(?:[^"\\]|\\.)*"|'[^']*')\s*\]\s*(?:#.*)?$`)

func codexHomeDir() string {
	if h := os.Getenv("CODEX_HOME"); h != "" {
		return h
	}
	if h, err := os.UserHomeDir(); err == nil {
		return filepath.Join(h, ".codex")
	}
	return ""
}

func loadCodexProjects() *codexProjects {
	c := &codexProjects{}
	home := codexHomeDir()
	if home == "" {
		return c
	}
	if b, ok := readCapped(filepath.Join(home, "config.toml")); ok {
		for _, line := range strings.Split(string(b), "\n") {
			m := codexProjectTable.FindStringSubmatch(strings.TrimRight(line, "\r"))
			if m == nil {
				continue
			}
			s := m[1]
			if s[0] == '"' {
				u, err := strconv.Unquote(s)
				if err != nil {
					continue
				}
				s = u
			} else {
				s = s[1 : len(s)-1]
			}
			c.add(s)
		}
	}
	if b, ok := readCapped(filepath.Join(home, ".codex-global-state.json")); ok {
		var st struct {
			Roots       []string                   `json:"electron-saved-workspace-roots"`
			Projectless []string                   `json:"projectless-thread-ids"`
			Assignments map[string]json.RawMessage `json:"thread-project-assignments"`
		}
		if json.Unmarshal(b, &st) == nil {
			for _, r := range st.Roots {
				c.add(r)
			}
			c.projectless, c.assigned = map[string]bool{}, map[string]bool{}
			for _, id := range st.Projectless {
				c.projectless[id] = true
			}
			for id := range st.Assignments {
				c.assigned[id] = true
			}
		}
	}
	return c
}

func (c *codexProjects) add(p string) {
	if !filepath.IsAbs(p) || len(p) > 4096 {
		return
	}
	p = filepath.Clean(p)
	if real, err := filepath.EvalSymlinks(p); err == nil {
		p = real
	}
	for _, r := range c.roots {
		if r == p {
			return
		}
	}
	c.roots = append(c.roots, p)
}

func within(dir, root string) bool {
	return dir == root || strings.HasPrefix(dir, strings.TrimRight(root, string(filepath.Separator))+string(filepath.Separator))
}

// lookup: the deepest listed Codex project folder containing a working directory (or its repository root),
// "" when none; skip names folders that are never projects (home, temp).
func (c *codexProjects) lookup(cwd string, skip func(string) bool) string {
	if c == nil || len(c.roots) == 0 || cwd == "" || len(cwd) > 4096 || !filepath.IsAbs(cwd) {
		return ""
	}
	dir := filepath.Clean(cwd)
	if real, err := filepath.EvalSymlinks(dir); err == nil {
		dir = real
	}
	cands := []string{dir}
	if g := gitRoot(dir); g != "" && g != dir {
		cands = append(cands, g)
	}
	best := ""
	for _, r := range c.roots {
		if skip != nil && skip(r) {
			continue
		}
		for _, d := range cands {
			if within(d, r) && len(r) > len(best) {
				best = r
			}
		}
	}
	return best
}

// independent: a thread the desktop lists as projectless and has not assigned to a project (CodexBar's
// CodexProjectlessWorkspaceMetadata): the only evidence of an independent chat. A missing id, an unlisted
// folder or a generated-looking name is not.
func (c *codexProjects) independent(thread string) bool {
	return c != nil && c.projectless[thread] && !c.assigned[thread]
}

func readCapped(p string) ([]byte, bool) {
	f, err := os.Open(p)
	if err != nil {
		return nil, false
	}
	defer f.Close()
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() {
		return nil, false
	}
	idlework.Open()
	b, err := io.ReadAll(idlework.Reader(io.LimitReader(f, maxCodexProjectFile+1)))
	if err != nil || len(b) > maxCodexProjectFile {
		return nil, false
	}
	idlework.Decode()
	return b, true
}

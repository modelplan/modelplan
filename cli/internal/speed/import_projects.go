// SPDX-License-Identifier: MIT
package speed

import (
	"path/filepath"
	"sort"
	"strings"
	"unicode"
	"unicode/utf8"
)

// HIST-IMP-10 (D168): imported history also keeps the project folder's name, as per-day sums.
// Only the last component of a turn's working directory is kept: never the path above it, a file
// name, a prompt, a reply or an id. The sums live in imported.json beside the imported rows, on
// this machine only, and go with them ("Remove imported history", a revoke of the history grant).

// ImportProject is one local day of one tool's turns in one project folder.
type ImportProject struct {
	Day    string `json:"day"`
	Source string `json:"source"`
	// Name is the folder's own name (the last path component), never a path.
	Name                 string      `json:"name"`
	ObservedOutputTokens int64       `json:"observedOutputTokens"`
	Turns                int         `json:"turns"`
	GrantEpoch           *GrantEpoch `json:"grantEpoch,omitempty"`
}

const (
	maxFolderName     = 200
	maxImportProjects = maxRows
)

type importProjectKey struct{ day, name string }

// FolderName is the last component of an absolute working directory, "" when there is none worth
// keeping (relative, root, too long, or holding control characters).
func FolderName(cwd string) string {
	if cwd == "" || len(cwd) > 4096 || !filepath.IsAbs(cwd) {
		return ""
	}
	name := filepath.Base(filepath.Clean(cwd))
	if name == "" || name == "." || name == string(filepath.Separator) || !utf8.ValidString(name) {
		return ""
	}
	if strings.IndexFunc(name, unicode.IsControl) >= 0 {
		return ""
	}
	if r := []rune(name); len(r) > maxFolderName {
		name = string(r[:maxFolderName])
	}
	return name
}

// addProject adds one read turn to the run's per-day, per-folder sums.
func (j *importJob) addProject(t turn) {
	if j.noProjects {
		return
	}
	name := FolderName(t.cwd)
	if name == "" {
		return
	}
	if j.projects == nil {
		j.projects = map[importProjectKey]*ImportProject{}
	}
	k := importProjectKey{day(t.at), name}
	p := j.projects[k]
	if p == nil {
		p = &ImportProject{Day: k.day, Source: j.source, Name: name}
		j.projects[k] = p
	}
	for _, q := range t.all {
		if q.cfg.model != "" {
			p.ObservedOutputTokens += q.out
		}
	}
	p.Turns++
}

// projectRows are the run's sums, oldest day first.
func (j *importJob) projectRows() []ImportProject {
	out := make([]ImportProject, 0, len(j.projects))
	for _, p := range j.projects {
		out = append(out, *p)
	}
	sort.Slice(out, func(a, b int) bool {
		if out[a].Day != out[b].Day {
			return out[a].Day < out[b].Day
		}
		return out[a].Name < out[b].Name
	})
	return out
}

// mergeProject adds a day's sums to the ledger's entry of the same day, tool and folder.
func (l *ImportLedger) mergeProject(p ImportProject) {
	for i := range l.Projects {
		x := &l.Projects[i]
		if x.Day == p.Day && x.Source == p.Source && x.Name == p.Name && sameEpoch(x.GrantEpoch, p.GrantEpoch) {
			x.ObservedOutputTokens += p.ObservedOutputTokens
			x.Turns += p.Turns
			return
		}
	}
	l.Projects = append(l.Projects, p)
}

// pruneProjects keeps the days the rows keep, and at most maxImportProjects entries (newest).
func (l *ImportLedger) pruneProjects(from string) {
	kept := l.Projects[:0]
	for _, p := range l.Projects {
		if p.Day >= from {
			kept = append(kept, p)
		}
	}
	sort.SliceStable(kept, func(i, j int) bool { return kept[i].Day < kept[j].Day })
	if len(kept) > maxImportProjects {
		kept = kept[len(kept)-maxImportProjects:]
	}
	l.Projects = kept
}

package speed

import (
	"bytes"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/modelplan/modelplan/cli/internal/profile"
)

// A session's project is the tool's own notion of a project, never ModelPlan's guess (owner
// decision G3-100; docs/personal-snapshot.md). It is known by an opaque reference: a keyed
// hash of the tool's project identity, with a random key kept beside the ledger
// (<cache>/observed/project-key), so the reference says nothing about the path and cannot be
// matched across machines. Per tool:
//   - Codex: the project folder Codex lists (a [projects."<path>"] table in config.toml, or a
//     saved workspace root of the desktop app) that contains the session's working directory or
//     its repository root; none when no such folder exists.
//   - Claude Code: the session's working directory, which is what names ~/.claude/projects/<dir>.
//     Worktrees and subfolders are projects of their own, as Claude shows them.
//   - OpenCode: the project row its session belongs to (its name, else its worktree's folder);
//     the "global" project is no project.
//   - ZCode: the session's project_id; its label is the folder name from ZCode's own session record
//     (ZCode stores no separate project name).
//   - Any other source: none.
//
// A session without a project carries an empty reference; the apps show "No project". The label
// is stored only while project labels are on: the default, until the user turns them off
// (`modelplan project-labels off`, which deletes the stored labels). Labels never leave the machine.

const maxProjects = 500

// ProjectLabelsFile is the user's choice, project-labels.json in the profile config folder.
func ProjectLabelsFile(home string) string {
	return profile.ConfigFile(home, "project-labels.json")
}

// ProjectLabels: project labels are on. They are on unless the user turned them off: without a
// file (no choice made) or a choice in it they are on, a stored choice is kept, and a file that
// cannot be read is off, since the choice in it is unknown.
func ProjectLabels(file string) bool {
	b, err := readSmall(file)
	if errors.Is(err, os.ErrNotExist) {
		return true
	}
	if err != nil {
		return false
	}
	var v struct {
		ProjectLabels *bool `json:"projectLabels"`
	}
	if json.Unmarshal(b, &v) != nil {
		return false
	}
	return v.ProjectLabels == nil || *v.ProjectLabels
}

// SetProjectLabels stores the user's choice. Turning labels off also deletes the labels the ledger
// holds.
func SetProjectLabels(file, cache string, on bool) error {
	if err := os.MkdirAll(filepath.Dir(file), 0o700); err != nil {
		return err
	}
	b, _ := json.MarshalIndent(map[string]any{"schemaVersion": 1, "projectLabels": on}, "", "  ")
	if err := write(file, append(b, '\n')); err != nil {
		return err
	}
	if on {
		return nil
	}
	return ClearProjectLabels(cache)
}

// ClearProjectLabels removes every stored project label from perf.json; the references stay.
func ClearProjectLabels(cache string) error {
	unlock, ok := lock(cache, "perf.lock")
	if !ok {
		return errors.New("perf.json is busy; try again")
	}
	defer unlock()
	l, ok := LoadPerf(cache)
	if !ok || l.Since.IsZero() {
		return nil // nothing of ours to change
	}
	changed := false
	for i := range l.Sessions {
		if l.Sessions[i].ProjectLabel != "" {
			l.Sessions[i].ProjectLabel, changed = "", true
		}
	}
	for i := range l.Live {
		if l.Live[i].ProjectLabel != "" {
			l.Live[i].ProjectLabel, changed = "", true
		}
	}
	if !changed {
		return nil
	}
	b, _ := json.Marshal(l)
	return write(PerfPath(cache), append(b, '\n'))
}

// nativeProject is a project a tool's own store names for a session (OpenCode, ZCode).
type nativeProject struct{ ID, Name string }

// projector names a session's project: its reference and, with labels on, its label. Nil when the
// key cannot be read or made; sessions then carry no project.
func projector(cache string, labels bool) func(source, cwd string, np nativeProject) (ref, label string) {
	key := projectKey(cache)
	if key == nil {
		return nil
	}
	var codex *codexProjects
	return func(source, cwd string, np nativeProject) (string, string) {
		var id, name string
		switch source {
		case "claude-code":
			id, name = cwdProject(cwd)
		case "codex":
			if codex == nil {
				codex = loadCodexProjects()
			}
			id, name = codex.lookup(cwd)
		case "opencode":
			if np.ID != "" && np.ID != "global" {
				id, name = "opencode:"+np.ID, nativeLabel(np.Name)
			}
		case "zcode":
			if np.ID != "" && np.ID != "global" {
				// ZCode stores no project name; its own record of the session folder gives the folder name.
				id, name = "zcode:"+np.ID, nativeLabel(cwd)
			}
		}
		if id == "" {
			return "", ""
		}
		m := hmac.New(sha256.New, key)
		m.Write([]byte(id))
		ref := hex.EncodeToString(m.Sum(nil)[:16])
		if !labels {
			name = ""
		}
		return ref, name
	}
}

// nativeLabel: a project's name, or the folder name when the tool only stores a path.
func nativeLabel(s string) string {
	s = strings.TrimSpace(s)
	if strings.ContainsAny(s, `/\`) {
		s = filepath.Base(filepath.Clean(s))
	}
	if len(s) > 200 {
		s = s[:200]
	}
	return s
}

func projectKeyPath(cache string) string { return filepath.Join(cache, "observed", "project-key") }

// projectKey reads the ledger's project key, making it on first use.
func projectKey(cache string) []byte {
	p := projectKeyPath(cache)
	if b, err := readSmall(p); err == nil {
		if k, err := hex.DecodeString(strings.TrimSpace(string(b))); err == nil && len(k) == 32 {
			return k
		}
		return nil // not ours to replace: every reference would change
	}
	k := make([]byte, 32)
	if _, err := rand.Read(k); err != nil {
		return nil
	}
	if os.MkdirAll(filepath.Dir(p), 0o700) != nil {
		return nil
	}
	f, err := os.OpenFile(p, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600)
	if err != nil {
		if b, err := readSmall(p); err == nil { // made by another run just now
			if k, err := hex.DecodeString(strings.TrimSpace(string(b))); err == nil && len(k) == 32 {
				return k
			}
		}
		return nil
	}
	_, err = f.WriteString(hex.EncodeToString(k) + "\n")
	if f.Close() != nil || err != nil {
		return nil
	}
	return k
}

// cwdProject: Claude Code's project, the session's working directory. "" for one that is not
// absolute.
func cwdProject(cwd string) (id, name string) {
	if cwd == "" || len(cwd) > 4096 || !filepath.IsAbs(cwd) {
		return "", ""
	}
	dir := filepath.Clean(cwd)
	return "cwd:" + dir, filepath.Base(dir)
}

// gitRoot: the folder of the checkout's repository (the one holding the common .git directory)
// that a working directory belongs to, "" when it is in none. Found by reading .git files.
func gitRoot(cwd string) string {
	dir := filepath.Clean(cwd)
	if real, err := filepath.EvalSymlinks(dir); err == nil {
		dir = real
	}
	for d, i := dir, 0; i < 64; i++ {
		if common := gitCommonDir(d); common != "" {
			if filepath.Base(common) == ".git" {
				return filepath.Dir(common)
			}
			return d
		}
		up := filepath.Dir(d)
		if up == d {
			break
		}
		d = up
	}
	return ""
}

// gitCommonDir: the repository's common git directory for a checkout rooted at dir, from its
// .git directory or its .git file (a worktree or submodule) and the commondir file there. "" when
// dir holds no usable .git.
func gitCommonDir(dir string) string {
	g := filepath.Join(dir, ".git")
	fi, err := os.Lstat(g)
	if err != nil {
		return ""
	}
	gitdir := g
	if fi.Mode().IsRegular() {
		b, err := readSmall(g)
		if err != nil {
			return ""
		}
		rest, ok := strings.CutPrefix(strings.TrimSpace(string(b)), "gitdir:")
		if !ok {
			return ""
		}
		gitdir = strings.TrimSpace(rest)
		if !filepath.IsAbs(gitdir) {
			gitdir = filepath.Join(dir, gitdir)
		}
	} else if !fi.IsDir() {
		return ""
	}
	common := gitdir
	if b, err := readSmall(filepath.Join(gitdir, "commondir")); err == nil {
		if c := strings.TrimSpace(string(b)); c != "" {
			if !filepath.IsAbs(c) {
				c = filepath.Join(gitdir, c)
			}
			common = c
		}
	}
	real, err := filepath.EvalSymlinks(common)
	if err != nil {
		return ""
	}
	if fi, err := os.Stat(real); err != nil || !fi.IsDir() {
		return ""
	}
	return real
}

// readSmall reads a regular file of at most 4 KiB.
func readSmall(p string) ([]byte, error) {
	f, err := os.Open(p)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() {
		return nil, errors.New("not a regular file")
	}
	b, err := io.ReadAll(io.LimitReader(f, 4<<10+1))
	if err != nil || len(b) > 4<<10 {
		return nil, errors.New("too large")
	}
	return bytes.TrimRight(b, "\x00"), nil
}

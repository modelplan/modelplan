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
)

// A session's project is known by an opaque reference: a keyed hash of its project root, with a
// random key kept beside the ledger (<cache>/observed/project-key), so the reference says nothing
// about the path and cannot be matched across machines. The root is the repository's git common
// directory when the session's working directory is inside a checkout or worktree that still
// exists, so worktrees of one repository are one project; otherwise the working directory itself.
// It is found by reading .git files, never by running git. The label (the root folder's name) is
// stored only while the user has turned project labels on (`modelplan project-labels on`).

const maxProjects = 500

// ProjectLabelsFile is the opt-in, ~/.config/modelplan/project-labels.json.
func ProjectLabelsFile(home string) string {
	return filepath.Join(home, ".config", "modelplan", "project-labels.json")
}

// ProjectLabels: the user turned project labels on. A missing or unreadable file is off.
func ProjectLabels(file string) bool {
	b, err := readSmall(file)
	if err != nil {
		return false
	}
	var v struct {
		ProjectLabels bool `json:"projectLabels"`
	}
	return json.Unmarshal(b, &v) == nil && v.ProjectLabels
}

// SetProjectLabels writes the opt-in. Turning it off also deletes the labels the ledger holds.
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
	if !changed {
		return nil
	}
	b, _ := json.Marshal(l)
	return write(PerfPath(cache), append(b, '\n'))
}

// projector names a working directory's project: its reference and, with labels on, its label.
// Nil when the key cannot be read or made; sessions then carry no project.
func projector(cache string, labels bool) func(cwd string) (ref, label string) {
	key := projectKey(cache)
	if key == nil {
		return nil
	}
	return func(cwd string) (string, string) {
		id, name := projectRoot(cwd)
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

// projectRoot: the identity a project reference hashes, and the root folder's name. "" for a
// working directory that is not absolute.
func projectRoot(cwd string) (id, name string) {
	if cwd == "" || len(cwd) > 4096 || !filepath.IsAbs(cwd) {
		return "", ""
	}
	dir := filepath.Clean(cwd)
	real, err := filepath.EvalSymlinks(dir)
	if err != nil {
		return "cwd:" + dir, filepath.Base(dir) // gone since: the directory as written
	}
	dir = real
	for d, i := dir, 0; i < 64; i++ {
		if common := gitCommonDir(d); common != "" {
			return "git:" + common, repoName(common, d)
		}
		up := filepath.Dir(d)
		if up == d {
			break
		}
		d = up
	}
	return "cwd:" + dir, filepath.Base(dir)
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

// repoName: the folder that holds the common directory (…/repo/.git), else the checkout's own.
func repoName(common, checkout string) string {
	if filepath.Base(common) == ".git" {
		return filepath.Base(filepath.Dir(common))
	}
	if n := strings.TrimSuffix(filepath.Base(common), ".git"); n != "" && n != filepath.Base(common) {
		return n
	}
	return filepath.Base(checkout)
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

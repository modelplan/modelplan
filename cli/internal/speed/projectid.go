package speed

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Project resolution (owner decision D470, replacing G3-100). A session's project is where the work
// lives, resolved in this order; the first match wins:
//
//  1. The git repository root, with linked worktrees merged into their main checkout (the commondir
//     rule of Token Monitor's projectRoot.js). A worktree whose main checkout is gone resolves through
//     a remembered mapping (project-roots.json, capped like Token Monitor's). A working directory that no
//     longer exists is never walked up to an unrelated parent repository (CodexBar's rule).
//  2. A workspace the tool names: a Codex project folder (never home, a temp folder or a projectless
//     chat folder), ZCode's project_id, an OpenCode project row other than "global".
//  3. A bucket: independent chats (a Codex thread in projectless-thread-ids with no project assignment,
//     as CodexBar's CodexProjectlessWorkspaceMetadata decides), the home folder, or none.
//
// The label is the identity folder's basename; a generic basename takes the origin remote's name instead.
// A thread title, a UUID or the home folder's name is never a label: such a project falls to a bucket.
// An identity is a full path used only inside the keyed hash; it is never stored or published.

// Project kinds, as published (the desktop words them).
const (
	KindRepo        = "repo"
	KindWorkspace   = "workspace"
	KindIndependent = "independent"
	KindHome        = "home"
	KindNone        = "none"
)

// projectInfo is a resolved project: the keyed reference, the label (basename only, empty for a bucket or
// while labels are off) and the kind.
type projectInfo struct{ Ref, Label, Kind string }

const maxRememberedRoots = 2000

var (
	uuidInName = regexp.MustCompile(`(?i)[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}`)
	hexName    = regexp.MustCompile(`(?i)^[0-9a-f]{8,}$`)
	t3Name     = regexp.MustCompile(`(?i)^t3-[0-9a-f]{6,}$`)
	genericDir = map[string]bool{"repo": true, "src": true, "app": true, "code": true, "work": true, "project": true,
		"main": true, "master": true, "workspace": true, "checkout": true}
)

// uuidLike: a name that is an identifier, never a project name.
func uuidLike(name string) bool {
	return uuidInName.MatchString(name) || hexName.MatchString(name) || t3Name.MatchString(name)
}

func genericName(name string) bool { return genericDir[strings.ToLower(name)] || uuidLike(name) }

// originName: the last path part of the origin remote in a repository's git config, ".git" stripped; "" when
// there is none. It reads a file; git is never run.
func originName(commonGitDir string) string {
	b, ok := readCapped(filepath.Join(commonGitDir, "config"))
	if !ok {
		return ""
	}
	in := false
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "[") {
			in = strings.HasPrefix(strings.ReplaceAll(line, " ", ""), `[remote"origin"]`)
			continue
		}
		if !in {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok || strings.TrimSpace(k) != "url" {
			continue
		}
		v = strings.TrimSuffix(strings.TrimRight(strings.TrimSpace(v), "/"), ".git")
		if i := strings.LastIndexAny(v, "/:\\"); i >= 0 {
			v = v[i+1:]
		}
		if v != "" && len(v) <= 100 && !uuidLike(v) {
			return v
		}
	}
	return ""
}

// slug: a title as a chat slug, for the guard against a label that is the thread's own title.
func slug(s string) string {
	var b strings.Builder
	dash := true
	for _, r := range strings.ToLower(s) {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' || r > 127 {
			b.WriteRune(r)
			dash = false
		} else if !dash {
			b.WriteByte('-')
			dash = true
		}
	}
	return strings.Trim(b.String(), "-")
}

type projectResolver struct {
	key         []byte
	labels      bool
	home        string
	user        string
	temps       []string
	codex       *codexProjects
	rememberAt  string
	remembered  [][2]string
	rememberSet map[string]int
	dirty       bool
}

func newProjectResolver(cache string, key []byte, labels bool) *projectResolver {
	r := &projectResolver{key: key, labels: labels, rememberAt: filepath.Join(cache, "observed", "project-roots.json")}
	if h, err := os.UserHomeDir(); err == nil && filepath.IsAbs(h) {
		r.home = filepath.Clean(h)
		if real, err := filepath.EvalSymlinks(r.home); err == nil {
			r.home = real
		}
		r.user = strings.ToLower(filepath.Base(r.home))
	}
	for _, t := range []string{os.TempDir(), "/tmp", "/var/tmp", "/private/tmp", "/private/var/folders", "/var/folders"} {
		t = filepath.Clean(t)
		r.temps = append(r.temps, t)
		if real, err := filepath.EvalSymlinks(t); err == nil && real != t {
			r.temps = append(r.temps, real)
		}
	}
	return r
}

func (r *projectResolver) ref(id string) string {
	m := hmac.New(sha256.New, r.key)
	m.Write([]byte(id))
	return hex.EncodeToString(m.Sum(nil)[:16])
}

func (r *projectResolver) bucket(kind string) projectInfo {
	return projectInfo{Ref: r.ref("bucket:" + kind), Kind: kind}
}

// isTempRoot: a temp base folder itself (never a workspace); a folder inside one may be listed by the user.
func (r *projectResolver) isTempRoot(dir string) bool {
	if dir == "/" {
		return true
	}
	for _, t := range r.temps {
		if dir == t {
			return true
		}
	}
	return false
}

// homeBucket: the home folder itself, or a folder directly under it.
func (r *projectResolver) homeBucket(dir string) bool {
	return r.home != "" && (dir == r.home || filepath.Dir(dir) == r.home)
}

// label: the folder's label under the naming rules, "" when the rules reject it (the caller then uses a bucket).
func (r *projectResolver) label(dir, commonGit, title string) string {
	name := filepath.Base(dir)
	if genericName(name) {
		if o := originName(commonGit); o != "" {
			name = o
		}
	}
	low := strings.ToLower(name)
	if name == "" || name == "." || name == string(filepath.Separator) || uuidLike(name) || low == r.user ||
		title != "" && (low == strings.ToLower(strings.TrimSpace(title)) || low == slug(title)) {
		return ""
	}
	if len(name) > 200 {
		name = name[:200]
	}
	return name
}

func (r *projectResolver) load() {
	if r.rememberSet != nil {
		return
	}
	r.rememberSet = map[string]int{}
	if b, ok := readCapped(r.rememberAt); ok {
		var pairs [][2]string
		if json.Unmarshal(b, &pairs) == nil {
			for _, p := range pairs {
				if len(r.remembered) < maxRememberedRoots && filepath.IsAbs(p[0]) && filepath.IsAbs(p[1]) {
					r.rememberSet[p[0]] = len(r.remembered)
					r.remembered = append(r.remembered, p)
				}
			}
		}
	}
}

func (r *projectResolver) remember(dir, root string) {
	r.load()
	if i, ok := r.rememberSet[dir]; ok && r.remembered[i][1] == root {
		return
	}
	if i, ok := r.rememberSet[dir]; ok {
		r.remembered[i][1] = root
	} else {
		if len(r.remembered) >= maxRememberedRoots {
			delete(r.rememberSet, r.remembered[0][0])
			r.remembered = r.remembered[1:]
			for i, p := range r.remembered {
				r.rememberSet[p[0]] = i
			}
		}
		r.rememberSet[dir] = len(r.remembered)
		r.remembered = append(r.remembered, [2]string{dir, root})
	}
	r.dirty = true
}

// recall: the repository a gone worktree (or a folder inside one) was remembered under.
func (r *projectResolver) recall(dir string) string {
	r.load()
	for d, i := dir, 0; i < 64; i++ {
		if j, ok := r.rememberSet[d]; ok {
			return r.remembered[j][1]
		}
		up := filepath.Dir(d)
		if up == d {
			break
		}
		d = up
	}
	return ""
}

// save writes the remembered mappings once, after a run.
func (r *projectResolver) save() {
	if !r.dirty {
		return
	}
	r.dirty = false
	if os.MkdirAll(filepath.Dir(r.rememberAt), 0o700) != nil {
		return
	}
	b, _ := json.Marshal(r.remembered)
	_ = write(r.rememberAt, append(b, '\n'))
}

// resolve names a session's project. cwd "" with no native project resolves to no reference at all: nothing
// is known about it.
func (r *projectResolver) resolve(source, cwd string, np nativeProject) projectInfo {
	if source == "codex" && np.Thread != "" {
		if r.codex == nil {
			r.codex = loadCodexProjects()
		}
		if r.codex.independent(np.Thread) {
			return r.bucket(KindIndependent)
		}
	}
	dir := ""
	if cwd != "" && len(cwd) <= 4096 && filepath.IsAbs(cwd) {
		dir = filepath.Clean(cwd)
	}
	if dir == "" && np.ID == "" {
		return projectInfo{}
	}
	if dir != "" {
		if info, ok := r.byRepo(dir, np); ok {
			return info
		}
	}
	if info, ok := r.byWorkspace(source, dir, np); ok {
		return info
	}
	switch {
	case dir != "" && r.homeBucket(dir):
		return r.bucket(KindHome)
	}
	return r.bucket(KindNone)
}

func (r *projectResolver) named(id, label, kind string) projectInfo {
	info := projectInfo{Ref: r.ref(id), Kind: kind}
	if r.labels {
		info.Label = label
	}
	return info
}

// byRepo: step 1.
func (r *projectResolver) byRepo(dir string, np nativeProject) (projectInfo, bool) {
	real, err := filepath.EvalSymlinks(dir)
	if err != nil {
		// A folder that no longer exists: its remembered repository, else its own name. Never an
		// unrelated parent repository.
		if root := r.recall(dir); root != "" {
			return r.repo(root, np)
		}
		if r.homeBucket(dir) {
			return projectInfo{}, false
		}
		if l := r.label(dir, "", np.Title); l != "" {
			return r.named("cwd:"+dir, l, KindWorkspace), true
		}
		return r.bucket(KindNone), true
	}
	root := gitRoot(real)
	if root == "" || root == r.home {
		return projectInfo{}, false
	}
	if root != real {
		if g := filepath.Join(real, ".git"); fileExists(g) {
			r.remember(dir, root)
		}
	}
	return r.repo(root, np)
}

func fileExists(p string) bool {
	fi, err := os.Lstat(p)
	return err == nil && fi.Mode().IsRegular()
}

func (r *projectResolver) repo(root string, np nativeProject) (projectInfo, bool) {
	l := r.label(root, filepath.Join(root, ".git"), np.Title)
	if l == "" {
		return r.bucket(KindNone), true
	}
	return r.named("repo:"+root, l, KindRepo), true
}

// byWorkspace: step 2.
func (r *projectResolver) byWorkspace(source, dir string, np nativeProject) (projectInfo, bool) {
	switch source {
	case "codex":
		if dir == "" {
			return projectInfo{}, false
		}
		if r.codex == nil {
			r.codex = loadCodexProjects()
		}
		root := r.codex.lookup(dir, func(p string) bool { return p == r.home || r.isTempRoot(p) })
		if root == "" {
			return projectInfo{}, false
		}
		if l := r.label(root, "", np.Title); l != "" {
			return r.named("codex:"+root, l, KindWorkspace), true
		}
		return r.bucket(KindNone), true
	case "opencode":
		if np.ID != "" && np.ID != "global" {
			return r.named("opencode:"+np.ID, r.labelOf(nativeLabel(np.Name), np.Title), KindWorkspace), true
		}
	case "zcode":
		if np.ID != "" && np.ID != "global" {
			// ZCode stores no project name; its own record of the session folder gives the folder name.
			return r.named("zcode:"+np.ID, r.labelOf(nativeLabel(dir), np.Title), KindWorkspace), true
		}
	}
	return projectInfo{}, false
}

// labelOf applies the guards to a name the tool gave.
func (r *projectResolver) labelOf(name, title string) string {
	low := strings.ToLower(name)
	if name == "" || uuidLike(name) || low == r.user || title != "" && (low == strings.ToLower(strings.TrimSpace(title)) || low == slug(title)) {
		return ""
	}
	return name
}

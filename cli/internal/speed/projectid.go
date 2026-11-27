package speed

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
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
	remembered  []rememberedRoot
	rememberSet map[string]int
	dirty       bool
}

// rememberedRoot: a linked worktree's checkout remembered under its repository, so its history keeps the
// repository after the worktree is removed. Every field is keyed or a label (macrevb-1299-5): Dir is the keyed
// hash of the worktree's top folder, Ref the repository's reference, Kind its kind; Label is kept only while
// project labels are on. No path is stored; the file is not written while labels are off and is deleted when
// they are turned off.
type rememberedRoot struct {
	Dir   string `json:"d"`
	Ref   string `json:"r"`
	Kind  string `json:"k"`
	Label string `json:"l,omitempty"`
}

// rememberFile: the remembered worktrees. legacyRememberFile held absolute paths (an earlier build of D470) and is
// removed on sight.
const (
	rememberFile       = "project-worktrees.json"
	legacyRememberFile = "project-roots.json"
)

func rememberPath(cache string) string { return filepath.Join(cache, "observed", rememberFile) }

// forgetRemembered deletes the remembered worktrees (project labels turned off).
func forgetRemembered(cache string) error {
	var errs []error
	for _, name := range []string{rememberFile, legacyRememberFile} {
		if err := os.Remove(filepath.Join(cache, "observed", name)); err != nil && !os.IsNotExist(err) {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}

func newProjectResolver(cache string, key []byte, labels bool) *projectResolver {
	r := &projectResolver{key: key, labels: labels, rememberAt: rememberPath(cache)}
	if labels {
		_ = os.Remove(filepath.Join(cache, "observed", legacyRememberFile))
	} else {
		_ = forgetRemembered(cache) // however labels were turned off, what was remembered goes
	}
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

var hexRef = regexp.MustCompile(`^[0-9a-f]{32}$`)

func (r *projectResolver) load() {
	if r.rememberSet != nil {
		return
	}
	r.rememberSet = map[string]int{}
	if b, ok := readCapped(r.rememberAt); ok {
		var entries []rememberedRoot
		if json.Unmarshal(b, &entries) == nil {
			for _, e := range entries {
				if len(r.remembered) >= maxRememberedRoots || !hexRef.MatchString(e.Dir) || !hexRef.MatchString(e.Ref) || (e.Kind != KindRepo && e.Kind != KindNone) {
					continue
				}
				if !r.labels || strings.ContainsAny(e.Label, `/\`) {
					e.Label = ""
				}
				if _, dup := r.rememberSet[e.Dir]; !dup {
					r.rememberSet[e.Dir] = len(r.remembered)
					r.remembered = append(r.remembered, e)
				}
			}
		}
	}
}

// remember keeps a linked worktree's top folder (top) under its repository's resolved project.
func (r *projectResolver) remember(top string, info projectInfo) {
	r.load()
	e := rememberedRoot{Dir: r.ref("dir:" + top), Ref: info.Ref, Kind: info.Kind, Label: info.Label}
	if i, ok := r.rememberSet[e.Dir]; ok {
		if r.remembered[i] != e {
			r.remembered[i], r.dirty = e, true
		}
		return
	}
	if len(r.remembered) >= maxRememberedRoots {
		delete(r.rememberSet, r.remembered[0].Dir)
		r.remembered = r.remembered[1:]
		for i, p := range r.remembered {
			r.rememberSet[p.Dir] = i
		}
	}
	r.rememberSet[e.Dir] = len(r.remembered)
	r.remembered = append(r.remembered, e)
	r.dirty = true
}

// recall: the project a gone worktree (or a folder inside one) was remembered under.
func (r *projectResolver) recall(dir string) (projectInfo, bool) {
	r.load()
	for d, i := dir, 0; i < 64; i++ {
		if j, ok := r.rememberSet[r.ref("dir:"+d)]; ok {
			e := r.remembered[j]
			info := projectInfo{Ref: e.Ref, Kind: e.Kind}
			if r.labels {
				info.Label = e.Label
			}
			return info, true
		}
		up := filepath.Dir(d)
		if up == d {
			break
		}
		d = up
	}
	return projectInfo{}, false
}

// save writes the remembered worktrees once, after a run. Never while labels are off: nothing about a project
// beyond the ledger's own references is kept then.
func (r *projectResolver) save() {
	if !r.dirty || !r.labels {
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
// is known about it. The repository comes first for every tool (macrevb-1299-2): a Codex thread listed as
// projectless is an independent chat only when its folder is in no repository.
func (r *projectResolver) resolve(source, cwd string, np nativeProject) projectInfo {
	dir := ""
	if cwd != "" && len(cwd) <= 4096 && filepath.IsAbs(cwd) {
		dir = filepath.Clean(cwd)
	}
	gone := false
	if dir != "" {
		info, ok, exists := r.byRepo(dir, np)
		if ok {
			return info
		}
		gone = !exists
	}
	if source == "codex" && np.Thread != "" {
		if r.codex == nil {
			r.codex = loadCodexProjects()
		}
		if r.codex.independent(np.Thread) {
			return r.bucket(KindIndependent)
		}
	}
	if dir == "" && np.ID == "" {
		return projectInfo{}
	}
	if gone && !r.homeBucket(dir) {
		// A folder that no longer exists and was not remembered: its own name. Never an unrelated parent
		// repository.
		if l := r.label(dir, "", np.Title); l != "" {
			return r.named("cwd:"+dir, l, KindWorkspace)
		}
		return r.bucket(KindNone)
	}
	if info, ok := r.byWorkspace(source, dir, np); ok {
		return info
	}
	if dir != "" && r.homeBucket(dir) {
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

// byRepo: step 1. exists reports whether dir is still there.
func (r *projectResolver) byRepo(dir string, np nativeProject) (info projectInfo, ok, exists bool) {
	real, err := filepath.EvalSymlinks(dir)
	if err != nil {
		// A folder that no longer exists: the repository its worktree was remembered under.
		info, ok := r.recall(dir)
		return info, ok, false
	}
	top, root := gitCheckout(real)
	if root == "" || root == r.home {
		return projectInfo{}, false, true
	}
	info, _ = r.repo(root, np)
	if top != root {
		// A linked worktree: its top folder is remembered, so any folder inside it keeps the repository after the
		// worktree is removed (macrevb-1299-3). Both spellings, as observed and resolved, are kept.
		r.remember(top, info)
		if rel, err := filepath.Rel(real, top); err == nil {
			if obs := filepath.Clean(filepath.Join(dir, rel)); obs != top {
				r.remember(obs, info)
			}
		}
	}
	return info, true, true
}

// gitCheckout: the top folder of the checkout a folder is in and its repository root (gitRoot); the two differ
// for a linked worktree. "" when the folder is in no checkout.
func gitCheckout(dir string) (top, root string) {
	for d, i := dir, 0; i < 64; i++ {
		if common := gitCommonDir(d); common != "" {
			if filepath.Base(common) == ".git" {
				return d, filepath.Dir(common)
			}
			return d, d
		}
		up := filepath.Dir(d)
		if up == d {
			break
		}
		d = up
	}
	return "", ""
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

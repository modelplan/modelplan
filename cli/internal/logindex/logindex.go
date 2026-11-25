// SPDX-License-Identifier: MIT

// Package logindex keeps the app-server's one in-memory inventory of the admitted local history
// roots (Claude Code projects, Codex sessions, ZCode CLI logs). The activity observer, the
// Codex rollout selection and the 30-second observation pass share it, so the engine pays for
// discovery once per root instead of once per caller (D397, energy plan item 2).
//
// After the first scan of a root nothing is enumerated again unless a directory changed. Every
// HotInterval the inventory stats the root, its immediate children, the newest-named directory
// chain and whatever changed within HotWindow, and re-lists only the directories whose
// metadata moved. Every ColdInterval it reconciles the whole root by metadata: one stat per
// known directory and file, which also finds an append to an old log (a resumed session). So
// idle discovery costs stats, never directory listings, and a new log is found within
// HotInterval in a hot directory and within ColdInterval anywhere else.
//
// A root retains every directory and .jsonl file under it, with no entry bound: a bound would
// leave a resumed log outside the retained set, which no stat can find and only a relisting
// could (macrevb-1222-1). Memory is what bounds it instead: a retained log costs its path and a
// 24-byte stamp, about 100 bytes, so 100,000 logs cost about 10 MB. Other entries are listed
// at a directory's (re)listing but never kept.
//
// It holds only paths and file metadata of the roots its callers are admitted to, in memory. A
// new consent fence discards everything, and Drop or Clear forgets a root at once. It never
// opens a file: a caller rechecks consent and file identity before any content read.
package logindex

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/idlework"
)

const (
	// HotInterval paces the metadata check of the directories where new logs appear.
	HotInterval = 6 * time.Second
	// ColdInterval paces the metadata reconciliation of a whole root.
	ColdInterval = 30 * time.Second
	// HotWindow keeps a directory or file hot after it last changed.
	HotWindow = time.Hour
	// unused drops a root no caller asked for within this time.
	unused = 5 * time.Minute
	// racyWindow: a directory modified this close to its listing may change again within the
	// same timestamp tick (coarse kernel clocks, 1 s on some file systems), so it is listed
	// again at its next check instead of being trusted by its stamp.
	racyWindow = 2 * time.Second
)

// Root is one admitted history directory and the source its logs belong to.
type Root struct {
	Dir, Source string
}

// File is one regular .jsonl file under a root, with the metadata of its last stat.
type File struct {
	Path, Source string
	Depth        int // path elements below the root: 1 for a file directly in it
	Size         int64
	Mod          time.Time
}

// Inventory is safe for concurrent use. The zero value is ready.
type Inventory struct {
	mu    sync.Mutex
	fence consent.Fence
	roots map[Root]*root
	// gen moves whenever what Files would return may have changed: a root (re)listed, a retained
	// file's stamp changed or gone, a root added, dropped or evicted, a new fence. Callers cache
	// what they select from the files under it (FilesIfChanged), so an idle tick copies nothing.
	gen uint64
	// retired: store epochs a newer fence replaced. A call under a retired epoch, or under an
	// older generation of the current one, is refused: it reads nothing and writes nothing, so a
	// call that captured its admission before a withdrawal cannot rebuild what the withdrawal
	// discarded (macrev2-1261-2).
	retired map[string]bool
}

// stale: f is older than the inventory's fence. Caller holds mu.
func (inv *Inventory) stale(f consent.Fence) bool {
	if inv.retired[f.StoreEpoch] {
		return true
	}
	return f.StoreEpoch == inv.fence.StoreEpoch && f.Generation < inv.fence.Generation
}

// advance moves the inventory to fence f, discarding every root, unless f is its fence already
// or older. It reports whether f may be used. Caller holds mu.
func (inv *Inventory) advance(f consent.Fence) bool {
	if inv.fence == f {
		if inv.roots == nil {
			inv.roots = map[Root]*root{}
		}
		return true
	}
	if inv.stale(f) {
		return false
	}
	if inv.fence.StoreEpoch != "" && inv.fence.StoreEpoch != f.StoreEpoch {
		if inv.retired == nil {
			inv.retired = map[string]bool{}
		}
		inv.retired[inv.fence.StoreEpoch] = true
	}
	inv.roots, inv.fence = map[Root]*root{}, f
	inv.gen++
	return true
}

// Advance moves the inventory to a newer consent fence, discarding everything it holds, so no
// call under an older fence can read or rebuild it afterwards. A withdrawal calls it with the
// fence that withdrew. An older or equal fence changes nothing.
func (inv *Inventory) Advance(f consent.Fence) {
	inv.mu.Lock()
	defer inv.mu.Unlock()
	if inv.gen == 0 {
		inv.gen = 1
	}
	inv.advance(f)
}

// Retained counts the files the inventory holds (tests and diagnostics; no path leaves).
func (inv *Inventory) Retained() int {
	inv.mu.Lock()
	defer inv.mu.Unlock()
	n := 0
	for _, r := range inv.roots {
		n += len(r.files)
	}
	return n
}

type root struct {
	dirty         bool // something Files returns changed since the inventory's gen last moved
	dirs          map[string]*dirState
	files         map[string]fileState
	hotAt, coldAt time.Time
	usedAt        time.Time
	now           time.Time // wall time of the current refresh
}

type dirState struct {
	info    os.FileInfo
	depth   int
	racy    bool     // listed within racyWindow of its modification
	subdirs []string // newest name first
	files   []string
}

// fileState is a retained file's last stat, kept compact: a root may hold many of them.
type fileState struct {
	size  int64
	mod   int64 // UnixNano
	depth int32
}

func stateOf(info os.FileInfo, depth int) fileState {
	return fileState{size: info.Size(), mod: info.ModTime().UnixNano(), depth: int32(depth)}
}

func (f fileState) modTime() time.Time { return time.Unix(0, f.mod) }

// Files returns the .jsonl files under the given roots, refreshing each root by its own
// schedule: a full scan the first time, a metadata reconciliation every ColdInterval and a hot
// check every HotInterval of elapsed (a monotonic clock). now is the wall time that decides
// what is recent. A root that is not absolute is ignored.
func (inv *Inventory) Files(fence consent.Fence, roots []Root, now, elapsed time.Time) []File {
	files, _, _ := inv.FilesIfChanged(fence, roots, now, elapsed, 0)
	return files
}

// FilesIfChanged is Files for a caller that caches what it selects from the files. A call under a
// fence older than the inventory's is refused with gen 0: the caller keeps nothing. It refreshes
// the roots as Files does and returns the inventory's generation. When that generation is still
// have (from an earlier call with the same fence and roots), nothing can have changed and it
// returns no files and changed=false without copying anything. have 0 always copies.
func (inv *Inventory) FilesIfChanged(fence consent.Fence, roots []Root, now, elapsed time.Time, have uint64) (files []File, gen uint64, changed bool) {
	inv.mu.Lock()
	defer inv.mu.Unlock()
	if inv.gen == 0 {
		inv.gen = 1
	}
	if !inv.advance(fence) {
		return nil, 0, true // an older fence: refused, nothing read or kept (gen 0)
	}
	for key, r := range inv.roots {
		if elapsed.Sub(r.usedAt) > unused {
			delete(inv.roots, key)
			inv.gen++
		}
	}
	var refreshed []*root
	var out []File
	for _, want := range roots {
		if want.Dir == "" || !filepath.IsAbs(want.Dir) {
			continue
		}
		want.Dir = filepath.Clean(want.Dir)
		r := inv.roots[want]
		if r != nil {
			r.now = now
		}
		switch {
		case r == nil:
			r = &root{now: now}
			inv.roots[want] = r
			r.scan(want.Dir, elapsed)
		case due(r.coldAt, elapsed, ColdInterval):
			r.reconcile(want.Dir, now, elapsed, true)
		case due(r.hotAt, elapsed, HotInterval):
			r.reconcile(want.Dir, now, elapsed, false)
		}
		r.usedAt = elapsed
		if r.dirty {
			r.dirty = false
			inv.gen++
		}
		refreshed = append(refreshed, r)
	}
	if have != 0 && have == inv.gen {
		return nil, inv.gen, false
	}
	for i, want := range validRoots(roots) {
		r := refreshed[i]
		idlework.Copied(len(r.files))
		for path, f := range r.files {
			out = append(out, File{Path: path, Source: want.Source, Depth: int(f.depth), Size: f.size, Mod: f.modTime()})
		}
	}
	return out, inv.gen, true
}

// validRoots: the roots Files refreshes, in order, cleaned.
func validRoots(roots []Root) []Root {
	var out []Root
	for _, want := range roots {
		if want.Dir == "" || !filepath.IsAbs(want.Dir) {
			continue
		}
		want.Dir = filepath.Clean(want.Dir)
		out = append(out, want)
	}
	return out
}

// Drop forgets one root at once (its admission was withdrawn).
func (inv *Inventory) Drop(dir string) {
	inv.mu.Lock()
	defer inv.mu.Unlock()
	dir = filepath.Clean(dir)
	for key := range inv.roots {
		if key.Dir == dir {
			delete(inv.roots, key)
			inv.gen++
		}
	}
}

// Clear forgets every root.
func (inv *Inventory) Clear() {
	inv.mu.Lock()
	defer inv.mu.Unlock()
	inv.roots = nil
	inv.gen++
}

func due(at, elapsed time.Time, every time.Duration) bool {
	return elapsed.Before(at) || elapsed.Sub(at) >= every
}

// scan lists the whole root, newest names first.
func (r *root) scan(dir string, elapsed time.Time) {
	idlework.Walk()
	r.dirty = true
	r.dirs, r.files = map[string]*dirState{}, map[string]fileState{}
	r.hotAt, r.coldAt = elapsed, elapsed
	info, err := os.Lstat(dir)
	if err != nil || !info.IsDir() {
		return // missing: the next hot check looks again
	}
	r.dirs[dir] = &dirState{info: info}
	r.list(dir)
}

// list enumerates one directory and adds the children it did not know.
func (r *root) list(path string) {
	r.dirty = true
	d := r.dirs[path]
	// Racy is about the file system's timestamp tick at the real moment of listing, so it is
	// judged by the wall clock, not the caller's now: a directory stamped in the future (clock
	// skew, a test clock) must not be listed again at every check.
	since := time.Since(d.info.ModTime())
	d.racy = since < racyWindow && since > -racyWindow
	es, err := os.ReadDir(path)
	idlework.Entries(len(es))
	if err != nil {
		return
	}
	known, oldFiles := map[string]bool{}, d.files
	for _, sub := range d.subdirs {
		known[sub] = true
	}
	d.subdirs, d.files = nil, nil
	var fresh []string
	for i := len(es) - 1; i >= 0; i-- { // newest names first: Codex days sort by date
		e := es[i]
		keep := e.Type()&os.ModeSymlink == 0 && (e.IsDir() || e.Type().IsRegular() && strings.HasSuffix(e.Name(), ".jsonl"))
		if !keep {
			continue
		}
		child := filepath.Join(path, e.Name())
		switch {
		case e.IsDir():
			info, err := os.Lstat(child)
			if err != nil || !info.IsDir() {
				continue
			}
			d.subdirs = append(d.subdirs, child)
			if known[child] && r.dirs[child] != nil {
				delete(known, child)
				continue // its own stamp says whether it changed
			}
			r.dirs[child] = &dirState{info: info, depth: d.depth + 1}
			fresh = append(fresh, child)
		default:
			info, err := e.Info()
			if err != nil || !info.Mode().IsRegular() {
				continue
			}
			d.files = append(d.files, child)
			r.files[child] = stateOf(info, d.depth+1)
		}
	}
	for gone := range known {
		r.remove(gone)
	}
	listed := make(map[string]bool, len(d.files))
	for _, f := range d.files {
		listed[f] = true
	}
	for _, f := range oldFiles {
		if !listed[f] {
			delete(r.files, f)
		}
	}
	for _, child := range fresh {
		r.list(child)
	}
}

// remove forgets a directory and everything under it.
func (r *root) remove(path string) {
	d := r.dirs[path]
	if d == nil {
		return
	}
	r.dirty = true
	for _, sub := range d.subdirs {
		r.remove(sub)
	}
	for _, f := range d.files {
		delete(r.files, f)
	}
	delete(r.dirs, path)
}

// reconcile stats the directories (all of them when cold, the hot ones otherwise), re-lists a
// directory only when its metadata moved, and stats the files (all, or the recent ones).
func (r *root) reconcile(dir string, now, elapsed time.Time, cold bool) {
	r.hotAt = elapsed
	if cold {
		r.coldAt = elapsed
		idlework.Walk()
	}
	top := r.dirs[dir]
	if top == nil {
		if info, err := os.Lstat(dir); err == nil && info.IsDir() {
			r.scan(dir, elapsed)
		}
		return
	}
	recent := func(t time.Time) bool { return now.Sub(t) < HotWindow }
	chain := map[string]bool{}
	for d := top; d != nil && len(d.subdirs) > 0; d = r.dirs[d.subdirs[0]] {
		chain[d.subdirs[0]] = true
	}
	var paths []string
	for path, d := range r.dirs {
		hot := cold || d.depth <= 1 || chain[path] || recent(d.info.ModTime())
		for i := 0; !hot && i < len(d.files); i++ {
			if f, ok := r.files[d.files[i]]; ok && recent(f.modTime()) {
				hot = true
			}
		}
		if hot {
			paths = append(paths, path)
		}
	}
	// Parents first: a re-listed parent may drop a child before it is visited.
	sort.Slice(paths, func(i, j int) bool {
		if di, dj := r.dirs[paths[i]].depth, r.dirs[paths[j]].depth; di != dj {
			return di < dj
		}
		return paths[i] < paths[j]
	})
	for _, path := range paths {
		d := r.dirs[path]
		if d == nil {
			continue
		}
		info, err := os.Lstat(path)
		if err != nil || !info.IsDir() {
			if path == dir {
				r.dirs, r.files = map[string]*dirState{}, map[string]fileState{}
				r.dirty = true
				return
			}
			r.remove(path)
			continue
		}
		if d.racy || !sameStamp(d.info, info) {
			d.info = info
			r.list(path)
			continue // listed with fresh file metadata
		}
		for _, f := range d.files {
			old, ok := r.files[f]
			if !ok || !cold && !recent(old.modTime()) {
				continue
			}
			info, err := os.Lstat(f)
			if err != nil || !info.Mode().IsRegular() {
				delete(r.files, f)
				r.dirty = true
				continue
			}
			if st := stateOf(info, int(old.depth)); st != old {
				r.files[f] = st
				r.dirty = true
			}
		}
	}
}

// sameStamp: the same file, size and modification time.
func sameStamp(a, b os.FileInfo) bool {
	return os.SameFile(a, b) && a.Size() == b.Size() && a.ModTime().Equal(b.ModTime()) && a.Mode() == b.Mode()
}

// SPDX-License-Identifier: MIT

// Package confine opens a history log so that the open itself stays inside the admitted root
// the log was found under (D397, macrevb-1222-4). Checking a path's ancestry and then opening
// it by name leaves a window in which an ancestor can be swapped for a symlink to somewhere
// else. Open resolves every component below the root relative to the root's own descriptor
// (os.Root: openat with no-follow per component on Unix, the equivalent handle walk on
// Windows), and refuses a component, symlink or "..", that would lead outside the root. The
// opened file must be a regular file. Nothing is read here.
package confine

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
)

var (
	// ErrOutside: the path is not below the root.
	ErrOutside = errors.New("path is not below its history root")
	// ErrNotRegular: what the path names is not a regular file.
	ErrNotRegular = errors.New("not a regular file")
)

// Within returns path relative to root when path lies lexically below root.
func Within(root, path string) (string, bool) {
	if root == "" || !filepath.IsAbs(root) || !filepath.IsAbs(path) {
		return "", false
	}
	rel, err := filepath.Rel(filepath.Clean(root), filepath.Clean(path))
	if err != nil || rel == "." || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) || filepath.IsAbs(rel) {
		return "", false
	}
	return rel, true
}

// Open opens path for reading, anchored to root: an ancestor between root and the file that is
// (or becomes, up to the open) a symlink out of root makes the open fail.
func Open(root, path string) (*os.File, error) {
	rel, ok := Within(root, path)
	if !ok {
		return nil, ErrOutside
	}
	r, err := os.OpenRoot(filepath.Clean(root))
	if err != nil {
		return nil, err
	}
	defer r.Close()
	f, err := r.Open(rel)
	if err != nil {
		return nil, err
	}
	if fi, err := f.Stat(); err != nil || !fi.Mode().IsRegular() {
		f.Close()
		return nil, ErrNotRegular
	}
	return f, nil
}

// OpenUnder opens path anchored to the first of roots that lexically contains it. A path below
// none of them (a transcript a hook names elsewhere) opens as before.
func OpenUnder(roots []string, path string) (*os.File, error) {
	for _, root := range roots {
		if _, ok := Within(root, path); ok {
			return Open(root, path)
		}
	}
	return os.Open(path)
}

// SPDX-License-Identifier: MIT

// Package profile is the one place that decides where ModelPlan keeps its own
// state: the config folder (consent, connections, declared quota, local-usage
// and project-label choices) and the cache folder (publication cache, history,
// perf, cycles, observed readings and every other store file).
//
// MODELPLAN_PROFILE_ROOT=<absolute dir> moves both under that folder, so a test
// build can run a true first run without touching the real profile (D164). It
// only relocates ModelPlan's own state: tool data such as ~/.codex or ~/.claude
// is still found from HOME, exactly as for a new user, and only read after
// consent. When it is set, it wins over MODELPLAN_CACHE so no store can land in
// the real profile.
package profile

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
)

// RootEnv names the fresh-profile root.
const RootEnv = "MODELPLAN_PROFILE_ROOT"

// ErrRelativeRoot: a set root that is empty or not absolute is refused, never
// resolved against the working directory or read as unset (which would select
// the real profile).
var ErrRelativeRoot = errors.New(RootEnv + " must be an absolute path")

// ErrLinkedStore: nothing under a root may be a symbolic link. Neither the engine
// nor the app creates one there, so a link can only have been planted, and it
// could lead a store back into the real profile.
var ErrLinkedStore = errors.New(RootEnv + " holds a symbolic link")

// unusable is where an invalid root's stores resolve: under /dev/null, so every
// create or write fails instead of landing in the real profile.
var unusable = filepath.Join(os.DevNull, "modelplan-unusable-profile")

// linked walks the whole root without following links, so every store path the
// resolver builds under it (including ones added later) is covered.
func linked(root string) bool {
	found := false
	_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			if path == root && errors.Is(err, fs.ErrNotExist) {
				return filepath.SkipAll // a root the store will create
			}
			found = true // unreadable: fail closed
			return filepath.SkipAll
		}
		if path != root && d.Type()&fs.ModeSymlink != 0 {
			found = true
			return filepath.SkipAll
		}
		return nil
	})
	return found
}

// state: the cleaned root, whether the key is present at all, and why a present
// root is unusable.
func state() (string, bool, error) {
	value, set := os.LookupEnv(RootEnv)
	if !set {
		return "", false, nil
	}
	if value == "" || !filepath.IsAbs(value) {
		return "", true, ErrRelativeRoot
	}
	root := filepath.Clean(value)
	if linked(root) {
		return "", true, ErrLinkedStore
	}
	return root, true, nil
}

// Root is the cleaned override root, or "" when the key is unset. A present but
// unusable root returns a path under /dev/null, never "".
func Root() string {
	root, set, err := state()
	if set && err != nil {
		return unusable
	}
	return root
}

// Check reports an unusable root before any command touches a store.
func Check() error {
	_, _, err := state()
	return err
}

// ConfigDir is ModelPlan's config folder: <root>/engine/config under an
// override, otherwise <home>/.config/modelplan.
func ConfigDir(home string) string {
	if root := Root(); root != "" {
		return filepath.Join(root, "engine", "config")
	}
	return filepath.Join(home, ".config", "modelplan")
}

// ConfigFile is one named file in ConfigDir.
func ConfigFile(home, name string) string { return filepath.Join(ConfigDir(home), name) }

// CacheDir is the store folder: <root>/engine/cache under an override, else
// $MODELPLAN_CACHE, else the user cache folder's modelplan.
func CacheDir() (string, error) {
	root, set, err := state()
	if err != nil {
		return "", err
	}
	if set {
		return filepath.Join(root, "engine", "cache"), nil
	}
	if dir := os.Getenv("MODELPLAN_CACHE"); dir != "" {
		return dir, nil
	}
	base, err := os.UserCacheDir()
	if err != nil {
		return "", err
	}
	return filepath.Join(base, "modelplan"), nil
}

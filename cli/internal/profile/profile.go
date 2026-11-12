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
	"os"
	"path/filepath"
)

// RootEnv names the fresh-profile root.
const RootEnv = "MODELPLAN_PROFILE_ROOT"

// ErrRelativeRoot: a set root that is not absolute is refused, never resolved
// against the working directory or ignored in favour of the real profile.
var ErrRelativeRoot = errors.New(RootEnv + " must be an absolute path")

// Root is the cleaned override root, or "" when none is set.
func Root() string {
	value := os.Getenv(RootEnv)
	if value == "" {
		return ""
	}
	return filepath.Clean(value)
}

// Check reports an unusable root before any command touches a store.
func Check() error {
	if value := os.Getenv(RootEnv); value != "" && !filepath.IsAbs(value) {
		return ErrRelativeRoot
	}
	return nil
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
	if root := Root(); root != "" {
		if !filepath.IsAbs(root) {
			return "", ErrRelativeRoot
		}
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

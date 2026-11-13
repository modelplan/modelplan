// SPDX-License-Identifier: MIT
package speed

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// lock keeps new kernel locks separate from the legacy exclusive-create markers.
// The marker check only detects older writers that already hold a fresh marker;
// it cannot coordinate with an older process that starts after this check.
func lock(cache, name string) (func(), bool) {
	if name != "speed.lock" && name != "perf.lock" {
		return nil, false
	}
	unlock, ok := lockPlatform(cache, strings.TrimSuffix(name, ".lock")+".flock")
	if !ok {
		return nil, false
	}
	info, err := os.Lstat(filepath.Join(cache, "observed", name))
	if (err != nil && !errors.Is(err, os.ErrNotExist)) || (err == nil && time.Since(info.ModTime()) <= 10*time.Second) {
		unlock()
		return nil, false
	}
	return unlock, true
}

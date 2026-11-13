// SPDX-License-Identifier: MIT
package main

import (
	"os"
	"path/filepath"
	"time"

	"github.com/modelplan/modelplan/cli/internal/detach"
	"github.com/modelplan/modelplan/cli/internal/localusage"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/store"
)

var startNativeDetached = detach.StartLocked

func nativeRefreshDue(st *store.Store, now time.Time) bool {
	home, _ := os.UserHomeDir()
	return quota.NativeDue(quotaPaths(st), now) || localusage.ProductionHistoryDue(home, st.Dir, now)
}

// Native readers need no plugin or helper installation. An admitted reader
// without an attempt is due immediately. One inherited kernel lock covers the
// detached worker's startup and entire lifetime, across CLI/App copies.
func refreshNativeLater(st *store.Store) {
	if nativeRefreshDue(st, time.Now()) {
		_ = startNativeDetached(filepath.Join(st.Dir, "observed", "native-refresh.lock"), "connections", "refresh", "--quiet", "--scheduled")
	}
}

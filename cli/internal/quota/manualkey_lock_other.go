// SPDX-License-Identifier: MIT
//go:build !(darwin || linux)

package quota

import "sync"

var manualKeyMu sync.Mutex

// Off the supported platforms only the in-process lock applies.
func lockManualKeys(string) (func(), error) {
	manualKeyMu.Lock()
	return manualKeyMu.Unlock, nil
}

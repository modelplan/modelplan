// SPDX-License-Identifier: MIT
package detect

import (
	"os"
	"path/filepath"
)

// ZaiSavedLoginScope is the account-usage path only ZCode's own sign-in (QR code / OAuth) can serve
// (D369). It is listed as detected only when that sign-in's files are there.
const ZaiSavedLoginScope = "zai.account_usage.saved_login"

// ZCodeLoginPresent: ZCode Desktop's sign-in layout (~/.zcode/v2 setting.json, config.json and
// credentials.json) exists as regular files, and its credential store is not bound to the system
// credential store. ZCode 3.19+ writes a "credential-source" marker when it moves the store's key
// into the macOS Keychain (enc:v2 entries); ModelPlan does not read another app's Keychain item
// (D230/D232), so such a sign-in is not one it can read (G3-158). Presence metadata only: nothing
// is opened or read.
func ZCodeLoginPresent(home string) bool {
	if home == "" {
		return false
	}
	dir := filepath.Join(home, ".zcode", "v2")
	if _, err := os.Lstat(filepath.Join(dir, "credential-source")); !os.IsNotExist(err) {
		return false
	}
	for _, name := range []string{"setting.json", "config.json", "credentials.json"} {
		fi, err := os.Lstat(filepath.Join(dir, name))
		if err != nil || !fi.Mode().IsRegular() {
			return false
		}
	}
	return true
}

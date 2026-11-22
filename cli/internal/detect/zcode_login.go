// SPDX-License-Identifier: MIT
package detect

import (
	"os"
	"path/filepath"
	"strings"
)

// ZaiSavedLoginScope is the account-usage path only ZCode's own sign-in (QR code / OAuth) can serve
// (D369). It is listed as detected only when that sign-in's files are there.
const ZaiSavedLoginScope = "zai.account_usage.saved_login"

// ZCodeLoginPresent: ZCode Desktop's sign-in layout (~/.zcode/v2 setting.json, config.json and
// credentials.json) exists as regular files. A store ZCode 3.19+ bound to the macOS Keychain
// ("credential-source", enc:v2:os) is present too: it is read only after the user's own Keychain
// choice (D380). Presence metadata only: nothing is opened or read.
func ZCodeLoginPresent(home string) bool {
	if home == "" {
		return false
	}
	dir := filepath.Join(home, ".zcode", "v2")
	for _, name := range []string{"setting.json", "config.json", "credentials.json"} {
		fi, err := os.Lstat(filepath.Join(dir, name))
		if err != nil || !fi.Mode().IsRegular() {
			return false
		}
	}
	return true
}

// ZCodeKeychainBound: ZCode pinned this sign-in's key to the system credential store (its
// "credential-source" marker). Metadata only; the marker is read, never the store.
func ZCodeKeychainBound(home string) bool {
	path := filepath.Join(home, ".zcode", "v2", "credential-source")
	fi, err := os.Lstat(path)
	if err != nil || !fi.Mode().IsRegular() || fi.Size() > 64 {
		return false
	}
	b, err := os.ReadFile(path)
	return err == nil && strings.TrimSpace(string(b)) == "os"
}

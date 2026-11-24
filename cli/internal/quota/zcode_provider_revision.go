// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"strconv"
)

// zcodeProviderRevision identifies the file version using metadata only. Size
// and mtime can survive a replacement, so an unverified identity fails closed.
func zcodeProviderRevision(path string) string {
	info, err := os.Lstat(path)
	if err != nil || !info.Mode().IsRegular() {
		return ""
	}
	identity := zcodeProviderFileIdentity(path, info)
	if identity == "" {
		return ""
	}
	return identity + ":" + strconv.FormatInt(info.Size(), 10) + ":" + strconv.FormatInt(info.ModTime().UnixNano(), 10)
}

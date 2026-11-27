//go:build windows

package quota

import "os"

func antigravityOwnedByUser(os.FileInfo) bool { return false }

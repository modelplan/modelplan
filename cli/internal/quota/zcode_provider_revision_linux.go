// SPDX-License-Identifier: MIT
package quota

import (
	"fmt"
	"os"
	"syscall"
)

func zcodeProviderFileIdentity(_ string, info os.FileInfo) string {
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return ""
	}
	return fmt.Sprintf("%d:%d:%d", stat.Dev, stat.Ino, stat.Ctim.Nano())
}

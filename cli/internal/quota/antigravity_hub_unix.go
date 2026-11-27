//go:build !windows

package quota

import (
	"os"
	"syscall"
)

func antigravityOwnedByUser(fi os.FileInfo) bool {
	st, ok := fi.Sys().(*syscall.Stat_t)
	return ok && int(st.Uid) == os.Getuid()
}

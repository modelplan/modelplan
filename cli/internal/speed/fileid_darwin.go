//go:build darwin

// SPDX-License-Identifier: MIT
package speed

import (
	"os"
	"syscall"
)

// fileID: the identity of the file at path (device, inode and birth time), "" when it cannot be
// read.
func fileID(path string) string {
	fi, err := os.Stat(path)
	if err != nil {
		return ""
	}
	st, ok := fi.Sys().(*syscall.Stat_t)
	if !ok {
		return ""
	}
	return fileIDOf(uint64(uint32(st.Dev)), st.Ino, st.Birthtimespec.Nano())
}

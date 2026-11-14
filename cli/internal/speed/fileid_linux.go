//go:build linux

// SPDX-License-Identifier: MIT
package speed

import "golang.org/x/sys/unix"

// fileID: the identity of the file at path (device, inode and, where the file system records it,
// birth time), "" when it cannot be read. A file removed and another created at its path can get
// the same inode; the birth time still tells them apart.
func fileID(path string) string {
	var st unix.Statx_t
	if err := unix.Statx(unix.AT_FDCWD, path, unix.AT_STATX_SYNC_AS_STAT, unix.STATX_INO|unix.STATX_BTIME, &st); err != nil || st.Mask&unix.STATX_INO == 0 {
		return ""
	}
	var birth int64
	if st.Mask&unix.STATX_BTIME != 0 {
		birth = st.Btime.Sec*1e9 + int64(st.Btime.Nsec)
	}
	return fileIDOf(unix.Mkdev(st.Dev_major, st.Dev_minor), st.Ino, birth)
}

// SPDX-License-Identifier: MIT
//go:build darwin

package toolcli

import (
	"bytes"
	"os"
	"syscall"

	"golang.org/x/sys/unix"
)

// killTagged kills every process of this user whose environment carries tag ("NAME=value"). The
// environment comes from kern.procargs2, which the kernel returns for the caller's own processes.
func killTagged(tag string) {
	needle := append(append([]byte{0}, tag...), 0)
	for pass := 0; pass < 3; pass++ {
		procs, err := unix.SysctlKinfoProcSlice("kern.proc.uid", os.Getuid())
		if err != nil {
			return
		}
		found := false
		self := os.Getpid()
		for _, p := range procs {
			pid := int(p.Proc.P_pid)
			if pid <= 1 || pid == self {
				continue
			}
			args, err := unix.SysctlRaw("kern.procargs2", pid)
			if err != nil || !bytes.Contains(args, needle) {
				continue
			}
			found = true
			_ = syscall.Kill(pid, syscall.SIGKILL)
		}
		if !found {
			return
		}
	}
}

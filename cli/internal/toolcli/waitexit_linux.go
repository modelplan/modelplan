// SPDX-License-Identifier: MIT
//go:build linux

package toolcli

import (
	"errors"

	"golang.org/x/sys/unix"
)

// waitExited blocks until the child has exited, without reaping it (WNOWAIT): the zombie keeps its
// pid, and so its process-group id, reserved until Wait.
func waitExited(pid int) error {
	for {
		var info unix.Siginfo
		err := unix.Waitid(unix.P_PID, pid, &info, unix.WEXITED|unix.WNOWAIT, nil)
		if !errors.Is(err, unix.EINTR) {
			return err
		}
	}
}

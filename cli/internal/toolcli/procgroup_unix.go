// SPDX-License-Identifier: MIT
//go:build darwin || linux

package toolcli

import (
	"os/exec"
	"syscall"
)

// ownProcessGroup starts the child in its own process group so a stop reaches every descendant
// that stayed in it, not only the launcher.
func ownProcessGroup(cmd *exec.Cmd) {
	if cmd.SysProcAttr == nil {
		cmd.SysProcAttr = &syscall.SysProcAttr{}
	}
	cmd.SysProcAttr.Setpgid = true
	cmd.Cancel = func() error { killProcessGroup(cmd); return nil }
}

func killProcessGroup(cmd *exec.Cmd) {
	if cmd.Process == nil {
		return
	}
	if pid := cmd.Process.Pid; pid > 0 {
		_ = syscall.Kill(-pid, syscall.SIGKILL)
	}
	_ = cmd.Process.Kill()
}

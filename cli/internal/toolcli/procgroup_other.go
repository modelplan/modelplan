// SPDX-License-Identifier: MIT
//go:build !darwin && !linux

package toolcli

import "os/exec"

func ownProcessGroup(cmd *exec.Cmd) {
	cmd.Cancel = func() error { killProcessGroup(cmd); return nil }
}

func killProcessGroup(cmd *exec.Cmd) {
	if cmd.Process != nil {
		_ = cmd.Process.Kill()
	}
}

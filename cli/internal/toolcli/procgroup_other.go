// SPDX-License-Identifier: MIT
//go:build !darwin && !linux

package toolcli

import "os/exec"

func ownProcessGroup(*exec.Cmd) {}

func killTagged(string) {}

func killProcessGroup(cmd *exec.Cmd) {
	if cmd.Process != nil {
		_ = cmd.Process.Kill()
	}
}

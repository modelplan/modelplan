// SPDX-License-Identifier: MIT
//go:build !darwin && !linux

package toolcli

import (
	"errors"
	"os/exec"
)

func ownProcessGroup(*exec.Cmd) {}

func killTagged(string) {}

func killProcessGroup(cmd *exec.Cmd) {
	if cmd.Process != nil {
		_ = cmd.Process.Kill()
	}
}

func waitExited(int) error { return errors.New("wait without reaping unsupported") }

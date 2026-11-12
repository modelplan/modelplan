//go:build darwin || linux

package quota

import (
	"os/exec"
	"syscall"
)

// ownProcessGroup starts the runtime in its own process group so a timeout can stop every
// descendant that inherited its pipes, not only the launcher.
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
	_ = syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
	_ = cmd.Process.Kill()
}

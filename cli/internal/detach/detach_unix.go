//go:build unix

package detach

import (
	"os"
	"os/exec"
	"syscall"
)

// Start runs this binary again with args in its own session, so a status-line
// invocation can return immediately while the sync finishes in the background.
func Start(args ...string) error {
	return start(nil, args...)
}

func start(files []*os.File, args ...string) error {
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	cmd := exec.Command(exe, args...)
	cmd.ExtraFiles = files
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return err
	}
	return cmd.Process.Release()
}

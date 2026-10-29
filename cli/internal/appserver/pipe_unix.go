//go:build darwin || linux || freebsd || openbsd || netbsd || dragonfly

// SPDX-License-Identifier: MIT
package appserver

import (
	"errors"
	"os"
	"syscall"
)

// Inherited fd 0/1 can be blocking os.Files outside Go's poller: Close then
// cannot wake a Read/Write already in a syscall. A nonblocking duplicate wrapped
// after F_SETFL is pollable and cancellation closes it promptly.
func cancellablePipe(file *os.File) (*os.File, error) {
	info, err := file.Stat()
	if err != nil || info.Mode()&os.ModeNamedPipe == 0 {
		return nil, errors.New("anonymous_pipe_required")
	}
	fd, err := syscall.Dup(int(file.Fd()))
	if err != nil {
		return nil, err
	}
	syscall.CloseOnExec(fd)
	if err := syscall.SetNonblock(fd, true); err != nil {
		_ = syscall.Close(fd)
		return nil, err
	}
	result := os.NewFile(uintptr(fd), "app-server-pipe")
	if result == nil {
		_ = syscall.Close(fd)
		return nil, errors.New("pipe_unavailable")
	}
	return result, nil
}

// SPDX-License-Identifier: MIT
//go:build darwin

package toolcli

import (
	"errors"
	"time"

	"golang.org/x/sys/unix"
)

// waitExited blocks until the child has exited, without reaping it: a kqueue NOTE_EXIT event fires
// on exit and leaves the zombie (and its process-group id) for Wait. A child that already exited
// is reported as ESRCH by the registration, and it is still unreaped, so that also returns nil.
func waitExited(pid int) error {
	kq, err := unix.Kqueue()
	if err != nil {
		return err
	}
	defer unix.Close(kq)
	change := []unix.Kevent_t{{Ident: uint64(pid), Filter: unix.EVFILT_PROC, Flags: unix.EV_ADD | unix.EV_ONESHOT, Fflags: unix.NOTE_EXIT}}
	events := make([]unix.Kevent_t, 1)
	for {
		// A bounded wait, so a zombie whose registration neither failed nor fired cannot hang the
		// read: each timeout checks for the zombie state itself.
		timeout := unix.NsecToTimespec(int64(250 * time.Millisecond))
		n, err := unix.Kevent(kq, change, events, &timeout)
		switch {
		case errors.Is(err, unix.EINTR):
			change = nil // registered already; keep waiting
			continue
		case errors.Is(err, unix.ESRCH):
			return nil
		case err != nil:
			return err
		}
		if n > 0 && events[0].Flags&unix.EV_ERROR != 0 {
			if unix.Errno(events[0].Data) == unix.ESRCH {
				return nil
			}
			return unix.Errno(events[0].Data)
		}
		if n > 0 && events[0].Fflags&unix.NOTE_EXIT != 0 {
			return nil
		}
		change = nil
		if k, err := unix.SysctlKinfoProc("kern.proc.pid", pid); err == nil && k.Proc.P_stat == sZomb {
			return nil // exited and waiting for our Wait
		}
	}
}

// sZomb is the zombie process state (<sys/proc.h> SZOMB).
const sZomb = 5

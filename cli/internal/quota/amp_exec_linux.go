package quota

import (
	"errors"
	"io"
	"os"

	"golang.org/x/sys/unix"
)

// Anonymous RAM-backed executable, sealed before verification. No package,
// credential or large on-disk artifact is copied or retained.
func ampSealedArtifact(source io.Reader) (*os.File, error) {
	fd, err := unix.MemfdCreate("modelplan-amp-audited", unix.MFD_CLOEXEC|unix.MFD_ALLOW_SEALING)
	if err != nil {
		return nil, err
	}
	file := os.NewFile(uintptr(fd), "modelplan-amp-audited")
	n, err := io.Copy(file, io.LimitReader(source, 256<<20+1))
	if err != nil || n > 256<<20 {
		file.Close()
		return nil, errors.New("artifact size unavailable")
	}
	if _, err = unix.FcntlInt(file.Fd(), unix.F_ADD_SEALS, unix.F_SEAL_WRITE|unix.F_SEAL_GROW|unix.F_SEAL_SHRINK|unix.F_SEAL_SEAL); err != nil {
		file.Close()
		return nil, err
	}
	if _, err = file.Seek(0, io.SeekStart); err != nil {
		file.Close()
		return nil, err
	}
	return file, nil
}
func ampExecPath() string { return "/proc/self/fd/3" }

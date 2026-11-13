//go:build !darwin && !linux && !freebsd && !openbsd && !netbsd && !dragonfly

// SPDX-License-Identifier: MIT
package appserver

import (
	"errors"
	"os"
)

func cancellablePipe(*os.File) (*os.File, error) { return nil, errors.New("unsupported_transport") }

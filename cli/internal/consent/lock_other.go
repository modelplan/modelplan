//go:build !darwin && !linux && !windows

package consent

import "errors"

func lockFile(string) (func(), error) {
	return nil, errors.New("reader admission is unsupported on this platform")
}

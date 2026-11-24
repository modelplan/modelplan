//go:build !darwin && !linux && !windows

package consent

import "errors"

func lockFileOS(string) (func(), error) {
	return nil, errors.New("reader admission is unsupported on this platform")
}

func lockFileSharedOS(string) (func(), error) {
	return nil, errors.New("reader admission is unsupported on this platform")
}

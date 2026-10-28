//go:build !darwin && !linux

package detach

import "errors"

func StartLocked(string, ...string) error {
	return errors.New("locked background refresh is unsupported on this platform")
}

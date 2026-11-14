//go:build !linux && !darwin

// SPDX-License-Identifier: MIT
package speed

// fileID: no file identity on other systems; the count of post-clear rows is the only check.
func fileID(string) string { return "" }

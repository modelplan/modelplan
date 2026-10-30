//go:build darwin

// SPDX-License-Identifier: MIT
package diagnostics

import "golang.org/x/sys/unix"

func hostOSVersion() (string, string) {
	value, err := unix.Sysctl("kern.osproductversion")
	if err != nil {
		return "", "unknown"
	}
	return value, "product"
}

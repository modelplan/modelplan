//go:build darwin

// SPDX-License-Identifier: MIT
package diagnostics

import "syscall"

func hostOSVersion() (string, string) {
	value, err := syscall.Sysctl("kern.osproductversion")
	if err != nil {
		return "", "unknown"
	}
	return value, "product"
}

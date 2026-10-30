//go:build linux

// SPDX-License-Identifier: MIT
package diagnostics

import (
	"io"
	"os"
	"strings"
	"syscall"
)

func hostOSVersion() (string, string) {
	if f, err := os.Open("/etc/os-release"); err == nil {
		b, _ := io.ReadAll(io.LimitReader(f, 16<<10))
		f.Close()
		for _, line := range strings.Split(string(b), "\n") {
			if value, ok := strings.CutPrefix(line, "VERSION_ID="); ok {
				value = strings.Trim(value, `"'`)
				if safeOSVersion(value) != "unknown" {
					return value, "distribution"
				}
			}
		}
	}
	var u syscall.Utsname
	if syscall.Uname(&u) != nil {
		return "", "unknown"
	}
	var b []byte
	for _, c := range u.Release {
		if c == 0 {
			break
		}
		b = append(b, byte(c))
	}
	return numericVersionPrefix(string(b)), "kernel"
}

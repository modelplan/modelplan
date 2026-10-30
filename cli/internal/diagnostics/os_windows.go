//go:build windows

// SPDX-License-Identifier: MIT
package diagnostics

import (
	"fmt"
	"golang.org/x/sys/windows"
)

func hostOSVersion() (string, string) {
	v := windows.RtlGetVersion()
	if v == nil {
		return "", "unknown"
	}
	return fmt.Sprintf("%d.%d.%d", v.MajorVersion, v.MinorVersion, v.BuildNumber), "product"
}

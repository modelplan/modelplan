//go:build windows

// SPDX-License-Identifier: MIT
package diagnostics

import (
	"fmt"
	"syscall"
	"unsafe"
)

// RtlGetVersion reports the actual Windows version without the application
// manifest compatibility substitutions made by GetVersion.
func hostOSVersion() (string, string) {
	var version struct {
		size, major, minor, build, platform uint32
		servicePack                         [128]uint16
	}
	version.size = uint32(unsafe.Sizeof(version))
	proc := syscall.NewLazyDLL("ntdll.dll").NewProc("RtlGetVersion")
	if err := proc.Find(); err != nil {
		return "", "unknown"
	}
	status, _, _ := proc.Call(uintptr(unsafe.Pointer(&version)))
	if status != 0 {
		return "", "unknown"
	}
	return fmt.Sprintf("%d.%d.%d", version.major, version.minor, version.build), "product"
}

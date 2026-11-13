//go:build !linux && !darwin && !windows

// SPDX-License-Identifier: MIT
package diagnostics

func hostOSVersion() (string, string) { return "", "unknown" }

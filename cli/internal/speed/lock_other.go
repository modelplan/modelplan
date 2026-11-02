//go:build !darwin && !linux && !windows

// SPDX-License-Identifier: MIT
package speed

// The speed reader supports advisory ledger locks on macOS and Linux only.
func lockPlatform(string, string) (func(), bool) { return nil, false }

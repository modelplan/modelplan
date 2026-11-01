//go:build !darwin && !linux

// SPDX-License-Identifier: MIT
package speed

// The speed reader supports advisory ledger locks on macOS and Linux only.
func lock(string, string) (func(), bool) { return nil, false }

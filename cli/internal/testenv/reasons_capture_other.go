//go:build !unix

// SPDX-License-Identifier: MIT
package testenv

import "testing"

func captureProcessOutput(t *testing.T) func() (string, error) {
	t.Helper()
	t.Skip("reader descriptor capture is supported by the Linux/macOS CI hosts")
	return func() (string, error) { return "", nil }
}

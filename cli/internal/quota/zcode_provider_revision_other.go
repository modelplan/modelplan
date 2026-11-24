//go:build !linux && !darwin && !windows

// SPDX-License-Identifier: MIT
package quota

import "os"

func zcodeProviderFileIdentity(string, os.FileInfo) string { return "" }

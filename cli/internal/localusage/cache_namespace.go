// SPDX-License-Identifier: MIT
package localusage

import (
	"encoding/hex"
	"github.com/modelplan/modelplan/cli/internal/consent"
	"strings"
)

// HistoryCacheTool parses the exact tool component before the fixed 64-hex
// profile hash. A prefix match would confuse valid hyphenated tool IDs.
func HistoryCacheTool(name string) (string, bool) {
	const prefix = "history-v1-"
	if !strings.HasPrefix(name, prefix) || !strings.HasSuffix(name, ".json") {
		return "", false
	}
	stem := strings.TrimSuffix(name, ".json")
	split := len(stem) - 65
	if split <= len(prefix) || stem[split] != '-' {
		return "", false
	}
	tool, hash := stem[len(prefix):split], stem[split+1:]
	decoded, err := hex.DecodeString(hash)
	if !consent.ValidTool(tool) || err != nil || len(decoded) != 32 || strings.ToLower(hash) != hash {
		return "", false
	}
	return tool, true
}

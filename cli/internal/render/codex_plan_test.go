// SPDX-License-Identifier: MIT
package render

import (
	"bytes"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestQuotaNamesCodexProTiersByPrice(t *testing.T) {
	var out bytes.Buffer
	Style{T: EN}.Quota(&out, quota.Report{Accounts: []quota.Account{{Source: "codex", Plan: "promax"}}})
	if s := out.String(); !strings.Contains(s, "Pro 500") || strings.Contains(s, "promax") {
		t.Fatalf("%q", s)
	}
}

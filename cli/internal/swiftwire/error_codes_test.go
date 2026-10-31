// SPDX-License-Identifier: MIT
package swiftwire

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

// Read the checked-in Swift declarations, not a second generated value. The Go
// constants are the app-server's actual wire codes, so either side drifting fails.
func checkSwiftErrorCodeParity(swift []byte) error {
	block := regexp.MustCompile(`(?s)public enum WireErrorCode \{(.*?)\n\}`).FindSubmatch(swift)
	if len(block) != 2 {
		return fmt.Errorf("missing Swift wire error code declarations")
	}
	decl := regexp.MustCompile(`(?m)^[ \t]*public static let (protocolMismatch|busy): Int = (-?[0-9]+)[ \t]*$`)
	matches := decl.FindAllSubmatch(block[1], -1)
	want := map[string]int{"protocolMismatch": wire.CodeProtocolMismatch, "busy": wire.CodeBusy}
	seen := map[string]bool{}
	for _, match := range matches {
		name := string(match[1])
		value, err := strconv.Atoi(string(match[2]))
		if err != nil || seen[name] || value != want[name] {
			return fmt.Errorf("Swift wire error code mismatch: %s", name)
		}
		seen[name] = true
	}
	if len(seen) != len(want) {
		return fmt.Errorf("missing Swift wire error code")
	}
	return nil
}

func TestSwiftWireErrorCodeParity(t *testing.T) {
	path := filepath.Join(repoRoot(t), "clients/swift/ModelPlanWire/Sources/ModelPlanWire/Generated.swift")
	swift, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if err := checkSwiftErrorCodeParity(swift); err != nil {
		t.Fatal(err)
	}

	// Negative controls prove that a changed, omitted, or duplicated production
	// declaration cannot pass the actual parity check.
	busy := []byte(fmt.Sprintf("    public static let busy: Int = %d", wire.CodeBusy))
	if bytes.Count(swift, busy) != 1 {
		t.Fatal("expected exactly one busy declaration")
	}
	for name, broken := range map[string][]byte{
		"changed":   bytes.Replace(swift, busy, []byte(fmt.Sprintf("    public static let busy: Int = %d", wire.CodeBusy+1)), 1),
		"missing":   bytes.Replace(swift, busy, nil, 1),
		"duplicate": bytes.Replace(swift, busy, bytes.Join([][]byte{busy, busy}, []byte("\n")), 1),
	} {
		t.Run(name, func(t *testing.T) {
			if err := checkSwiftErrorCodeParity(broken); err == nil {
				t.Fatal("invalid Swift declaration passed parity check")
			}
		})
	}
}

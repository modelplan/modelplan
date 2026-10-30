// SPDX-License-Identifier: MIT
package swiftwire

import (
	"bytes"
	"encoding/json"
	"fmt"

	"github.com/modelplan/modelplan/cli/internal/appserver"
)

// ChildEnvironmentContract publishes supervision's key names, never values.
// The same source generates the Swift set used by ProcessEngineClient.
func ChildEnvironmentContract() ([]byte, error) {
	value := struct {
		Comment     string   `json:"$comment"`
		Version     int      `json:"version"`
		AllowedKeys []string `json:"allowedKeys"`
	}{"SPDX-License-Identifier: MIT. Generated from appserver.ChildEnvironmentKeys; run go run ./internal/swiftwire/cmd --write from cli/.", 1, appserver.ChildEnvironmentKeys()}
	data, err := json.MarshalIndent(value, "", "  ")
	return append(data, '\n'), err
}

func writeChildEnvironmentSwift(out *bytes.Buffer) {
	fmt.Fprintln(out, "// Generated from Go supervision; key names only, never environment values.")
	fmt.Fprintln(out, "public enum WireChildEnvironment {")
	fmt.Fprint(out, "    public static let allowedKeys: Set<String> = [")
	for i, key := range appserver.ChildEnvironmentKeys() {
		if i > 0 {
			fmt.Fprint(out, ", ")
		}
		fmt.Fprintf(out, "%q", key)
	}
	fmt.Fprint(out, "]\n}\n\n")
}

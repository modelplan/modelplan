// SPDX-License-Identifier: MIT
package quota

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"
)

// Post-merge #916 (1): every code ReaderErrorCode can emit is in the public readerErrorCode enum
// (desktop.json and connections.json reference it), and the schema lists no code the CLI drops.
func TestReaderErrorCodesMatchPublicSchema(t *testing.T) {
	b, err := os.ReadFile(filepath.Join("..", "..", "..", "schema", "app-cli", "common.json"))
	if err != nil {
		t.Fatal(err)
	}
	var doc struct {
		Defs map[string]struct {
			Enum []string `json:"enum"`
		} `json:"$defs"`
	}
	if err := json.Unmarshal(b, &doc); err != nil {
		t.Fatal(err)
	}
	schema := append([]string(nil), doc.Defs["readerErrorCode"].Enum...)
	cli := append([]string(nil), readerErrorCodes...)
	sort.Strings(schema)
	sort.Strings(cli)
	if strings.Join(schema, ",") != strings.Join(cli, ",") {
		t.Fatalf("schema %v\ncli    %v", schema, cli)
	}
	for _, code := range cli {
		if ReaderErrorCode(code) != code {
			t.Fatal("vocabulary code not passed through", code)
		}
	}
	if ReaderErrorCode("made_up") != "other" {
		t.Fatal("unknown code passed through")
	}
}

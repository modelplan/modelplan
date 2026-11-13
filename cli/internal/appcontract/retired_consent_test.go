// SPDX-License-Identifier: MIT
package appcontract

import (
	"encoding/json"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestConsentSchemaAcceptsCompatibilityBackend(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
	validator, err := NewValidator(root)
	if err != nil {
		t.Fatal(err)
	}
	raw, err := os.ReadFile(filepath.Join(root, "schema", "app-cli", "fixtures", "consented-consent.json"))
	if err != nil {
		t.Fatal(err)
	}
	var view map[string]any
	if err := json.Unmarshal(raw, &view); err != nil {
		t.Fatal(err)
	}
	tools := view["tools"].([]any)
	if len(tools) == 0 {
		t.Fatal("fixture has no tool")
	}
	tools[0].(map[string]any)["backend"] = "codexbar-compat"
	raw, err = json.Marshal(view)
	if err != nil {
		t.Fatal(err)
	}
	if err := validator.Validate("consent", raw); err != nil {
		t.Fatalf("common.receiptTool.backend must accept the requested compatibility alias: %v", err)
	}
}

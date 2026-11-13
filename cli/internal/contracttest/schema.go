// SPDX-License-Identifier: MIT
package contracttest

import (
	"bytes"
	"os"
	"path/filepath"
	"runtime"

	"github.com/santhosh-tekuri/jsonschema/v6"
)

// ValidateOutput is test-only support for exercising actual command boundaries.
func ValidateOutput(command string, output []byte) error {
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
	schemaBytes, err := os.ReadFile(filepath.Join(root, "schema", command+"-v1.json"))
	if err != nil {
		return err
	}
	doc, err := jsonschema.UnmarshalJSON(bytes.NewReader(schemaBytes))
	if err != nil {
		return err
	}
	compiler := jsonschema.NewCompiler()
	compiler.AssertFormat()
	location := "https://example.test/" + command + "-v1.json"
	if err = compiler.AddResource(location, doc); err != nil {
		return err
	}
	schema, err := compiler.Compile(location)
	if err != nil {
		return err
	}
	value, err := jsonschema.UnmarshalJSON(bytes.NewReader(output))
	if err != nil {
		return err
	}
	return schema.Validate(value)
}

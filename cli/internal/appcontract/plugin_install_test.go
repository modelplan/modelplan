// SPDX-License-Identifier: MIT
package appcontract

import (
	"encoding/json"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/plugininstall"
)

func pluginContractRoot(t *testing.T) string {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	return filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
}

func readPluginSchema(t *testing.T, root string) map[string]any {
	t.Helper()
	b, err := os.ReadFile(filepath.Join(root, "schema/app-cli/plugin-install.json"))
	if err != nil {
		t.Fatal(err)
	}
	var doc map[string]any
	if err := json.Unmarshal(b, &doc); err != nil {
		t.Fatal(err)
	}
	return doc["$defs"].(map[string]any)["result"].(map[string]any)
}

// Even an omitempty field that happens to be zero in every capture must require
// a reviewed schema update. Compare the actual serialized Go model recursively.
func TestPluginSchemaMatchesGoResult(t *testing.T) {
	schema := readPluginSchema(t, pluginContractRoot(t))
	props := schema["properties"].(map[string]any)
	required := map[string]bool{}
	for _, v := range schema["required"].([]any) {
		required[v.(string)] = true
	}
	typ := reflect.TypeOf(plugininstall.Result{})
	if len(props) != typ.NumField() {
		t.Fatalf("schema has %d fields, Go Result has %d", len(props), typ.NumField())
	}
	for i := 0; i < typ.NumField(); i++ {
		field := typ.Field(i)
		tag := strings.Split(field.Tag.Get("json"), ",")
		name := tag[0]
		if name == "" {
			name = field.Name
		}
		shape, ok := props[name].(map[string]any)
		if !ok {
			t.Errorf("Go Result field %s has no schema", name)
			continue
		}
		optional := slices.Contains(tag[1:], "omitempty")
		if required[name] == optional {
			t.Errorf("%s required/omitempty drift", name)
		}
		assertPluginJSONType(t, name, field.Type, shape)
	}
}

func assertPluginJSONType(t *testing.T, path string, typ reflect.Type, shape map[string]any) {
	t.Helper()
	want := ""
	switch typ.Kind() {
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64, reflect.Uint, reflect.Uint8, reflect.Uint16, reflect.Uint32, reflect.Uint64:
		want = "integer"
	case reflect.String:
		want = "string"
	case reflect.Slice:
		want = "array"
		items, ok := shape["items"].(map[string]any)
		if !ok {
			t.Fatalf("%s schema lacks array items", path)
		}
		assertPluginJSONType(t, path+"[]", typ.Elem(), items)
	default:
		t.Fatalf("extend contract parity for Go field %s (%s)", path, typ)
	}
	if shape["type"] != want {
		t.Errorf("%s: schema type=%v, Go JSON type=%s", path, shape["type"], want)
	}
}

// Status is a string in the production DTO, so also check every production
// assignment. A new branch must update the schema and have a binary capture.
func TestPluginStatusVocabularyAndCapturesMatchProduction(t *testing.T) {
	root := pluginContractRoot(t)
	src, err := parser.ParseFile(token.NewFileSet(), filepath.Join(root, "cli/internal/plugininstall/install.go"), nil, 0)
	if err != nil {
		t.Fatal(err)
	}
	actual := map[string]bool{}
	record := func(expr ast.Expr) {
		literal, ok := expr.(*ast.BasicLit)
		if !ok || literal.Kind != token.STRING {
			t.Fatalf("extend contract status checker for non-literal production assignment %T", expr)
		}
		value, err := strconv.Unquote(literal.Value)
		if err != nil {
			t.Fatal(err)
		}
		actual[value] = true
	}
	ast.Inspect(src, func(node ast.Node) bool {
		switch n := node.(type) {
		case *ast.KeyValueExpr:
			if key, ok := n.Key.(*ast.Ident); ok && key.Name == "Status" {
				record(n.Value)
			}
		case *ast.AssignStmt:
			for i, lhs := range n.Lhs {
				if key, ok := lhs.(*ast.SelectorExpr); ok && key.Sel.Name == "Status" {
					if i >= len(n.Rhs) {
						t.Fatal("extend checker for multi-value status assignment")
					}
					record(n.Rhs[i])
				}
			}
		}
		return true
	})
	declared := map[string]bool{}
	status := readPluginSchema(t, root)["properties"].(map[string]any)["status"].(map[string]any)
	for _, v := range status["enum"].([]any) {
		declared[v.(string)] = true
	}
	if !reflect.DeepEqual(actual, declared) {
		t.Fatalf("production statuses %v != schema %v", actual, declared)
	}
	b, err := os.ReadFile(filepath.Join(root, "schema/app-cli/fixtures/manifest.json"))
	if err != nil {
		t.Fatal(err)
	}
	var manifest Manifest
	if err := json.Unmarshal(b, &manifest); err != nil {
		t.Fatal(err)
	}
	covered := map[string]bool{}
	for _, entry := range manifest.Entries {
		if entry.Schema != "plugin-install" {
			continue
		}
		b, err := os.ReadFile(filepath.Join(root, "schema/app-cli/fixtures", entry.File))
		if err != nil {
			t.Fatal(err)
		}
		var result plugininstall.Result
		if err := json.Unmarshal(b, &result); err != nil {
			t.Fatal(err)
		}
		covered[result.Tool+":"+result.Status] = true
	}
	for _, tool := range []string{"claude-code", "codex"} {
		for status := range actual {
			if !covered[tool+":"+status] {
				t.Errorf("no actual-binary capture for %s:%s", tool, status)
			}
		}
	}
}

func TestPluginSchemaRejectsIncompatibleResults(t *testing.T) {
	root := pluginContractRoot(t)
	v, err := NewValidator(root)
	if err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(filepath.Join(root, "schema/app-cli/fixtures/fresh-plugin-install-codex-installed.json"))
	if err != nil {
		t.Fatal(err)
	}
	for _, mutation := range []string{"status", "progress", "missing", "command", "extra"} {
		t.Run(mutation, func(t *testing.T) {
			var object map[string]any
			if err := json.Unmarshal(b, &object); err != nil {
				t.Fatal(err)
			}
			switch mutation {
			case "status":
				object["status"] = "manual-required"
			case "progress":
				object["completed"] = 1
			case "missing":
				delete(object, "docs")
			case "command":
				object["commands"] = []string{"codex plugin add unexpected"}
			case "extra":
				object["hostMessage"] = "unexpected wire field"
			}
			raw, err := json.Marshal(object)
			if err != nil {
				t.Fatal(err)
			}
			if v.Validate("plugin-install", raw) == nil {
				t.Fatal("accepted incompatible plugin result")
			}
		})
	}
}

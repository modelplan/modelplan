// SPDX-License-Identifier: MIT
package wire_test

import (
	"bytes"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

func optionalJSONField(f reflect.StructField) bool {
	return f.Type.Kind() == reflect.Pointer || strings.Contains(f.Tag.Get("json"), ",omitempty") || strings.Contains(f.Tag.Get("json"), ",omitzero")
}

// These are independent encoder probes, not the Swift generator's type model.
// Source inventory below fails if a new DTO is not reachable from this list.
func goWireTypes() map[string]reflect.Type {
	found := map[string]reflect.Type{}
	visited := map[reflect.Type]bool{}
	var visit func(reflect.Type)
	visit = func(typ reflect.Type) {
		if visited[typ] {
			return
		}
		visited[typ] = true
		switch typ.Kind() {
		case reflect.Pointer, reflect.Slice, reflect.Array:
			visit(typ.Elem())
		case reflect.Map:
			visit(typ.Elem())
		case reflect.Struct:
			if typ.PkgPath() != reflect.TypeFor[wire.Request]().PkgPath() && typ.PkgPath() != reflect.TypeFor[rows.Row]().PkgPath() {
				return
			}
			name, _, _ := strings.Cut(typ.Name(), "[")
			found[typ.PkgPath()+"."+name] = typ
			for i := 0; i < typ.NumField(); i++ {
				visit(typ.Field(i).Type)
			}
		}
	}
	for _, typ := range []reflect.Type{
		reflect.TypeFor[wire.Request](), reflect.TypeFor[wire.Success[wire.RowsSnapshot]](), reflect.TypeFor[wire.Failure](), reflect.TypeFor[wire.Notification[wire.RowsSnapshot]](),
		reflect.TypeFor[wire.InitializeParams](), reflect.TypeFor[wire.InitializeResult](), reflect.TypeFor[wire.Empty](), reflect.TypeFor[wire.CancelParams](),
		reflect.TypeFor[wire.ConsentFacts](), reflect.TypeFor[wire.ConsentGrantParams](), reflect.TypeFor[wire.ConsentReceipt](), reflect.TypeFor[wire.CredentialRequest](), reflect.TypeFor[wire.CredentialResult](),
		reflect.TypeFor[wire.RefreshRequestParams](), reflect.TypeFor[wire.RefreshScheduled](), reflect.TypeFor[wire.PluginInstallParams](), reflect.TypeFor[wire.PluginInstallResult](),
		reflect.TypeFor[wire.HistoryQueryParams](), reflect.TypeFor[wire.HistoryPage](), reflect.TypeFor[wire.Diagnostics](), reflect.TypeFor[wire.Health](), reflect.TypeFor[wire.CockpitData](), reflect.TypeFor[wire.PublicationResult](), reflect.TypeFor[rows.Projection](),
	} {
		visit(typ)
	}
	return found
}

type encodedField struct {
	present bool
	raw     string
}

func encodeOptionalField(typ reflect.Type, name string, raw json.RawMessage) (encodedField, error) {
	input := map[string]json.RawMessage{}
	if raw != nil {
		input[name] = raw
	}
	data, err := json.Marshal(input)
	if err != nil {
		return encodedField{}, err
	}
	value := reflect.New(typ)
	if err := json.Unmarshal(data, value.Interface()); err != nil {
		return encodedField{}, err
	}
	data, err = json.Marshal(value.Interface())
	if err != nil {
		return encodedField{}, err
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil {
		return encodedField{}, err
	}
	field, present := fields[name]
	return encodedField{present, string(bytes.TrimSpace(field))}, nil
}

func checkGoNullPolicy(typ reflect.Type, f reflect.StructField) error {
	policy, err := wire.ParseNullPolicy(f.Tag.Get("null"))
	if err != nil {
		return err
	}
	// Invalid explicit null is not a third valid state. Method/schema validation
	// rejects it (e.g. a JSON-RPC request id); struct encoding is not a validator.
	if policy == wire.NullForbidden {
		return nil
	}
	name, _, _ := strings.Cut(f.Tag.Get("json"), ",")
	absent, err := encodeOptionalField(typ, name, nil)
	if err != nil {
		return err
	}
	null, err := encodeOptionalField(typ, name, json.RawMessage(`null`))
	if err != nil {
		return err
	}
	if policy == wire.NullCoalesced {
		if absent != null {
			return fmt.Errorf("coalesced declaration disagrees with Go encoding")
		}
		return nil
	}
	if absent.present || !null.present || null.raw != "null" {
		return fmt.Errorf("Go encoder collapsed absent/null for a distinct field")
	}
	for _, raw := range []string{`"synthetic"`, `0`, `false`, `[]`, `{}`} {
		value, err := encodeOptionalField(typ, name, json.RawMessage(raw))
		if err != nil {
			return err
		}
		if !value.present || value.raw != raw {
			return fmt.Errorf("Go encoder collapsed the distinct value state")
		}
	}
	return nil
}

func TestOptionalWireFieldsDeclareAndPreserveNullPolicy(t *testing.T) {
	types := goWireTypes()
	count, distinct := 0, 0
	for _, typ := range types {
		for i := 0; i < typ.NumField(); i++ {
			f := typ.Field(i)
			if !f.IsExported() || f.Tag.Get("json") == "-" || (!optionalJSONField(f) && f.Tag.Get("null") == "") {
				continue
			}
			count++
			if f.Tag.Get("null") == string(wire.NullDistinct) {
				distinct++
			}
			if err := checkGoNullPolicy(typ, f); err != nil {
				t.Errorf("%s.%s: %v", typ.Name(), f.Name, err)
			}
		}
	}
	if distinct == 0 {
		t.Fatal("no distinct-state encoder probes")
	}
	// Audit source declarations too: an unregistered new DTO cannot silently
	// escape the reflection walk, including DTOs added in new wire source files.
	_, source, _, _ := runtime.Caller(0)
	base := filepath.Dir(source)
	for _, scope := range []struct {
		dir, pkg string
		single   bool
	}{
		{base, reflect.TypeFor[wire.Request]().PkgPath(), false},
		{filepath.Join(base, "../../rows/types.go"), reflect.TypeFor[rows.Row]().PkgPath(), true},
	} {
		files := []string{scope.dir}
		if !scope.single {
			entries, err := os.ReadDir(scope.dir)
			if err != nil {
				t.Fatal(err)
			}
			files = nil
			for _, entry := range entries {
				if strings.HasSuffix(entry.Name(), ".go") && !strings.HasSuffix(entry.Name(), "_test.go") {
					files = append(files, filepath.Join(scope.dir, entry.Name()))
				}
			}
		}
		for _, file := range files {
			parsed, err := parser.ParseFile(token.NewFileSet(), file, nil, 0)
			if err != nil {
				t.Fatal(err)
			}
			ast.Inspect(parsed, func(n ast.Node) bool {
				decl, ok := n.(*ast.TypeSpec)
				if !ok || !decl.Name.IsExported() {
					return true
				}
				if _, ok := decl.Type.(*ast.StructType); ok {
					if _, seen := types[scope.pkg+"."+decl.Name.Name]; !seen {
						t.Errorf("%s has no Go encoder probe", decl.Name.Name)
					}
				}
				return true
			})
		}
	}
	t.Logf("%d optional/nullable fields, %d distinct-state Go encoder probes", count, distinct)
}

func TestNullPolicyCheckDetectsUndeclaredAndCollapsedFields(t *testing.T) {
	for _, tc := range []struct {
		name string
		typ  reflect.Type
		fail bool
	}{
		{"unknown-policy", reflect.TypeFor[struct {
			Value *string `json:"value,omitempty" null:"misspelled"`
		}](), true},
		{"undeclared", reflect.TypeFor[struct {
			Value *string `json:"value,omitempty"`
		}](), true},
		{"collapsed-distinct", reflect.TypeFor[struct {
			Value *string `json:"value,omitempty" null:"distinct"`
		}](), true},
		{"false-coalesced", reflect.TypeFor[struct {
			Value json.RawMessage `json:"value,omitempty" null:"coalesced"`
		}](), true},
		{"preserved", reflect.TypeFor[struct {
			Value json.RawMessage `json:"value,omitempty" null:"distinct"`
		}](), false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			if err := checkGoNullPolicy(tc.typ, tc.typ.Field(0)); (err != nil) != tc.fail {
				t.Fatalf("unexpected check outcome: %v", err)
			}
		})
	}
}

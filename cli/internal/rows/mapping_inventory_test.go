// SPDX-License-Identifier: MIT
package rows

import (
	"go/ast"
	"go/parser"
	"go/token"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"testing"
)

// This is the emitting code, not a second hand-maintained vocabulary. Generic
// error/unavailable statuses require a bounded error companion; they cannot
// become an intentional-other exception of their own.
func TestKnownEmittingSitesAreRegistered(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
	files := []string{"cli/internal/quota/sources.go", "cli/internal/quota/readerstate.go", "cli/internal/quota/quota_native.go", "cli/internal/quota/claudeaccount.go", "cli/internal/quota/connect.go", "cli/internal/quota/codexbar.go", "cli/internal/detect/detect.go", "cli/internal/keychain/security.go"}
	managed, err := filepath.Glob(filepath.Join(root, "cli/internal/quota/*_state.go"))
	if err != nil {
		t.Fatal(err)
	}
	for _, path := range managed {
		rel, _ := filepath.Rel(root, path)
		files = append(files, rel)
	}
	for _, path := range files {
		tree, err := parser.ParseFile(token.NewFileSet(), filepath.Join(root, path), nil, 0)
		if err != nil {
			t.Fatal(err)
		}
		channel := func(field string) (SignalChannel, bool) {
			switch field {
			case "Status", "Availability":
				if strings.Contains(path, "/detect/") {
					return SignalDetection, true
				}
				return SignalStatus, true
			case "Blocked":
				return SignalBlocked, true
			case "ErrorCode":
				return SignalError, true
			case "State":
				if strings.Contains(path, "/keychain/") {
					return SignalKeychain, true
				}
			}
			return "", false
		}
		check := func(field string, value ast.Expr) {
			ch, ok := channel(field)
			if !ok {
				return
			}
			literal, ok := value.(*ast.BasicLit)
			if !ok || literal.Kind != token.STRING {
				return
			}
			raw, err := strconv.Unquote(literal.Value)
			if err != nil {
				t.Fatal(err)
			}
			if raw == "" {
				return
			}
			if _, ok := signalCodes[signalKey{ch, raw}]; !ok {
				t.Errorf("%s emits unregistered %s=%q", path, ch, raw)
			}
		}
		ast.Inspect(tree, func(node ast.Node) bool {
			switch n := node.(type) {
			case *ast.CompositeLit:
				if typ, ok := n.Type.(*ast.Ident); ok && (typ.Name == "Binding" || typ.Name == "SharedPoolBinding") {
					return false
				}
				for _, entry := range n.Elts {
					if kv, ok := entry.(*ast.KeyValueExpr); ok {
						if key, ok := kv.Key.(*ast.Ident); ok {
							check(key.Name, kv.Value)
						}
					}
				}
			case *ast.AssignStmt:
				for i, lhs := range n.Lhs {
					if key, ok := lhs.(*ast.SelectorExpr); ok && i < len(n.Rhs) {
						check(key.Sel.Name, n.Rhs[i])
					}
				}
			}
			return true
		})
	}
}

func TestReaderErrorEmitterVocabulary(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
	tree, err := parser.ParseFile(token.NewFileSet(), filepath.Join(root, "cli/internal/quota/reader_errors.go"), nil, 0)
	if err != nil {
		t.Fatal(err)
	}
	check := func(expr ast.Expr) {
		literal, ok := expr.(*ast.BasicLit)
		if !ok || literal.Kind != token.STRING {
			return
		}
		value, err := strconv.Unquote(literal.Value)
		if err != nil {
			t.Fatal(err)
		}
		if value == "" {
			return
		} // No error for consent/privacy blocks, not a reason code.
		out, known := MapSignal(SignalError, value)
		if !known || out.Code == CodeOther && !IntentionalOther(SignalError, value) {
			t.Errorf("reader_errors.go emits unmapped error %q", value)
		}
	}
	for _, decl := range tree.Decls {
		fn, ok := decl.(*ast.FuncDecl)
		if !ok {
			continue
		}
		ast.Inspect(fn.Body, func(node ast.Node) bool {
			if ret, ok := node.(*ast.ReturnStmt); ok {
				for _, value := range ret.Results {
					check(value)
				}
			}
			if fn.Name.Name == "ReaderErrorCode" {
				if clause, ok := node.(*ast.CaseClause); ok {
					for _, value := range clause.List {
						check(value)
					}
				}
			}
			return true
		})
	}
}

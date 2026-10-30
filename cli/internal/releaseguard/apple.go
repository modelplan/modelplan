// SPDX-License-Identifier: MIT
// Package releaseguard checks release source without requiring an Apple SDK.
package releaseguard

import (
	"fmt"
	"go/ast"
	"go/build/constraint"
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Only an explicit test-only compilation condition permits private SPI. DEBUG
// is deliberately insufficient: a debug application is still an application.
const TestSPIFlag = "MODELPLAN_TEST_ONLY_SPI"

type Finding struct {
	Path string
	Line int
	Rule string
}

func (f Finding) String() string { return fmt.Sprintf("%s:%d: %s", f.Path, f.Line, f.Rule) }

const spiLiteral = "(?:(?:@|#+)?\"|`)"

var privateSPI = regexp.MustCompile(`\b_webProcessIdentifier\b|\b[Vv]alueForKey(?:Path)?\s*[:(]\s*` + spiLiteral + `_|\b(?:value|setValue)\s*\([^)]*\bforKey(?:Path)?\s*:\s*` + spiLiteral + `_|\bsetValue\s*:[^;]*\bforKey(?:Path)?\s*:\s*` + spiLiteral + `_|\b(?:NSSelectorFromString|Selector|sel_registerName|sel_getUid)\s*\(\s*` + spiLiteral + `_`)

// AppleSPI checks all source files, including tests: directory names alone do
// not establish that code cannot enter a release build.
func AppleSPI(path, source string) []Finding {
	var findings []Finding
	// Go build expressions must imply the dedicated test flag for every
	// assignment of platform and other tags.
	if strings.HasSuffix(path, ".go") {
		for _, line := range strings.Split(source, "\n") {
			if strings.HasPrefix(line, "//go:build ") {
				expr, err := constraint.Parse(line)
				if err == nil && requiresTestFlag(expr) {
					return nil
				}
				break
			}
			if strings.TrimSpace(line) != "" && !strings.HasPrefix(strings.TrimSpace(line), "//") {
				break
			}
		}
	}

	// Keep comments out of both the matcher and preprocessor: a commented-out
	// #if must never hide real release code. Preserve line breaks for diagnostics.
	type branch struct{ parent, seen constraint.Expr }
	var stack []branch
	var active constraint.Expr
	var release strings.Builder
	for _, line := range strings.Split(stripComments(exposeCgoPreamble(path, source)), "\n") {
		trimmed := strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(trimmed, "#if "):
			condition := swiftCondition(strings.TrimSpace(strings.TrimPrefix(trimmed, "#if ")))
			stack = append(stack, branch{active, condition})
			active = and(active, condition)
		case strings.HasPrefix(trimmed, "#elseif ") && len(stack) > 0:
			b := &stack[len(stack)-1]
			condition := swiftCondition(strings.TrimSpace(strings.TrimPrefix(trimmed, "#elseif ")))
			active = and(b.parent, and(&constraint.NotExpr{X: b.seen}, condition))
			b.seen = &constraint.OrExpr{X: b.seen, Y: condition}
		case trimmed == "#else" && len(stack) > 0:
			b := stack[len(stack)-1]
			active = and(b.parent, &constraint.NotExpr{X: b.seen})
		case trimmed == "#endif" && len(stack) > 0:
			active = stack[len(stack)-1].parent
			stack = stack[:len(stack)-1]
		default:
			possible, _ := releasePossibilities(active)
			if possible {
				release.WriteString(line)
			}
		}
		release.WriteByte('\n')
	}
	text := release.String()
	for _, match := range privateSPI.FindAllStringIndex(text, -1) {
		findings = append(findings, Finding{path, strings.Count(text[:match[0]], "\n") + 1, "private Apple SPI outside " + TestSPIFlag})
	}
	return findings
}

func CheckApple(root string) ([]Finding, error) {
	var findings []Finding
	for _, dir := range []string{"desktop/native", "clients/swift"} {
		err := filepath.WalkDir(filepath.Join(root, dir), func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if d.IsDir() {
				if d.Name() == ".build" || d.Name() == ".tmp" {
					return filepath.SkipDir
				}
				return nil
			}
			switch filepath.Ext(path) {
			case ".swift", ".go", ".m", ".mm", ".h":
			default:
				return nil
			}
			b, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			relative, err := filepath.Rel(root, path)
			if err != nil {
				return err
			}
			findings = append(findings, AppleSPI(filepath.ToSlash(relative), string(b))...)
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	return findings, nil
}

func requiresTestFlag(expr constraint.Expr) bool {
	possible, _ := releasePossibilities(expr)
	return !possible
}
func swiftCondition(s string) constraint.Expr {
	expr, err := constraint.Parse("//go:build " + s)
	if err != nil {
		return &constraint.TagExpr{Tag: "unknown-condition"}
	}
	return expr
}
func and(a, b constraint.Expr) constraint.Expr {
	if a == nil {
		return b
	}
	return &constraint.AndExpr{X: a, Y: b}
}

// Unknown release flags may be true or false. Correlated conditions are treated
// conservatively; the dedicated test flag is always false in a release build.
func releasePossibilities(expr constraint.Expr) (yes, no bool) {
	switch e := expr.(type) {
	case nil:
		return true, false
	case *constraint.TagExpr:
		if e.Tag == TestSPIFlag {
			return false, true
		}
		return true, true
	case *constraint.NotExpr:
		y, n := releasePossibilities(e.X)
		return n, y
	case *constraint.AndExpr:
		ay, an := releasePossibilities(e.X)
		by, bn := releasePossibilities(e.Y)
		return ay && by, an || bn
	case *constraint.OrExpr:
		ay, an := releasePossibilities(e.X)
		by, bn := releasePossibilities(e.Y)
		return ay || by, an && bn
	default:
		return true, true
	}
}
func stripComments(source string) string {
	b := []byte(source)
	block, line := 0, false
	var quote byte
	escaped := false
	for i := 0; i < len(b); i++ {
		c := b[i]
		if line {
			if c == '\n' {
				line = false
			} else {
				b[i] = ' '
			}
			continue
		}
		if block > 0 {
			if i+1 < len(b) && string(b[i:i+2]) == "/*" {
				block++
				b[i] = ' '
				b[i+1] = ' '
				i++
				continue
			}
			if i+1 < len(b) && string(b[i:i+2]) == "*/" {
				block--
				b[i] = ' '
				b[i+1] = ' '
				i++
				continue
			}
			if c != '\n' {
				b[i] = ' '
			}
			continue
		}
		if quote != 0 {
			if c == quote && !escaped {
				quote = 0
			}
			if c == '\\' && !escaped && quote != '`' {
				escaped = true
			} else {
				escaped = false
			}
			continue
		}
		if c == '"' || c == '\'' || c == '`' {
			quote = c
			continue
		}
		if i+1 < len(b) && string(b[i:i+2]) == "//" {
			line = true
			b[i] = ' '
			b[i+1] = ' '
			i++
			continue
		}
		if i+1 < len(b) && string(b[i:i+2]) == "/*" {
			block = 1
			b[i] = ' '
			b[i+1] = ' '
			i++
		}
	}
	return string(b)
}

// Cgo compiles its preamble comments. Expose those bodies before stripping
// ordinary comments so a Go wrapper cannot conceal an Objective-C SPI call.
func exposeCgoPreamble(path, source string) string {
	if !strings.HasSuffix(path, ".go") {
		return source
	}
	fset := token.NewFileSet()
	file, err := parser.ParseFile(fset, path, source, parser.ParseComments)
	if err != nil {
		return source
	}
	b := []byte(source)
	for _, decl := range file.Decls {
		group, ok := decl.(*ast.GenDecl)
		if !ok || group.Doc == nil {
			continue
		}
		cgo := false
		for _, spec := range group.Specs {
			if imp, ok := spec.(*ast.ImportSpec); ok && imp.Path.Value == `"C"` {
				cgo = true
			}
		}
		if !cgo {
			continue
		}
		for _, comment := range group.Doc.List {
			offset := fset.Position(comment.Pos()).Offset
			if strings.HasPrefix(comment.Text, "/*") {
				b[offset], b[offset+1] = ' ', ' '
				end := offset + len(comment.Text)
				b[end-2], b[end-1] = ' ', ' '
			} else {
				b[offset], b[offset+1] = ' ', ' '
			}
		}
	}
	return string(b)
}

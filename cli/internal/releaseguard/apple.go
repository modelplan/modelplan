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
	"sort"
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

// Harmless grouping parentheses do not turn a literal into a computed key.
const spiGrouping = `(?:\(\s*)*`

var privateSPI = regexp.MustCompile(`\b_webProcessIdentifier\b|\b[Vv]alueForKey(?:Path)?\s*[:(]\s*` + spiGrouping + spiLiteral + `_|\bsetValue\s*:[^;]*\bforKey(?:Path)?\s*:\s*` + spiGrouping + spiLiteral + `_|\b(?:NSSelectorFromString|Selector|sel_registerName|sel_getUid)\s*\(\s*` + spiGrouping + spiLiteral + `_|@selector\s*\(\s*_`)
var swiftKVCCall = regexp.MustCompile(`\b(?:value|setValue)\s*\(`)
var privateKeyLiteral = regexp.MustCompile(`^\s*` + spiGrouping + spiLiteral + `_`)
var branchDirective = regexp.MustCompile(`^#\s*(if|ifdef|ifndef|elif|elseif|else|endif)\b(.*)$`)
var definedTag = regexp.MustCompile(`\bdefined\s*(?:\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)|\s+([A-Za-z_][A-Za-z0-9_]*))`)

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
		directive := branchDirective.FindStringSubmatch(strings.TrimSpace(line))
		command, conditionText := "", ""
		if directive != nil {
			command, conditionText = directive[1], strings.TrimSpace(directive[2])
		}
		switch {
		case command == "if" || command == "ifdef" || command == "ifndef":
			condition := sourceCondition(conditionText)
			if command == "ifndef" {
				condition = &constraint.NotExpr{X: condition}
			}
			stack = append(stack, branch{active, condition})
			active = and(active, condition)
		case (command == "elseif" || command == "elif") && len(stack) > 0:
			b := &stack[len(stack)-1]
			condition := sourceCondition(conditionText)
			active = and(b.parent, and(&constraint.NotExpr{X: b.seen}, condition))
			b.seen = &constraint.OrExpr{X: b.seen, Y: condition}
		case command == "else" && len(stack) > 0:
			b := stack[len(stack)-1]
			active = and(b.parent, &constraint.NotExpr{X: b.seen})
		case command == "endif" && len(stack) > 0:
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
	var positions []int
	for _, match := range privateSPI.FindAllStringIndex(text, -1) {
		positions = append(positions, match[0])
	}
	positions = append(positions, swiftPrivateKeyPositions(text)...)
	sort.Ints(positions)
	previousLine := 0
	for _, position := range positions {
		line := strings.Count(text[:position], "\n") + 1
		if line == previousLine {
			continue
		}
		previousLine = line
		findings = append(findings, Finding{path, line, "private Apple SPI outside " + TestSPIFlag})
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
func sourceCondition(s string) constraint.Expr {
	s = definedTag.ReplaceAllString(s, "${1}${2}")
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

// Swift's value expression may contain arbitrary nested calls. Walk balanced
// argument delimiters and inspect only a top-level forKey/forKeyPath label;
// stopping at the first ')' misses ordinary setters such as makeValue().
func swiftPrivateKeyPositions(text string) []int {
	var positions []int
	for _, match := range swiftKVCCall.FindAllStringIndex(text, -1) {
		depth, braces, brackets := 1, 0, 0
		for i := match[1]; i < len(text) && depth > 0; i++ {
			c := text[i]
			if c == '"' || c == '\'' || c == '`' {
				quote := c
				for i++; i < len(text); i++ {
					if text[i] == '\\' && quote != '`' {
						i++
						continue
					}
					if text[i] == quote {
						break
					}
				}
				continue
			}
			switch c {
			case '(':
				depth++
			case ')':
				depth--
			case '{':
				braces++
			case '}':
				braces--
			case '[':
				brackets++
			case ']':
				brackets--
			}
			if depth != 1 || braces != 0 || brackets != 0 {
				continue
			}
			if i > 0 && identifierByte(text[i-1]) {
				continue
			}
			for _, label := range []string{"forKeyPath", "forKey"} {
				if !strings.HasPrefix(text[i:], label) {
					continue
				}
				end := i + len(label)
				if end < len(text) && identifierByte(text[end]) {
					continue
				}
				for end < len(text) && strings.ContainsRune(" \t\r\n", rune(text[end])) {
					end++
				}
				if end < len(text) && text[end] == ':' && privateKeyLiteral.MatchString(text[end+1:]) {
					positions = append(positions, match[0])
					depth = 0
					break
				}
			}
		}
	}
	return positions
}
func identifierByte(b byte) bool {
	return b >= 'a' && b <= 'z' || b >= 'A' && b <= 'Z' || b >= '0' && b <= '9' || b == '_'
}

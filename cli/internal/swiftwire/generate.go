// SPDX-License-Identifier: MIT
// Package swiftwire generates the Swift DTO client from production Go declarations.
// It is build tooling only and never joins or computes engine state.
package swiftwire

import (
	"bytes"
	_ "embed"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"path/filepath"
	"reflect"
	"sort"
	"strconv"
	"strings"
	"unicode"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/appserver/wireschema"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

//go:embed runtime.swift.txt
var support string

type field struct {
	Go, JSON, Swift        string
	Optional, Omit, Strict bool
	Rule                   map[string]any
}
type declaration struct {
	Pkg, Go, Swift string
	AST            *ast.TypeSpec
	Fields         []field
	Enum           []string
}
type model struct {
	Types map[string]*declaration
	Defs  map[string]any
	Used  map[string]bool
}

func swiftName(pkg, name string) string {
	if pkg == "rows" {
		return "Rows" + name
	}
	return "Wire" + name
}
func quoted(s string) string { return strconv.Quote(s) }
func ident(s string) string  { return "`" + s + "`" }
func enumCase(s string) string {
	if s == "unknown" {
		return "knownUnknown"
	}
	var b strings.Builder
	upper := false
	for _, r := range s {
		if r == '_' || r == '-' {
			upper = true
			continue
		}
		if upper {
			r = unicode.ToUpper(r)
			upper = false
		}
		b.WriteRune(r)
	}
	out := b.String()
	if out == "" {
		return "emptyValue"
	}
	if out[0] >= '0' && out[0] <= '9' {
		out = "value" + out
	}
	return out
}
func load(root string) (*model, error) {
	m := &model{Types: map[string]*declaration{}, Used: map[string]bool{}}
	schema, err := wireschema.Generate(root)
	if err != nil {
		return nil, err
	}
	var doc struct {
		Defs map[string]any `json:"$defs"`
	}
	if err = json.Unmarshal(schema, &doc); err != nil {
		return nil, err
	}
	m.Defs = doc.Defs
	for _, pkg := range []string{"wire", "rows"} {
		dir := "rows"
		if pkg == "wire" {
			dir = "appserver/wire"
		}
		for _, file := range []string{"types.go", "enums.go"} {
			f, err := parser.ParseFile(token.NewFileSet(), filepath.Join(root, "cli/internal", dir, file), nil, 0)
			if err != nil {
				return nil, err
			}
			for _, decl := range f.Decls {
				g, ok := decl.(*ast.GenDecl)
				if !ok {
					continue
				}
				for _, sp := range g.Specs {
					t, ok := sp.(*ast.TypeSpec)
					if !ok || !t.Name.IsExported() {
						continue
					}
					m.Types[pkg+"."+t.Name.Name] = &declaration{Pkg: pkg, Go: t.Name.Name, Swift: swiftName(pkg, t.Name.Name), AST: t}
				}
			}
			for _, decl := range f.Decls {
				g, ok := decl.(*ast.GenDecl)
				if !ok || g.Tok != token.CONST {
					continue
				}
				for _, sp := range g.Specs {
					v := sp.(*ast.ValueSpec)
					id, ok := v.Type.(*ast.Ident)
					if !ok {
						continue
					}
					target := m.Types[pkg+"."+id.Name]
					if target == nil {
						continue
					}
					for _, val := range v.Values {
						lit, ok := val.(*ast.BasicLit)
						if !ok || lit.Kind != token.STRING {
							return nil, fmt.Errorf("unsupported enum expression")
						}
						s, err := strconv.Unquote(lit.Value)
						if err != nil {
							return nil, err
						}
						target.Enum = append(target.Enum, s)
					}
				}
			}
		}
	}
	return m, nil
}
func (m *model) swiftType(pkg string, e ast.Expr) (string, error) {
	switch t := e.(type) {
	case *ast.StarExpr:
		return m.swiftType(pkg, t.X)
	case *ast.Ident:
		basic := map[string]string{"string": "String", "bool": "Bool", "int": "Int", "int64": "Int64", "uint64": "UInt64", "float64": "Double", "T": "T"}
		if s, ok := basic[t.Name]; ok {
			return s, nil
		}
		if pkg == "wire" && t.Name == "ID" {
			return "WireRequestID", nil
		}
		key := pkg + "." + t.Name
		d := m.Types[key]
		if d == nil {
			return "", fmt.Errorf("unsupported type %s", key)
		}
		m.Used[key] = true
		return d.Swift, nil
	case *ast.SelectorExpr:
		p, ok := t.X.(*ast.Ident)
		if !ok {
			return "", fmt.Errorf("unsupported selector")
		}
		if p.Name == "time" && t.Sel.Name == "Time" {
			return "WireTimestamp", nil
		}
		if p.Name == "json" && t.Sel.Name == "RawMessage" {
			return "WireJSONValue", nil
		}
		return m.swiftType(p.Name, t.Sel)
	case *ast.ArrayType:
		if t.Len != nil {
			return "", fmt.Errorf("fixed arrays unsupported")
		}
		s, err := m.swiftType(pkg, t.Elt)
		return "[" + s + "]", err
	case *ast.MapType:
		k, ok := t.Key.(*ast.Ident)
		if !ok || k.Name != "string" {
			return "", fmt.Errorf("non-string map key")
		}
		s, err := m.swiftType(pkg, t.Value)
		return "[String: " + s + "]", err
	case *ast.IndexExpr:
		a, err := m.swiftType(pkg, t.X)
		if err != nil {
			return "", err
		}
		b, err := m.swiftType(pkg, t.Index)
		return a + "<" + b + ">", err
	default:
		return "", fmt.Errorf("unsupported AST type %T", e)
	}
}
func strict(name, field string) bool {
	if name == "WireCredentialResult" || name == "WireConsentGrantParams" || name == "WireConsentReceipt" || name == "WireErrorContext" {
		return true
	}
	switch field {
	case "id", "sessionId", "storeEpoch", "consentGeneration", "expectStoreEpoch", "expectGeneration", "requestId", "operationId", "scope", "tool", "subscriptionRef", "accountLocator", "keychain", "consent", "state", "scopes":
		return true
	}
	return false
}
func (m *model) fields(d *declaration) error {
	if d.AST == nil {
		return nil
	}
	st, ok := d.AST.Type.(*ast.StructType)
	if !ok {
		return nil
	}
	var props map[string]any
	key := d.Go
	if d.Swift == "WireFailure" {
		key = "Error"
	}
	if definition, ok := m.Defs[key].(map[string]any); ok {
		props, _ = definition["properties"].(map[string]any)
	}
	for _, f := range st.Fields.List {
		if len(f.Names) != 1 || f.Tag == nil {
			return fmt.Errorf("unsupported anonymous/untagged wire field")
		}
		tag, err := strconv.Unquote(f.Tag.Value)
		if err != nil {
			return err
		}
		parts := strings.Split(reflect.StructTag(tag).Get("json"), ",")
		if parts[0] == "-" || !f.Names[0].IsExported() {
			continue
		}
		if parts[0] == "" {
			return fmt.Errorf("wire field has no JSON name")
		}
		omit := false
		for _, p := range parts[1:] {
			omit = omit || p == "omitempty"
		}
		_, pointer := f.Type.(*ast.StarExpr)
		s, err := m.swiftType(d.Pkg, f.Type)
		if err != nil {
			return err
		}
		if d.Swift == "WireCancelParams" && parts[0] == "id" {
			s = "WireRequestID"
		}
		rule, _ := props[parts[0]].(map[string]any)
		// The producer schema may constrain a plain Go string before it becomes a typed enum.
		if values, ok := rule["enum"].([]any); ok && s == "String" {
			key := d.Swift + f.Names[0].Name
			e := &declaration{Swift: key}
			for _, v := range values {
				e.Enum = append(e.Enum, v.(string))
			}
			m.Types[key] = e
			m.Used[key] = true
			s = key
		}
		d.Fields = append(d.Fields, field{Go: f.Names[0].Name, JSON: parts[0], Swift: s, Optional: pointer || omit, Omit: omit, Strict: strict(d.Swift, parts[0]), Rule: rule})
	}
	return nil
}
func (m *model) prepare() error {
	// All wire structs are public DTO roots; row input types are never traversed.
	for key, d := range m.Types {
		if d.Pkg == "wire" {
			if _, ok := d.AST.Type.(*ast.StructType); ok {
				m.Used[key] = true
			}
		}
	}
	done := map[string]bool{}
	for {
		keys := []string{}
		for key := range m.Used {
			if !done[key] {
				keys = append(keys, key)
			}
		}
		if len(keys) == 0 {
			break
		}
		sort.Strings(keys)
		for _, key := range keys {
			done[key] = true
			if err := m.fields(m.Types[key]); err != nil {
				return err
			}
		}
	}
	return nil
}
func emitEnum(b *bytes.Buffer, d *declaration) error {
	fmt.Fprintf(b, "public enum %s: Codable, Sendable, Equatable {\n", d.Swift)
	cases := map[string]bool{}
	for _, v := range d.Enum {
		c := enumCase(v)
		if cases[c] {
			return fmt.Errorf("enum case collision")
		}
		cases[c] = true
		fmt.Fprintf(b, "    case %s\n", ident(c))
	}
	fmt.Fprintln(b, "    case unknown(String)\n    public init(rawValue: String) {\n        switch rawValue {")
	for _, v := range d.Enum {
		fmt.Fprintf(b, "        case %s: self = .%s\n", quoted(v), ident(enumCase(v)))
	}
	fmt.Fprintln(b, "        default: self = .unknown(rawValue)\n        }\n    }\n    public var rawValue: String {\n        switch self {")
	for _, v := range d.Enum {
		fmt.Fprintf(b, "        case .%s: return %s\n", ident(enumCase(v)), quoted(v))
	}
	fmt.Fprint(b, "        case .unknown(let value): return value\n        }\n    }\n    public var isKnown: Bool { if case .unknown = self { return false }; return true }\n    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }\n    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }\n}\n")
	return nil
}
func emitStruct(b *bytes.Buffer, d *declaration) {
	generic := ""
	if d.AST.TypeParams != nil {
		generic = "<T: Codable & Sendable>"
	}
	conform := "Codable, Sendable"
	if d.Swift == "WireCredentialResult" || d.Swift == "WireRequest" {
		conform += ", CustomStringConvertible, CustomDebugStringConvertible"
	}
	fmt.Fprintf(b, "public struct %s%s: %s {\n", d.Swift, generic, conform)
	for _, f := range d.Fields {
		optional := ""
		if f.Optional {
			optional = "?"
		}
		fmt.Fprintf(b, "    public let %s: %s%s\n", ident(f.JSON), f.Swift, optional)
	}
	if len(d.Fields) > 0 {
		fmt.Fprintln(b, "    private enum CodingKeys: String, CodingKey {")
		for _, f := range d.Fields {
			fmt.Fprintf(b, "        case %s\n", ident(f.JSON))
		}
		fmt.Fprintln(b, "    }")
	}
	args := []string{}
	for _, f := range d.Fields {
		ty := f.Swift
		if f.Optional {
			ty += "?"
		}
		arg := ident(f.JSON) + ": " + ty
		if f.Optional {
			arg += " = nil"
		}
		args = append(args, arg)
	}
	fmt.Fprintf(b, "    public init(%s) throws {\n", strings.Join(args, ", "))
	for _, f := range d.Fields {
		fmt.Fprintf(b, "        self.%s = %s\n", ident(f.JSON), ident(f.JSON))
	}
	fmt.Fprintln(b, "        try validate()\n    }")
	fmt.Fprintln(b, "    public init(from decoder: Decoder) throws {")
	if len(d.Fields) > 0 {
		fmt.Fprintln(b, "        let c = try decoder.container(keyedBy: CodingKeys.self)")
	} else {
		fmt.Fprintln(b, "        _ = try decoder.container(keyedBy: WireCodingKey.self)")
	}
	if d.Swift == "WireSuccess" || d.Swift == "WireFailure" {
		forbidden := "error"
		if d.Swift == "WireFailure" {
			forbidden = "result"
		}
		fmt.Fprintf(b, "        let extra = try decoder.container(keyedBy: WireCodingKey.self)\n        if extra.allKeys.contains(where: { $0.stringValue == %s }) { throw WireDecodeError.invalidFrame }\n", quoted(forbidden))
	}
	if d.Swift == "WireCredentialResult" {
		fmt.Fprintln(b, "        // Non-success credentials may not carry a token or expiry, even explicit null.\n        let outcome = try c.decode(WireCredentialOutcome.self, forKey: .outcome)\n        if outcome.rawValue != \"ok\" && (c.contains(.accessToken) || c.contains(.expiresAt)) { throw WireDecodeError.invalidAuthorization }")
	}
	for _, f := range d.Fields {
		call := "decode"
		prefix := "try "
		if f.Optional {
			call = "decodeIfPresent"
			if !f.Strict {
				prefix = "try? "
			}
		}
		fmt.Fprintf(b, "        self.%s = %sc.%s(%s.self, forKey: .%s)\n", ident(f.JSON), prefix, call, f.Swift, ident(f.JSON))
	}
	fmt.Fprintln(b, "        try validate()\n    }\n    public func encode(to encoder: Encoder) throws {\n        try validate()")
	if len(d.Fields) > 0 {
		fmt.Fprintln(b, "        var c = encoder.container(keyedBy: CodingKeys.self)")
	} else {
		fmt.Fprintln(b, "        _ = encoder.container(keyedBy: WireCodingKey.self)")
	}
	for _, f := range d.Fields {
		call := "encode"
		if f.Omit {
			call = "encodeIfPresent"
		}
		fmt.Fprintf(b, "        try c.%s(%s, forKey: .%s)\n", call, ident(f.JSON), ident(f.JSON))
	}
	fmt.Fprintln(b, "    }\n    private func validate() throws {")
	for _, f := range d.Fields {
		value := ident(f.JSON)
		switch f.JSON {
		case "id", "sessionId", "storeEpoch", "expectStoreEpoch", "requestId", "operationId", "scope", "tool", "provider":
			if f.Swift == "String" {
				if f.Optional {
					fmt.Fprintf(b, "        if let value = %s { try WireValidation.identity(value) }\n", value)
				} else {
					fmt.Fprintf(b, "        try WireValidation.identity(%s)\n", value)
				}
			}
		case "subscriptionRef", "accountLocator":
			fmt.Fprintf(b, "        if let value = %s { try WireValidation.reference(value) }\n", value)
		}
		if f.JSON == "scopes" && f.Swift == "[String]" {
			values := "scopes"
			if f.Optional {
				values = "(scopes ?? [])"
			}
			fmt.Fprintf(b, "        for scope in %s { try WireValidation.identity(scope) }\n", values)
		}
		// Bounds originate in the producer schema rather than a second hand-written limit.
		if low, ok := f.Rule["minimum"].(float64); ok && !f.Optional {
			fmt.Fprintf(b, "        guard %s >= %v else { throw WireDecodeError.invalidBound }\n", value, low)
		}
		if high, ok := f.Rule["maximum"].(float64); ok && !f.Optional {
			fmt.Fprintf(b, "        guard %s <= %v else { throw WireDecodeError.invalidBound }\n", value, high)
		}
		switch f.Swift {
		case "RowsConsent", "WireConsentState", "WireCredentialOutcome", "RowsKind":
			fmt.Fprintf(b, "        guard %s.isKnown else { throw WireDecodeError.invalidAuthorization }\n", value)
		case "WireKeychainChoice":
			if f.Optional {
				fmt.Fprintf(b, "        if let value = %s, !value.isKnown { throw WireDecodeError.invalidAuthorization }\n", value)
			}
		}
	}
	switch d.Swift {
	case "WireRequest", "WireSuccess", "WireNotification", "WireFailure":
		fmt.Fprintln(b, "        guard jsonrpc == WireProtocol.jsonrpc else { throw WireDecodeError.invalidVersion }")
		if d.Swift == "WireRequest" {
			fmt.Fprintln(b, "        try WireValidation.identity(method)\n        if method == \"credentials/result\" {\n            guard let params = params else { throw WireDecodeError.invalidAuthorization }\n            _ = try WireDecoder.decode(WireCredentialResult.self, from: JSONEncoder().encode(params))\n        }")
		}
	case "WireInitializeParams", "WireInitializeResult":
		fmt.Fprintln(b, "        try WireValidation.protocolVersion(protocolVersion)")
	case "RowsProjection":
		fmt.Fprintln(b, "        guard rowsVersion == WireProtocol.rowsVersion else { throw WireDecodeError.invalidVersion }\n        guard Set(rows.map { $0.id }).count == rows.count else { throw WireDecodeError.invalidIdentity }")
	case "RowsRow":
		fmt.Fprintln(b, "        try WireValidation.identity(id)\n        if kind.rawValue == \"tool\" { try WireValidation.toolID(id) }\n        if kind.rawValue == \"declared\" && (!id.hasPrefix(\"declared:\") || id.count <= 9) { throw WireDecodeError.invalidIdentity }\n        if [\"denied\", \"unset\", \"retired\"].contains(consent.rawValue) && !accounts.isEmpty { throw WireDecodeError.invalidAuthorization }")
	case "WireConsentGrantParams":
		fmt.Fprintln(b, "        for scope in allow + deny + (forget ?? []) { try WireValidation.identity(scope) }\n        for (scope, choice) in keychain ?? [:] {\n            try WireValidation.identity(scope)\n            guard [\"allow\", \"deny\"].contains(choice.rawValue) else { throw WireDecodeError.invalidAuthorization }\n        }")
	case "WireConsentReceipt":
		fmt.Fprintln(b, "        if committed && committedGeneration == nil { throw WireDecodeError.invalidAuthorization }\n        guard code.isKnown else { throw WireDecodeError.invalidAuthorization }")
	case "WireCredentialResult":
		fmt.Fprintln(b, "        if outcome.rawValue == \"ok\" {\n            guard let token = accessToken, !token.isEmpty else { throw WireDecodeError.invalidAuthorization }\n        } else if accessToken != nil || expiresAt != nil { throw WireDecodeError.invalidAuthorization }")
	case "WireEnvelope":
		fmt.Fprintln(b, "        if let snapshot = data as? WireRowsSnapshot, snapshot.projection.consentGeneration != consentGeneration { throw WireDecodeError.invalidAuthorization }")
	}
	fmt.Fprintln(b, "    }")
	if d.Swift == "WireCredentialResult" {
		fmt.Fprintln(b, "    public var description: String { \"WireCredentialResult([redacted])\" }\n    public var debugDescription: String { description }")
	}
	if d.Swift == "WireRequest" {
		fmt.Fprintln(b, "    public var description: String { \"WireRequest([redacted params])\" }\n    public var debugDescription: String { description }")
	}
	fmt.Fprint(b, "}\n\n")
}

// Generate derives field presence/nullability from JSON tags and pointer syntax.
func Generate(root string) ([]byte, error) {
	m, err := load(root)
	if err != nil {
		return nil, err
	}
	if err = m.prepare(); err != nil {
		return nil, err
	}
	var b bytes.Buffer
	fmt.Fprint(&b, "// SPDX-License-Identifier: MIT\n// Code generated from Go wire DTOs and JSON tags. DO NOT EDIT.\n// Regenerate: cd cli && go run ./internal/swiftwire/cmd --write\nimport Foundation\n")
	fmt.Fprintf(&b, "public enum WireProtocol {\n    public static let version = %s\n    public static let jsonrpc = %s\n    public static let rowsVersion = %d\n    public static let maxFrameBytes = %d\n}\n\n", quoted(wire.ProtocolVersion), quoted(wire.JSONRPC), rows.Version, wire.MaxFrameBytes)
	b.WriteString(support)
	b.WriteString("\n")
	keys := []string{}
	for key := range m.Used {
		keys = append(keys, key)
	}
	sort.Slice(keys, func(i, j int) bool { return m.Types[keys[i]].Swift < m.Types[keys[j]].Swift })
	for _, key := range keys {
		d := m.Types[key]
		if len(d.Enum) > 0 {
			if err = emitEnum(&b, d); err != nil {
				return nil, err
			}
		} else {
			emitStruct(&b, d)
		}
	}
	return append(bytes.TrimRight(b.Bytes(), "\n"), '\n'), nil
}

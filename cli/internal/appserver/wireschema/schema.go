// SPDX-License-Identifier: MIT
// Package wireschema generates the schema from production wire types. It is
// build/test tooling and is not imported by the running app-server.
package wireschema

import (
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
	"time"

	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
)

type object = map[string]any

type builder struct {
	defs  object
	enums map[string][]string
}

// Generate uses the checkout's typed constants as the enum source. root is the
// repository root, supplied explicitly so the generator never searches HOME.
func Generate(root string) ([]byte, error) {
	b := builder{defs: object{}, enums: map[string][]string{}}
	for _, pkg := range []string{"appserver/wire", "rows"} {
		path := filepath.Join(root, "cli/internal", pkg, "enums.go")
		f, err := parser.ParseFile(token.NewFileSet(), path, nil, 0)
		if err != nil {
			return nil, err
		}
		for _, d := range f.Decls {
			g, ok := d.(*ast.GenDecl)
			if !ok || g.Tok != token.CONST {
				continue
			}
			var lastType string
			for _, spec := range g.Specs {
				v := spec.(*ast.ValueSpec)
				if id, ok := v.Type.(*ast.Ident); ok {
					lastType = id.Name
				} else if len(v.Values) > 0 {
					lastType = ""
				}
				if lastType == "" {
					continue
				}
				for _, value := range v.Values {
					lit, ok := value.(*ast.BasicLit)
					if !ok || lit.Kind != token.STRING {
						continue
					}
					s, err := strconv.Unquote(lit.Value)
					if err != nil {
						return nil, err
					}
					b.enums[f.Name.Name+"."+lastType] = append(b.enums[f.Name.Name+"."+lastType], s)
				}
			}
		}
	}
	// Named schema roots keep generated consumers independent of reflection's
	// spelling of generic instantiations.
	roots := map[string]reflect.Type{
		"InitializeParams":     reflect.TypeFor[wire.InitializeParams](),
		"InitializeResult":     reflect.TypeFor[wire.InitializeResult](),
		"RowsSnapshot":         reflect.TypeFor[wire.RowsSnapshot](),
		"ConsentFacts":         reflect.TypeFor[wire.ConsentFacts](),
		"ConsentGrantParams":   reflect.TypeFor[wire.ConsentGrantParams](),
		"ConsentReceipt":       reflect.TypeFor[wire.ConsentReceipt](),
		"CredentialRequest":    reflect.TypeFor[wire.CredentialRequest](),
		"CredentialResult":     reflect.TypeFor[wire.CredentialResult](),
		"Diagnostics":          reflect.TypeFor[wire.Diagnostics](),
		"Health":               reflect.TypeFor[wire.Health](),
		"HistoryQueryParams":   reflect.TypeFor[wire.HistoryQueryParams](),
		"HistoryPage":          reflect.TypeFor[wire.HistoryPage](),
		"RefreshRequestParams": reflect.TypeFor[wire.RefreshRequestParams](),
		"RefreshScheduled":     reflect.TypeFor[wire.RefreshScheduled](),
		"CancelParams":         reflect.TypeFor[wire.CancelParams](),
		"Error":                reflect.TypeFor[wire.Failure](),
	}
	for name, t := range roots {
		b.defs[name] = b.schema(t, false)
	}
	// Conditional token placement and the grant choice are semantic constraints
	// beyond field shape. A denied/canceled result cannot carry a token.
	cred := b.defs["CredentialResult"].(object)
	cred["if"] = object{"properties": object{"outcome": object{"const": "ok"}}}
	cred["then"] = object{"required": []string{"accessToken"}, "properties": object{"accessToken": object{"type": "string", "minLength": 1}}}
	cred["else"] = object{"not": object{"anyOf": []any{object{"required": []string{"accessToken"}}, object{"required": []string{"expiresAt"}}}}}
	grant := b.defs["ConsentGrantParams"].(object)
	grant["properties"].(object)["keychain"] = object{"type": "object", "additionalProperties": object{"type": "string", "enum": []string{"allow", "deny"}}}
	history := b.defs["HistoryQueryParams"].(object)["properties"].(object)
	history["limit"] = object{"type": "integer", "minimum": 1, "maximum": 500}
	history["kind"] = object{"enum": []string{"tokens", "quota_cycles", "sessions"}}
	b.defs["RequestID"] = object{"anyOf": []any{object{"type": "string"}, object{"type": "integer"}}}
	incoming := []any{}
	requestMethods := map[string]string{"initialize": "InitializeParams", "shutdown": "", "rows/subscribe": "", "consent/get": "", "consent/grant": "ConsentGrantParams", "credentials/result": "CredentialResult", "diagnostics/get": "", "$/cancel": "CancelParams", "history/query": "HistoryQueryParams", "refresh/request": "RefreshRequestParams"}
	for _, method := range sortedKeys(requestMethods) {
		param := requestMethods[method]
		props := object{"jsonrpc": object{"const": wire.JSONRPC}, "method": object{"const": method}, "id": object{"$ref": "#/$defs/RequestID"}}
		required := []string{"jsonrpc", "method"}
		if method != "$/cancel" {
			required = append(required, "id")
		}
		if param != "" {
			props["params"] = object{"$ref": "#/$defs/" + param}
			required = append(required, "params")
		} else {
			props["params"] = object{"type": "object", "maxProperties": 0}
		}
		incoming = append(incoming, object{"type": "object", "properties": props, "required": required, "additionalProperties": false})
	}
	b.defs["Request"] = object{"oneOf": incoming}
	envelopes := []any{}
	for _, name := range []string{"InitializeResult", "RowsSnapshot", "ConsentFacts", "ConsentReceipt", "Diagnostics", "Health", "HistoryPage"} {
		env := b.schema(reflect.TypeFor[wire.Envelope[wire.Empty]](), false).(object)
		env["properties"].(object)["data"] = object{"$ref": "#/$defs/" + name}
		b.defs[name+"Envelope"] = env
		envelopes = append(envelopes, object{"$ref": "#/$defs/" + name + "Envelope"})
	}
	empty := b.schema(reflect.TypeFor[wire.Envelope[wire.Empty]](), false)
	envelopes = append(envelopes, empty)
	b.defs["Response"] = object{"anyOf": []any{object{"$ref": "#/$defs/Error"}, object{"type": "object", "properties": object{"jsonrpc": object{"const": wire.JSONRPC}, "id": object{"$ref": "#/$defs/RequestID"}, "result": object{"anyOf": envelopes}}, "required": []string{"jsonrpc", "id", "result"}, "additionalProperties": false}}}
	notifications := []any{}
	notificationMethods := map[string]string{"rows/changed": "RowsSnapshot", "consent/changed": "ConsentFacts", "credentials/request": "CredentialRequest", "engine/health": "Health"}
	for _, method := range sortedKeys(notificationMethods) {
		name := notificationMethods[method]
		env := b.schema(reflect.TypeFor[wire.Envelope[wire.Empty]](), false).(object)
		env["properties"].(object)["data"] = object{"$ref": "#/$defs/" + name}
		notifications = append(notifications, object{"type": "object", "properties": object{"jsonrpc": object{"const": wire.JSONRPC}, "method": object{"const": method}, "params": env}, "required": []string{"jsonrpc", "method", "params"}, "additionalProperties": false})
	}
	b.defs["Notification"] = object{"oneOf": notifications}
	doc := object{"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "https://modelplan.ai/schema/app-cli/app-server.json", "$comment": "SPDX-License-Identifier: MIT. Generated from appserver/wire and rows; run go run ./internal/appserver/wire/cmd/schema.", "$defs": b.defs, "anyOf": []any{object{"$ref": "#/$defs/Request"}, object{"$ref": "#/$defs/Response"}, object{"$ref": "#/$defs/Notification"}}, "x-limits": object{"frameBytes": wire.MaxFrameBytes, "requests": wire.MaxRequests, "queries": wire.MaxQueries, "credentialsPerProvider": wire.MaxCredentialsPerProvider, "dataMessages": wire.MaxDataMessages, "controlMessages": wire.MaxControlMessages, "controlBytes": wire.MaxControlBytes, "writeTimeoutSeconds": wire.WriteTimeout.Seconds()}}
	data, err := json.MarshalIndent(doc, "", "  ")
	return append(data, '\n'), err
}

func (b *builder) schema(t reflect.Type, ref bool) any {
	if t == reflect.TypeFor[json.RawMessage]() {
		return object{}
	}
	if t == reflect.TypeFor[time.Time]() {
		return object{"type": "string", "format": "date-time"}
	}
	if t.Kind() == reflect.Pointer {
		return object{"anyOf": []any{b.schema(t.Elem(), true), object{"type": "null"}}}
	}
	if values := b.enums[t.String()]; len(values) > 0 {
		return object{"type": "string", "enum": values}
	}
	switch t.Kind() {
	case reflect.String:
		return object{"type": "string"}
	case reflect.Bool:
		return object{"type": "boolean"}
	case reflect.Int, reflect.Int64:
		return object{"type": "integer"}
	case reflect.Uint64:
		return object{"type": "integer", "minimum": 0}
	case reflect.Float64:
		return object{"type": "number"}
	case reflect.Slice:
		return object{"type": "array", "items": b.schema(t.Elem(), true)}
	case reflect.Map:
		return object{"type": "object", "additionalProperties": b.schema(t.Elem(), true)}
	case reflect.Struct:
		name := t.Name()
		if ref && name != "" {
			if _, ok := b.defs[name]; !ok {
				b.defs[name] = object{}
				b.defs[name] = b.schema(t, false)
			}
			return object{"$ref": "#/$defs/" + name}
		}
		props := object{}
		required := []string{}
		for i := 0; i < t.NumField(); i++ {
			field := t.Field(i)
			tag := strings.Split(field.Tag.Get("json"), ",")
			name := tag[0]
			if name == "-" || !field.IsExported() {
				continue
			}
			if name == "" {
				name = field.Name
			}
			props[name] = b.schema(field.Type, true)
			optional := false
			for _, option := range tag[1:] {
				optional = optional || option == "omitempty"
			}
			if !optional {
				required = append(required, name)
			}
		}
		return object{"type": "object", "properties": props, "required": required, "additionalProperties": false}
	default:
		panic(fmt.Sprintf("unsupported wire type %v", t))
	}
}

func sortedKeys(m map[string]string) []string {
	keys := make([]string, 0, len(m))
	for key := range m {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	return keys
}

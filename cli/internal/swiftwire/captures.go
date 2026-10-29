// SPDX-License-Identifier: MIT
package swiftwire

import (
	"encoding/json"
	"fmt"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"reflect"
	"sort"
	"strings"
	"time"
)

type captureRoot struct {
	Name, Swift string
	Type        reflect.Type
}

func captureRoots() []captureRoot {
	roots := []reflect.Type{
		reflect.TypeFor[wire.Request](), reflect.TypeFor[wire.ErrorContext](), reflect.TypeFor[wire.RPCError](), reflect.TypeFor[wire.Failure](),
		reflect.TypeFor[wire.InitializeParams](), reflect.TypeFor[wire.InitializeResult](), reflect.TypeFor[wire.Empty](), reflect.TypeFor[wire.CancelParams](),
		reflect.TypeFor[wire.RowsSnapshot](), reflect.TypeFor[wire.ConsentScope](), reflect.TypeFor[wire.ConsentFacts](), reflect.TypeFor[wire.ConsentGrantParams](), reflect.TypeFor[wire.ConsentReceipt](),
		reflect.TypeFor[wire.CredentialRequest](), reflect.TypeFor[wire.CredentialResult](), reflect.TypeFor[wire.RefreshRequestParams](), reflect.TypeFor[wire.RefreshScheduled](), reflect.TypeFor[wire.PluginInstallParams](), reflect.TypeFor[wire.PluginInstallResult](), reflect.TypeFor[wire.PublicationResult](), reflect.TypeFor[wire.PublicationUnits](), reflect.TypeFor[wire.PublicationCapability](), reflect.TypeFor[wire.CockpitData](), reflect.TypeFor[wire.CockpitSubscription](), reflect.TypeFor[wire.CockpitAccount](),
		reflect.TypeFor[wire.HistoryQueryParams](), reflect.TypeFor[wire.HistoryItem](), reflect.TypeFor[wire.HistoryPage](), reflect.TypeFor[wire.Diagnostics](), reflect.TypeFor[wire.ScopeDiag](), reflect.TypeFor[wire.Health](),
		reflect.TypeFor[rows.Text](), reflect.TypeFor[rows.Name](), reflect.TypeFor[rows.Reason](), reflect.TypeFor[rows.NextStep](), reflect.TypeFor[rows.Row](), reflect.TypeFor[rows.ExpiryState](),
		reflect.TypeFor[rows.Account](), reflect.TypeFor[rows.Plan](), reflect.TypeFor[rows.Credits](), reflect.TypeFor[rows.Failure](), reflect.TypeFor[rows.Window](), reflect.TypeFor[rows.RowsSummary](), reflect.TypeFor[wire.RowsProjection](),
	}
	out := []captureRoot{}
	for _, t := range roots {
		pkg := "wire"
		if strings.HasSuffix(t.PkgPath(), "/rows") {
			pkg = "rows"
		}
		name := swiftName(pkg, t.Name())
		out = append(out, captureRoot{name, name, t})
	}
	return append(out,
		captureRoot{"WireEnvelope", "WireEnvelope<WireRowsSnapshot>", reflect.TypeFor[wire.Envelope[wire.RowsSnapshot]]()},
		captureRoot{"WireSuccess", "WireSuccess<WireRowsSnapshot>", reflect.TypeFor[wire.Success[wire.RowsSnapshot]]()},
		captureRoot{"WireNotification", "WireNotification<WireRowsSnapshot>", reflect.TypeFor[wire.Notification[wire.RowsSnapshot]]()},
	)
}
func (m *model) seed(t reflect.Type, name string) (reflect.Value, error) {
	if t == reflect.TypeFor[wire.PluginInstallResult]() {
		return reflect.ValueOf(wire.PluginInstallResult{SchemaVersion: 1, Tool: wire.PluginCodex,
			Status: wire.PluginPlanned, Commands: [][]string{{"codex", "plugin", "marketplace", "add", "modelplan/modelplan"}, {"codex", "plugin", "add", "modelplan-codex@modelplan"}},
			Completed: 0, Docs: "https://github.com/modelplan/modelplan/tree/main/codex"}), nil
	}
	if t == reflect.TypeFor[time.Time]() {
		return reflect.ValueOf(time.Date(2026, 10, 29, 12, 0, 0, 123456789, time.UTC)), nil
	}
	if t == reflect.TypeFor[json.RawMessage]() {
		value := `{}`
		if name == "ID" {
			value = `9007199254740993`
		}
		return reflect.ValueOf(json.RawMessage(value)), nil
	}
	if t.Kind() == reflect.Pointer {
		v, err := m.seed(t.Elem(), name)
		if err != nil {
			return reflect.Value{}, err
		}
		p := reflect.New(t.Elem())
		p.Elem().Set(v)
		return p, nil
	}
	v := reflect.New(t).Elem()
	switch t.Kind() {
	case reflect.String:
		s := "synthetic"
		pkg := "wire"
		if strings.HasSuffix(t.PkgPath(), "/rows") {
			pkg = "rows"
		}
		if d := m.Types[pkg+"."+t.Name()]; d != nil && len(d.Enum) > 0 {
			s = d.Enum[0]
		} else {
			switch name {
			case "JSONRPC":
				s = wire.JSONRPC
			case "ProtocolVersion":
				s = wire.ProtocolVersion
			case "ID", "Tool":
				s = "codex"
			case "SessionID":
				s = "s-synthetic"
			case "StoreEpoch", "ExpectStoreEpoch":
				s = "e-synthetic"
			case "Scope":
				s = "codex.runtime_usage"
			case "SubscriptionRef", "AccountLocator":
				s = "0123456789abcdef"
			case "AccessToken":
				s = "TOKEN-CANARY-U4"
			case "Provider":
				s = "claude"
			case "Kind":
				s = "tokens"
			}
		}
		v.SetString(s)
	case reflect.Bool:
		v.SetBool(false)
	case reflect.Int, reflect.Int64:
		v.SetInt(1)
	case reflect.Uint64:
		v.SetUint(7)
	case reflect.Float64:
		v.SetFloat(42.5)
	case reflect.Slice:
		v = reflect.MakeSlice(t, 1, 1)
		elem, err := m.seed(t.Elem(), name)
		if err != nil {
			return reflect.Value{}, err
		}
		v.Index(0).Set(elem)
	case reflect.Map:
		v = reflect.MakeMap(t)
		elem, err := m.seed(t.Elem(), name)
		if err != nil {
			return reflect.Value{}, err
		}
		v.SetMapIndex(reflect.ValueOf("codex.runtime_usage"), elem)
	case reflect.Struct:
		for i := 0; i < t.NumField(); i++ {
			f := t.Field(i)
			if !f.IsExported() {
				continue
			}
			elem, err := m.seed(f.Type, f.Name)
			if err != nil {
				return reflect.Value{}, err
			}
			v.Field(i).Set(elem)
		}
	default:
		return reflect.Value{}, fmt.Errorf("unsupported capture seed %s", t)
	}
	return v, nil
}

type mutation struct {
	Field     string `json:"field"`
	Omission  bool   `json:"omission"`
	Null      bool   `json:"null"`
	WrongType bool   `json:"wrongType"`
	Strict    bool   `json:"strict"`
}
type captureCase struct {
	File     string     `json:"file"`
	Type     string     `json:"type"`
	Optional []mutation `json:"optional"`
	Required []string   `json:"required"`
}
type captureIndex struct {
	Version int           `json:"version"`
	Cases   []captureCase `json:"cases"`
}

// Captures marshals the production Go types, not a separately transcribed JSON fixture.
func Captures(root string) (map[string][]byte, error) {
	m, err := load(root)
	if err != nil {
		return nil, err
	}
	if err = m.prepare(); err != nil {
		return nil, err
	}
	files := map[string][]byte{}
	index := captureIndex{Version: 1, Cases: []captureCase{}}
	roots := captureRoots()
	sort.Slice(roots, func(i, j int) bool { return roots[i].Name < roots[j].Name })
	covered := map[string]bool{}
	var dispatcher strings.Builder
	dispatcher.WriteString("// SPDX-License-Identifier: MIT\n// Code generated from Go capture roots. DO NOT EDIT.\nimport Foundation\nimport ModelPlanWire\n\nfunc decodeCapture(_ type: String, _ data: Data) throws {\n    switch type {\n")
	for _, r := range roots {
		covered[r.Name] = true
		v, err := m.seed(r.Type, "")
		if err != nil {
			return nil, err
		}
		b, err := json.MarshalIndent(v.Interface(), "", "  ")
		if err != nil {
			return nil, err
		}
		files[r.Name+".json"] = append(b, '\n')
		c := captureCase{File: r.Name + ".json", Type: r.Swift, Optional: []mutation{}, Required: []string{}}
		var d *declaration
		for _, candidate := range m.Types {
			if candidate.Swift == r.Name {
				d = candidate
				break
			}
		}
		if d == nil {
			return nil, fmt.Errorf("capture root missing: %s", r.Name)
		}
		for _, f := range d.Fields {
			if f.Optional {
				safeNull := !(r.Name == "WireCredentialResult" && f.JSON == "accessToken")
				c.Optional = append(c.Optional, mutation{Field: f.JSON, Omission: safeNull && !f.RequiredNullable, Null: safeNull, WrongType: !f.Strict || f.Swift == "WireJSONValue", Strict: f.Strict})
			} else {
				c.Required = append(c.Required, f.JSON)
			}
		}
		index.Cases = append(index.Cases, c)
		fmt.Fprintf(&dispatcher, "    case %s: _ = try WireDecoder.decode(%s.self, from: data)\n", quoted(r.Swift), r.Swift)
	}
	for key := range m.Used {
		d := m.Types[key]
		if len(d.Enum) == 0 && !covered[d.Swift] {
			return nil, fmt.Errorf("new DTO needs a capture root: %s", d.Swift)
		}
	}
	dispatcher.WriteString("    default: throw WireDecodeError.invalidIdentity\n    }\n}\n")
	files["CaptureTypes.swift"] = []byte(dispatcher.String())
	b, err := json.MarshalIndent(index, "", "  ")
	if err != nil {
		return nil, err
	}
	files["index.json"] = append(b, '\n')
	// A row projection from the production builder is kept in addition to full-field DTO captures.
	input := rows.Input{Now: time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC), ConsentGeneration: 7, DeclaredPlanIDs: []string{"team"}}
	projection := rows.Build(input)
	if err = rows.Validate(input, projection); err != nil {
		return nil, err
	}
	b, err = json.MarshalIndent(wire.Success[wire.RowsSnapshot]{JSONRPC: wire.JSONRPC, ID: json.RawMessage(`9007199254740993`), Result: wire.Envelope[wire.RowsSnapshot]{SessionID: "s-synthetic", StoreEpoch: "e-synthetic", ConsentGeneration: 7, Data: wire.RowsSnapshot{Sequence: 1, Projection: wire.Project(projection)}}}, "", "  ")
	if err != nil {
		return nil, err
	}
	files["production-rows.json"] = append(b, '\n')
	b, err = json.MarshalIndent(wire.Failure{JSONRPC: wire.JSONRPC, ID: json.RawMessage("null"), Error: wire.RPCError{Code: wire.CodeParseError, Message: wire.ErrorName(wire.CodeParseError), Data: wire.ErrorContext{SessionID: "s-synthetic"}}}, "", "  ")
	if err != nil {
		return nil, err
	}
	files["null-error.json"] = append(b, '\n')
	files["retired-with-account.json"], err = retiredAccountCapture()
	if err != nil {
		return nil, err
	}
	return files, nil
}

// retiredAccountCapture is built and validated by the real projector. Retirement
// preserves admitted accounts; it is not revocation or an unset grant.
func retiredAccountCapture() ([]byte, error) {
	now := time.Date(2026, 10, 29, 12, 0, 0, 0, time.UTC)
	observed, fresh, resets := now.Add(-time.Minute), now.Add(time.Hour), now.Add(2*time.Hour)
	duration := int64(18000)
	remaining := 75.0
	input := rows.Input{Now: now, ConsentGeneration: 7,
		Catalogue: []rows.CatalogueEntry{
			{ToolID: "codex", Detected: true, ReaderExists: true, Retired: true},
			{ToolID: "claude", Detected: true, ReaderExists: true},
		},
		Consents: []rows.ConsentRecord{
			{ToolID: "codex", State: rows.ConsentAllowed, Generation: 7},
			{ToolID: "claude", State: rows.ConsentAllowed, Generation: 7},
		},
	}
	for _, tool := range []string{"codex", "claude"} {
		route := rows.RouteRuntimeRPC
		if tool == "claude" {
			route = rows.RouteSavedLoginAPI
		}
		input.Profiles = append(input.Profiles, rows.ProfileState{ToolID: tool, ProfileKey: tool, LatestAttempt: rows.AttemptResultSucceeded, ObservedAt: &observed, WithinFreshness: true, FreshUntil: &fresh})
		input.Accounts = append(input.Accounts, rows.AccountInput{ToolID: tool, ProfileKey: tool, Source: "native:" + tool, Route: route, PlanID: "pro", Windows: []rows.WindowInput{{Kind: "five_hour", DurationSeconds: &duration, RemainingPercent: &remaining, ObservedAt: &observed, ResetsAt: &resets}}})
	}
	projection := rows.Build(input)
	if err := rows.Validate(input, projection); err != nil {
		return nil, err
	}
	message := wire.Success[wire.RowsSnapshot]{JSONRPC: wire.JSONRPC, ID: json.RawMessage(`31`), Result: wire.Envelope[wire.RowsSnapshot]{SessionID: "s-retired", StoreEpoch: "e-retired", ConsentGeneration: 7, Scopes: []string{"claude.account_usage.saved_login", "codex.runtime_usage"}, Data: wire.RowsSnapshot{Sequence: 1, Projection: wire.Project(projection)}}}
	b, err := json.MarshalIndent(message, "", "  ")
	return append(b, '\n'), err
}

// SPDX-License-Identifier: MIT
package desktopcontract_test

import (
	"bytes"
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"reflect"
	"runtime"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/desktopcontract"
	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
	"github.com/santhosh-tekuri/jsonschema/v6"
)

var updateContract = flag.Bool("update-contract", false, "explicitly regenerate reviewed v1 schemas and synthetic goldens")

func root() string {
	_, f, _, _ := runtime.Caller(0)
	return filepath.Clean(filepath.Join(filepath.Dir(f), "../../.."))
}
func encoded(t *testing.T, v any) []byte {
	t.Helper()
	b, e := json.MarshalIndent(v, "", "  ")
	if e != nil {
		t.Fatal(e)
	}
	return append(b, '\n')
}
func value(t *testing.T, b []byte) any {
	t.Helper()
	v, e := jsonschema.UnmarshalJSON(bytes.NewReader(b))
	if e != nil {
		t.Fatal(e)
	}
	return v
}
func schema(t *testing.T, name string) *jsonschema.Schema {
	t.Helper()
	p := filepath.Join(root(), "schema", name+"-v1.json")
	b, e := os.ReadFile(p)
	if e != nil {
		t.Fatal(e)
	}
	c := jsonschema.NewCompiler()
	c.AssertFormat()
	if e = c.AddResource("https://example.test/"+name+"-v1.json", value(t, b)); e != nil {
		t.Fatal(e)
	}
	s, e := c.Compile("https://example.test/" + name + "-v1.json")
	if e != nil {
		t.Fatal(e)
	}
	return s
}

// A bootstrapping aid, never executed by normal tests. Committed schemas are
// independently compiled and validated; existing goldens detect producer drift.
func reflected(t reflect.Type, defs map[string]any) map[string]any {
	if t == reflect.TypeOf(json.RawMessage{}) {
		return map[string]any{}
	}
	if t == reflect.TypeOf(time.Time{}) {
		return map[string]any{"type": "string", "format": "date-time"}
	}
	if t.Kind() == reflect.Pointer {
		return map[string]any{"anyOf": []any{reflected(t.Elem(), defs), map[string]any{"type": "null"}}}
	}
	switch t.Kind() {
	case reflect.Bool:
		return map[string]any{"type": "boolean"}
	case reflect.String:
		return map[string]any{"type": "string"}
	case reflect.Int, reflect.Int8, reflect.Int16, reflect.Int32, reflect.Int64:
		return map[string]any{"type": "integer"}
	case reflect.Uint, reflect.Uint64:
		return map[string]any{"type": "integer", "minimum": 0}
	case reflect.Float32, reflect.Float64:
		return map[string]any{"type": "number"}
	case reflect.Slice, reflect.Array:
		return map[string]any{"type": []string{"array", "null"}, "items": reflected(t.Elem(), defs)}
	case reflect.Map:
		return map[string]any{"type": []string{"object", "null"}, "additionalProperties": reflected(t.Elem(), defs)}
	case reflect.Interface:
		return map[string]any{}
	case reflect.Struct:
		name := filepath.Base(t.PkgPath()) + "-" + t.Name()
		if _, ok := defs[name]; ok {
			return map[string]any{"$ref": "#/$defs/" + name}
		}
		defs[name] = map[string]any{}
		props := map[string]any{}
		required := []string{}
		var fields func(reflect.Type)
		fields = func(typ reflect.Type) {
			for i := 0; i < typ.NumField(); i++ {
				f := typ.Field(i)
				if f.Anonymous {
					fields(f.Type)
					continue
				}
				if f.PkgPath != "" {
					continue
				}
				tag := f.Tag.Get("json")
				parts := strings.Split(tag, ",")
				if parts[0] == "-" {
					continue
				}
				n := parts[0]
				if n == "" {
					n = f.Name
				}
				props[n] = reflected(f.Type, defs)
				if !strings.Contains(tag, ",omitempty") {
					required = append(required, n)
				}
			}
		}
		fields(t)
		defs[name] = map[string]any{"type": "object", "properties": props, "required": required, "additionalProperties": true}
		return map[string]any{"$ref": "#/$defs/" + name}
	}
	panic(t.String())
}
func freezeSchema(v any, name string) map[string]any {
	defs := map[string]any{}
	ref := reflected(reflect.TypeOf(v), defs)
	definition := defs[strings.TrimPrefix(ref["$ref"].(string), "#/$defs/")].(map[string]any)
	props := definition["properties"].(map[string]any)
	caps := desktopcontract.PersonalCapabilities()
	if name == "publication" {
		caps = desktopcontract.PublicationCapabilities()
	}
	requiredCaps := []string{}
	for key := range caps {
		requiredCaps = append(requiredCaps, key)
	}
	sort.Strings(requiredCaps)
	props["capabilities"] = map[string]any{"type": "object", "required": requiredCaps, "additionalProperties": map[string]any{"$ref": "#/$defs/desktopcontract-Capability"}}
	defs["desktopcontract-Capability"].(map[string]any)["properties"].(map[string]any)["status"] = map[string]any{"enum": []string{"supported", "source-dependent", "publication-dependent", "unavailable"}}
	props["contractVersion"] = map[string]any{"const": 1}
	props["schemaVersion"] = map[string]any{"const": 1}
	if name == "desktop" {
		props["kind"] = map[string]any{"const": "modelplan.personal-snapshot"}
	}
	if name == "publication" {
		props["publishedAt"] = map[string]any{"type": []string{"string", "null"}, "format": "date-time"}
		nullableNumber := map[string]any{"type": []string{"number", "null"}}
		effort := map[string]any{"type": "object", "required": []string{"effort"}, "properties": map[string]any{"effort": map[string]any{"type": "string", "minLength": 1}, "label": map[string]any{"type": "string"}, "ability": nullableNumber, "cost": nullableNumber, "time": nullableNumber, "abilityBasis": map[string]any{"type": "string"}, "costBasisId": map[string]any{"type": "string"}, "timeEstimated": map[string]any{"type": "boolean"}, "timeBasis": map[string]any{"type": []string{"object", "null"}}}, "additionalProperties": true}
		model := map[string]any{"type": "object", "required": []string{"id", "developerId", "harnessIds"}, "properties": map[string]any{"id": map[string]any{"type": "string", "minLength": 1}, "name": map[string]any{"type": "string"}, "developerId": map[string]any{"type": "string", "minLength": 1}, "recommended": map[string]any{"type": "string"}, "harnessIds": map[string]any{"type": "object", "additionalProperties": map[string]any{"type": []string{"array", "null"}, "items": map[string]any{"type": "string"}}}, "efforts": map[string]any{"type": []string{"array", "null"}, "items": effort}}, "additionalProperties": true}
		modelProps := model["properties"].(map[string]any)
		modelProps["lineageId"] = map[string]any{"type": []string{"string", "null"}, "minLength": 1}
		modelProps["lineageStatus"] = map[string]any{"type": []string{"string", "null"}, "enum": []any{"current", "older", "preview", "retired", nil}}
		modelProps["defaultSelected"] = map[string]any{"type": []string{"boolean", "null"}}
		props["selectionRevision"] = map[string]any{"type": "string", "minLength": 1}
		props["models"] = map[string]any{"type": "array", "items": model}
		props["units"] = map[string]any{"type": "object", "required": []string{"ability", "cost", "time"}, "properties": map[string]any{"ability": map[string]any{"const": "websiteAbility"}, "cost": map[string]any{"const": "usdPerReferenceTask"}, "time": map[string]any{"const": "taskTimeCrossModel"}}, "additionalProperties": true}
		for _, k := range []string{"lineups", "speedTiers", "resets", "windows"} {
			props[k] = map[string]any{"type": "array", "items": map[string]any{"type": "object"}}
		}
		for _, k := range []string{"multiplierHorizon", "planMetering"} {
			props[k] = map[string]any{"type": []string{"object", "null"}}
		}
		props["multipliers"] = map[string]any{"type": []string{"array", "null"}, "items": map[string]any{"type": "object"}}
		props["publicationId"] = map[string]any{"type": "string", "minLength": 1}
	}
	definition["$schema"] = "https://json-schema.org/draft/2020-12/schema"
	definition["$id"] = "https://modelplan.ai/schema/" + name + "-v1.json"
	definition["title"] = "ModelPlan " + name + " contract v1"
	definition["$comment"] = "SPDX-License-Identifier: MIT. Frozen required fields/types; additive extensions allowed. A breaking change requires a new contract version and schema."
	definition["$defs"] = defs
	// Move the root out of defs to avoid self-referential JSON map serialization.
	delete(defs, strings.TrimPrefix(ref["$ref"].(string), "#/$defs/"))
	return definition
}
func TestContractV1Goldens(t *testing.T) {
	old := time.Local
	time.Local = time.UTC
	t.Cleanup(func() { time.Local = old })
	cases, e := contracttest.Cases()
	if e != nil {
		t.Fatal(e)
	}
	if *updateContract {
		if e := os.MkdirAll(filepath.Join(root(), "schema"), 0755); e != nil {
			t.Fatal(e)
		}
		for name, v := range map[string]any{"desktop": snapshot.Snapshot{}, "publication": digest.Publication{}} {
			if e := os.WriteFile(filepath.Join(root(), "schema", name+"-v1.json"), encoded(t, freezeSchema(v, name)), 0644); e != nil {
				t.Fatal(e)
			}
		}
	}
	schemas := map[string]*jsonschema.Schema{"desktop": schema(t, "desktop"), "publication": schema(t, "publication")}
	type indexCase struct {
		ID          string `json:"id"`
		Description string `json:"description"`
		Coverage    string `json:"coverage"`
		Desktop     string `json:"desktop"`
		Publication string `json:"publication"`
	}
	index := struct {
		ContractVersion int         `json:"contractVersion"`
		Cases           []indexCase `json:"cases"`
	}{ContractVersion: 1}
	dir := filepath.Join(root(), "testdata/contract-v1")
	if *updateContract {
		if e := os.MkdirAll(dir, 0755); e != nil {
			t.Fatal(e)
		}
	}
	seen := map[string]bool{}
	for _, tc := range cases {
		seen[strings.Split(tc.ID, "-")[0]] = true
		index.Cases = append(index.Cases, indexCase{tc.ID, tc.Description, tc.Coverage, tc.ID + "-desktop.json", tc.ID + "-publication.json"})
		for command, v := range map[string]any{"desktop": tc.Desktop, "publication": tc.Publication} {
			t.Run(tc.ID+"/"+command, func(t *testing.T) {
				got := encoded(t, v)
				if e := schemas[command].Validate(value(t, got)); e != nil {
					t.Fatalf("producer violates schema: %v", e)
				}
				path := filepath.Join(dir, tc.ID+"-"+command+".json")
				if *updateContract {
					if e := os.WriteFile(path, got, 0644); e != nil {
						t.Fatal(e)
					}
				}
				want, e := os.ReadFile(path)
				if e != nil {
					t.Fatal(e)
				}
				if !bytes.Equal(got, want) {
					t.Fatalf("contract golden drift: %s; review compatibility before updating", path)
				}
			})
		}
	}
	for _, id := range []string{"F01", "F02", "F03", "F04", "F05", "F06", "F07", "F08", "F09", "F10", "F11", "F12", "F13", "F14", "F15", "F16", "F17", "F18", "F19", "F20"} {
		if !seen[id] {
			t.Fatal("missing scenario", id)
		}
	}
	path := filepath.Join(dir, "cases.json")
	got := encoded(t, index)
	if *updateContract {
		if e := os.WriteFile(path, got, 0644); e != nil {
			t.Fatal(e)
		}
	}
	want, e := os.ReadFile(path)
	if e != nil || !bytes.Equal(got, want) {
		t.Fatal("scenario inventory drift", e)
	}
}
func TestContractRejectsBreakingChanges(t *testing.T) {
	cases, e := contracttest.Cases()
	if e != nil {
		t.Fatal(e)
	}
	for name, v := range map[string]any{"desktop": cases[0].Desktop, "publication": cases[0].Publication} {
		s := schema(t, name)
		for _, mutation := range []string{"version", "missing", "wrong-type", "timestamp", "schema-version", "nested-type"} {
			t.Run(name+"/"+mutation, func(t *testing.T) {
				var doc map[string]any
				_ = json.Unmarshal(encoded(t, v), &doc)
				switch mutation {
				case "schema-version":
					doc["schemaVersion"] = 99
				case "nested-type":
					if name == "desktop" {
						doc["accounts"].([]any)[0].(map[string]any)["windows"].([]any)[0].(map[string]any)["remainingPercent"] = "unknown"
					} else {
						doc["models"].([]any)[0].(map[string]any)["efforts"].([]any)[0].(map[string]any)["cost"] = "unknown"
					}
				case "version":
					doc["contractVersion"] = 2
				case "missing":
					delete(doc, "capabilities")
				case "wrong-type":
					if name == "desktop" {
						doc["accounts"] = true
					} else {
						doc["models"] = true
					}
				case "timestamp":
					if name == "desktop" {
						doc["generatedAt"] = "not-a-date"
					} else {
						doc["publishedAt"] = "not-a-date"
					}
				}
				if e := s.Validate(value(t, encoded(t, doc))); e == nil {
					t.Fatal("schema accepted breaking mutation")
				}
			})
		}
		t.Run(name+"/additive", func(t *testing.T) {
			var doc map[string]any
			_ = json.Unmarshal(encoded(t, v), &doc)
			doc["futureAdditiveField"] = true
			if e := s.Validate(value(t, encoded(t, doc))); e != nil {
				t.Fatal(e)
			}
		})
	}
}

func TestScenarioEvidenceIsSubstantive(t *testing.T) {
	cases, err := contracttest.Cases()
	if err != nil {
		t.Fatal(err)
	}
	for _, tc := range cases {
		switch tc.ID {
		case "F01-six-working":
			refs := map[string]bool{}
			for _, s := range tc.Desktop.LiveSessions {
				if s.SubscriptionRef == nil {
					t.Fatal("missing working attribution")
				}
				refs[*s.SubscriptionRef] = true
			}
			if len(refs) != 6 {
				t.Fatal("six-working scenario reuses subscription identity")
			}
		case "F09":
			sums := tc.Desktop.TodayTotals[0].Sums
			if sums.EligibleRequests != 10 || sums.EligibleOutputTokens != 1000 || sums.GenMs != 91000 {
				t.Fatal("unequal-duration ratio-of-sums evidence lost")
			}
			if len(tc.Desktop.Hourly) != 2 || tc.Desktop.Hourly[0].ObservedOutputTokens != 0 {
				t.Fatal("known-zero/missing-hour evidence lost")
			}
		case "F10":
			if len(tc.Desktop.DailyLong) != 371 {
				t.Fatal("long heatmap evidence truncated")
			}
		case "F11":
			if len(tc.Desktop.PaceHistory.Groups) != 1 || len(tc.Desktop.PaceHistory.Groups[0].Cycles) != 10 {
				t.Fatal("cycle evidence truncated")
			}
		case "F19":
			if len(tc.Desktop.Hourly) != 2 || tc.Desktop.Hourly[0].Hour == tc.Desktop.Hourly[1].Hour {
				t.Fatal("offset-distinct repeated hour missing")
			}
		case "F19-spring":
			if len(tc.Desktop.Hourly) != 2 {
				t.Fatal("spring transition missing")
			}
		case "F03-insufficient-rate":
			if len(tc.Desktop.LiveSessions) != 1 || tc.Desktop.LiveSessions[0].Rate.Value != nil {
				t.Fatal("four samples fabricated a rate")
			}
		}
		if tc.Desktop.Capabilities["creditsHistory"].Status != "unavailable" || tc.Publication.Capabilities["lineageSelection"].Status != "publication-dependent" {
			t.Fatal("unknown history or publication-dependent selection capability changed")
		}
	}
}

func TestLineageSelectionSchemaRejectsInvalidMetadata(t *testing.T) {
	cases, err := contracttest.Cases()
	if err != nil {
		t.Fatal(err)
	}
	s := schema(t, "publication")
	for _, mutation := range []struct {
		field   string
		invalid any
	}{
		{"lineageId", 42}, {"lineageId", ""}, {"lineageId", true},
		{"lineageStatus", "newest"}, {"lineageStatus", true}, {"lineageStatus", 1},
		{"defaultSelected", "false"}, {"defaultSelected", 0},
		{"selectionRevision", true}, {"selectionRevision", ""}, {"selectionRevision", nil},
	} {
		t.Run(mutation.field+"/"+strings.TrimSpace(string(encoded(t, mutation.invalid))), func(t *testing.T) {
			var doc map[string]any
			_ = json.Unmarshal(encoded(t, cases[0].Publication), &doc)
			if mutation.field == "selectionRevision" {
				doc[mutation.field] = mutation.invalid
			} else {
				doc["models"].([]any)[0].(map[string]any)[mutation.field] = mutation.invalid
			}
			if err := s.Validate(value(t, encoded(t, doc))); err == nil {
				t.Fatal("accepted invalid selection metadata")
			}
		})
	}
}

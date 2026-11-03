// SPDX-License-Identifier: MIT
package swiftwire

import (
	"bytes"
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/appcontract"
	"github.com/modelplan/modelplan/cli/internal/appserver/wire"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func repoRoot(t *testing.T) string {
	t.Helper()
	_, file, _, _ := runtime.Caller(0)
	return filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
}

// Tolerating a malformed optional field is allowed only when the specific
// producer/consumer behavior is documented in the null-policy audit.
func TestEveryTolerantOptionalFieldHasAnAuditEntry(t *testing.T) {
	root := repoRoot(t)
	m, err := load(root)
	if err != nil {
		t.Fatal(err)
	}
	if err := m.prepare(); err != nil {
		t.Fatal(err)
	}
	audit, err := os.ReadFile(filepath.Join(root, "cli/internal/swiftwire/null-policy-audit.md"))
	if err != nil {
		t.Fatal(err)
	}
	checked := 0
	for key := range m.Used {
		d := m.Types[key]
		for _, f := range d.Fields {
			if !f.Optional || f.Strict {
				continue
			}
			checked++
			name := d.Go + "." + f.Go
			if d.Pkg == "rows" {
				name = "rows." + name
			}
			if !strings.Contains(string(audit), "| "+name+" |") {
				t.Errorf("%s.%s: tolerant optional field has no null-policy audit entry", d.Swift, f.JSON)
			}
		}
	}
	if checked == 0 {
		t.Fatal("no tolerant optional fields checked")
	}
}

func TestRowsWindowResetTimestampUsesBoundedStrictDecode(t *testing.T) {
	if !strict("RowsWindow", "resetsAt") {
		t.Fatal("RowsWindow.resetsAt must reject a non-null invalid value")
	}
	generated, err := Generate(repoRoot(t))
	if err != nil {
		t.Fatal(err)
	}
	want := "do { self.`resetsAt` = try c.decodeIfPresent(WireTimestamp.self, forKey: .`resetsAt`) }\n        catch { throw WireDecodeError.invalidBound }"
	if !bytes.Contains(generated, []byte(want)) {
		t.Fatal("missing strict, coalescing reset timestamp decoder")
	}
}

func TestGeneratedSwiftMatchesProductionContract(t *testing.T) {
	root := repoRoot(t)
	a, err := Generate(root)
	if err != nil {
		t.Fatal(err)
	}
	b, err := Generate(root)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(a, b) {
		t.Fatal("non-deterministic Swift generation")
	}
	for _, required := range []string{
		"public struct WireEnvelope<T: Codable & Sendable>",
		"case unknown(String)", "public let `vendorKey`: String?",
		"public let `consentGeneration`: UInt64", "decodeIfPresent",
		"public struct WireCredentialResult", "[redacted]",
	} {
		if !bytes.Contains(a, []byte(required)) {
			t.Errorf("missing contract: %s", required)
		}
	}
	checked, err := os.ReadFile(filepath.Join(root, "clients/swift/ModelPlanWire/Sources/ModelPlanWire/Generated.swift"))
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(a, checked) {
		t.Fatal("Swift drift: run go run ./internal/swiftwire/cmd --write")
	}
}

func TestRealGoCapturesAndMutationCoverage(t *testing.T) {
	root := repoRoot(t)
	files, err := Captures(root)
	if err != nil {
		t.Fatal(err)
	}
	for name, data := range files {
		path := filepath.Join(root, "schema/app-cli/captures", name)
		if name == "CaptureTypes.swift" {
			path = filepath.Join(root, "clients/swift/ModelPlanWire/Tests/ModelPlanWireTests", name)
		}
		if os.Getenv("UPDATE_SWIFT_CAPTURES") == "1" {
			if err = os.WriteFile(path, data, 0644); err != nil {
				t.Fatal(err)
			}
		}
		stored, err := os.ReadFile(path)
		if err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(stored, data) {
			t.Fatalf("capture drift: %s", name)
		}
	}
	var index captureIndex
	if err = json.Unmarshal(files["index.json"], &index); err != nil {
		t.Fatal(err)
	}
	optional, strict, display := 0, 0, 0
	for _, c := range index.Cases {
		for _, f := range c.Optional {
			optional++
			if f.Strict {
				strict++
			} else {
				display++
			}
		}
	}
	if optional == 0 || strict == 0 || display == 0 {
		t.Fatal("missing optional/identity/display mutation coverage")
	}
	var message wire.Success[wire.RowsSnapshot]
	if err = json.Unmarshal(files["production-rows.json"], &message); err != nil {
		t.Fatal(err)
	}
	if message.Result.Data.Projection.Rows[0].ID != "declared:team" {
		t.Fatal("real Go encoding lost production row")
	}
	t.Logf("%d DTO roots, %d optional fields (%d strict, %d display)", len(index.Cases), optional, strict, display)
}

func TestRetiredAccountCaptureAndClientGuard(t *testing.T) {
	root := repoRoot(t)
	capture, err := retiredAccountCapture()
	if err != nil {
		t.Fatal(err)
	}
	validator, err := appcontract.NewValidator(root)
	if err != nil {
		t.Fatal(err)
	}
	if err = validator.Validate("app-server", capture); err != nil {
		t.Fatal(err)
	}
	var message wire.Success[wire.RowsSnapshot]
	if err = json.Unmarshal(capture, &message); err != nil {
		t.Fatal(err)
	}
	found := false
	for _, row := range message.Result.Data.Projection.Rows {
		if row.ID == "codex" {
			found = string(row.Consent) == "retired" && string(row.Reason.Code) == "catalogue_retired" && len(row.Accounts) == 1
		}
	}
	if !found || len(message.Result.Data.Projection.Rows) != 2 {
		t.Fatal("missing valid retired account plus healthy row")
	}
	generated, err := Generate(root)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(generated, []byte(`["denied", "unset", "retired"]`)) {
		t.Fatal("valid Go retired-account capture is rejected by the generated client guard")
	}
}

func TestQueryBindingsRemainStrict(t *testing.T) {
	files, err := Captures(repoRoot(t))
	if err != nil {
		t.Fatal(err)
	}
	var index captureIndex
	if err = json.Unmarshal(files["index.json"], &index); err != nil {
		t.Fatal(err)
	}
	for _, capture := range index.Cases {
		if capture.Type != "WireHistoryQueryParams" {
			continue
		}
		for _, field := range capture.Optional {
			if (field.Field == "ref" || field.Field == "cursor") && field.WrongType {
				t.Errorf("query binding %s silently loses a malformed value", field.Field)
			}
		}
	}
}

func TestModelScopeAndResetEventsAreStrictNonNull(t *testing.T) {
	files, err := Captures(repoRoot(t))
	if err != nil {
		t.Fatal(err)
	}
	var index captureIndex
	if err := json.Unmarshal(files["index.json"], &index); err != nil {
		t.Fatal(err)
	}
	want := map[string]string{"RowsWindow": "modelScope", "WireRowsProjection": "resetEvents"}
	for _, capture := range index.Cases {
		field, ok := want[capture.Type]
		if !ok {
			continue
		}
		for _, f := range capture.Optional {
			if f.Field != field {
				continue
			}
			if !f.Strict || !f.Omission || f.Null || f.WrongType || f.NullPolicy != wire.NullForbidden {
				t.Errorf("%s.%s: unsafe optional contract: %+v", capture.Type, field, f)
			}
			delete(want, capture.Type)
		}
	}
	if len(want) != 0 {
		t.Fatalf("missing strict optional captures: %v", want)
	}
}

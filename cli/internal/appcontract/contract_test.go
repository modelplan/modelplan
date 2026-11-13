// SPDX-License-Identifier: MIT
package appcontract

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"testing"
	"time"
)

func TestBinaryConformanceAndGoldenFixtures(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
	helper := filepath.Join(t.TempDir(), "fixture-runtime")
	if err := Build(root, helper, "./internal/appcontract/cmd"); err != nil {
		t.Fatal(err)
	}
	files, err := Generate(root, helper)
	if err != nil {
		t.Fatal(err)
	}
	if err := Check(root, files, false); err != nil {
		t.Fatal(err)
	}
}

func TestSchemaRejectsContractDrift(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
	v, err := NewValidator(root)
	if err != nil {
		t.Fatal(err)
	}
	for _, raw := range []string{
		`{"generation":0,"consentTextVersion":2,"mode":"automatic","consentText":{"en":"x","zh":"x"},"tools":[{"id":"codex","displayName":"Codex","accessClass":"standard","detected":true,"allowed":false,"backend":"native","readerId":"native:codex","keychain":"unset","hosts":[],"hostDetails":[{"host":"https://chatgpt.com (runtime)","note":""}]}]}`,
		`{"generation":"0","consentTextVersion":2,"mode":"automatic","consentText":{"en":"x","zh":"x"},"tools":[]}`,
	} {
		if v.Validate("consent", []byte(raw)) == nil {
			t.Fatal("schema accepted incompatible wire shape", raw)
		}
	}
	if _, err := os.Stat(filepath.Join(root, "schema", "app-cli", "fixtures", "manifest.json")); err != nil {
		t.Fatal(err)
	}
}

// Keep the checked-in command inventory tied to literal helper invocations, so a
// new app command cannot silently escape the schema and binary fixture gate.
func TestAppCommandInventory(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	root := filepath.Clean(filepath.Join(filepath.Dir(file), "../../.."))
	var inventory struct {
		Commands []struct {
			Schema    string   `json:"schema"`
			Arguments []string `json:"arguments"`
			Callsite  string   `json:"callsite"`
		} `json:"commands"`
	}
	read := func(name string, target any) {
		t.Helper()
		b, err := os.ReadFile(filepath.Join(root, name))
		if err != nil {
			t.Fatal(err)
		}
		if err := json.Unmarshal(b, target); err != nil {
			t.Fatal(err)
		}
	}
	read("schema/app-cli/commands.json", &inventory)
	var manifest Manifest
	read("schema/app-cli/fixtures/manifest.json", &manifest)
	captured := map[string]string{}
	for _, e := range manifest.Entries {
		captured[strings.Join(e.Arguments, "\x00")] = e.Schema
	}
	known := map[string]bool{}
	callsites := map[string]bool{}
	for _, c := range inventory.Commands {
		key := strings.Join(c.Arguments, "\x00")
		if captured[key] != c.Schema {
			t.Errorf("missing matching binary capture for %v (%s)", c.Arguments, c.Schema)
		}
		if _, err := os.Stat(filepath.Join(root, "schema/app-cli", c.Schema+".json")); err != nil {
			t.Fatal(err)
		}
		known[key] = true
		if strings.HasSuffix(c.Callsite, ".swift") {
			callsites[c.Callsite] = true
		}
	}
	arrays := regexp.MustCompile(`(?:return\s+|arguments\s*[=:]\s*|\?\s*)(\["[^"\n]+"(?:,\s*"[^"\n]+")*\])`)
	for callsite := range callsites {
		b, err := os.ReadFile(filepath.Join(root, callsite))
		if err != nil {
			t.Fatal(err)
		}
		matches := arrays.FindAllSubmatch(b, -1)
		if len(matches) == 0 {
			t.Errorf("no helper argv found in %s", callsite)
		}
		for _, match := range matches {
			literal := match[1]
			var args []string
			if err := json.Unmarshal(literal, &args); err != nil {
				t.Fatal(err)
			}
			if !known[strings.Join(args, "\x00")] {
				t.Errorf("%s helper argv missing from contract: %v", callsite, args)
			}
		}
	}
}

func TestClockNormalizationPreservesDurationsAndMachineValues(t *testing.T) {
	a, err := canonical([]byte(`{"generatedAt":"2026-10-29T10:01:10Z","validUntil":"2026-10-29T10:06:10Z","remainingPercent":75,"hostDetails":[{"host":"api.example.test","note":"display"}]}`), "/synthetic")
	if err != nil {
		t.Fatal(err)
	}
	b, err := canonical([]byte(`{"generatedAt":"2026-11-01T12:31:10Z","validUntil":"2026-11-01T12:36:10Z","remainingPercent":75,"hostDetails":[{"host":"api.example.test","note":"display"}]}`), "/synthetic")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(a, b) {
		t.Fatal("equivalent clock shifts drift")
	}
	var got struct {
		GeneratedAt, ValidUntil time.Time
		RemainingPercent        int
		HostDetails             []struct{ Host, Note string }
	}
	if err := json.Unmarshal(a, &got); err != nil {
		t.Fatal(err)
	}
	if got.ValidUntil.Sub(got.GeneratedAt) != 5*time.Minute || got.RemainingPercent != 75 || got.HostDetails[0].Host != "api.example.test" {
		t.Fatal("normalization changed contract semantics")
	}
	changed, err := canonical(bytes.ReplaceAll(b, []byte("75"), []byte("74")), "/synthetic")
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Equal(a, changed) {
		t.Fatal("normalization hid a quota change")
	}
}

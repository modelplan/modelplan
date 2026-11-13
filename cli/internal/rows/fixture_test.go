// SPDX-License-Identifier: MIT
package rows

import (
	"bytes"
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

var updateRowsFixtures = flag.Bool("update-rows-fixtures", false, "regenerate synthetic model-level rows fixtures")

// These are pure-builder fixtures, not CLI stdout captures. The command capture
// suite is extended when the reader and consent-fence adapters are integrated.
func TestMissingRetiredNoReaderFixtures(t *testing.T) {
	_, file, _, _ := runtime.Caller(0)
	for _, name := range []string{"allowed-missing-no-reader", "allowed-retired-no-reader"} {
		t.Run(name, func(t *testing.T) {
			in := sampleInput()
			in.Accounts = nil
			in.Catalogue[0].ToolID = "amp"
			in.Consents[0].ToolID = "amp"
			in.Profiles = nil
			in.Catalogue[0].ReaderExists = false
			expected := CodeToolNotFound
			if name == "allowed-missing-no-reader" {
				in.Catalogue[0].Detected = false
			} else {
				in.Catalogue = nil
				expected = CodeCatalogueRetired
			}
			projection := Build(in)
			if projection.Rows[0].Reason.Code != expected {
				t.Fatalf("missing/retired lost to no_reader: %+v", projection)
			}
			if err := ValidateCapture(in, projection); err != nil {
				t.Fatal(err)
			}
			record := struct {
				Provenance string     `json:"provenance"`
				Projection Projection `json:"projection"`
			}{"synthetic rows.Build output; model-level fixture, not CLI stdout", projection}
			encoded, err := json.MarshalIndent(record, "", "  ")
			if err != nil {
				t.Fatal(err)
			}
			encoded = append(encoded, '\n')
			path := filepath.Join(filepath.Dir(file), "testdata", name+".json")
			if *updateRowsFixtures {
				if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
					t.Fatal(err)
				}
				if err := os.WriteFile(path, encoded, 0644); err != nil {
					t.Fatal(err)
				}
			}
			old, err := os.ReadFile(path)
			if err != nil || !bytes.Equal(old, encoded) {
				t.Fatalf("projection fixture drift: %s; regenerate with go test ./internal/rows -run TestMissingRetiredNoReaderFixtures -args -update-rows-fixtures", name)
			}
		})
	}
}

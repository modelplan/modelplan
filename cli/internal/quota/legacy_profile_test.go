// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func writeLegacyConsent(t *testing.T, tools string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(consent.Path()), 0o700); err != nil {
		t.Fatal(err)
	}
	body := `{"schemaVersion":1,"privacy":"automatic","generation":3,"tools":{` + tools + `}}`
	if err := os.WriteFile(consent.Path(), []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
}

const legacyAt = `"consentTextVersion":2,"at":"2026-10-20T00:00:00Z"`

// Codex has no native reader but is still listed, with its runtime route.
func TestDoctorReadersListsCodex(t *testing.T) {
	isolateHome(t)
	writeLegacyConsent(t, `"codex":{"allowed":true,`+legacyAt+`}`)
	p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	for _, row := range ReaderDiagnostics(p, now) {
		if row.Provider == "codex" {
			if row.Admitted != "yes" || row.Consent != "granted" || row.State != "unavailable:not_read" {
				t.Fatalf("codex row = %+v", row)
			}
			return
		}
	}
	t.Fatal("doctor readers does not list Codex")
}

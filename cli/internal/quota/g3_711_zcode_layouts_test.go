// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// Post-merge #711 (1): every ZCode layout detection lists (the CLI community package and the
// Desktop support folder, not only ~/.zcode) gets the unsupported-sign-in cause instead of
// "waiting for the first reading" forever (G3-21).
func TestG711ZCodeAlternateLayoutsWithoutProviderFile(t *testing.T) {
	now := time.Date(2026, 11, 14, 20, 0, 0, 0, time.UTC)
	for _, rel := range []string{".local/share/zcode-community", ".local/share/zcode-cli", "Library/Application Support/ZCode"} {
		t.Run(rel, func(t *testing.T) {
			isolateHome(t)
			home, _ := os.UserHomeDir()
			if err := os.MkdirAll(filepath.Join(home, filepath.FromSlash(rel)), 0o700); err != nil {
				t.Fatal(err)
			}
			p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
			s, ok := zaiSource(ReadPermitted(p, now))
			if !ok || s.ErrorCode != "unsupported_login" {
				t.Fatalf("%s: %+v (found=%t), want unsupported_login", rel, s, ok)
			}
			if d := zaiDiagnostic(t, p, now); d.State != "unavailable:no_provider_file" {
				t.Fatalf("%s: diagnostic %+v", rel, d)
			}
		})
	}
}

// Post-merge #711 (2): a bare legacy GLM allow (no key, profile or other backend) is not a route
// any reader can use, so it does not hide the missing-provider-file diagnosis.
func TestG711BareLegacyGLMGrantKeepsNoProviderFileCause(t *testing.T) {
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	writeZCodeDesktopLayout(t, home)
	writeLegacyConsent(t, `"zai":{"allowed":true,`+legacyAt+`,"readerId":"native:zai","backend":"native"}`)
	now := time.Date(2026, 11, 14, 20, 0, 0, 0, time.UTC)
	p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	s, ok := zaiSource(ReadPermitted(p, now))
	if !ok || s.ErrorCode != "unsupported_login" {
		t.Fatalf("bare legacy grant: %+v (found=%t), want unsupported_login", s, ok)
	}
	if d := zaiDiagnostic(t, p, now); d.State != "unavailable:no_provider_file" {
		t.Fatalf("diagnostic %+v", d)
	}
}

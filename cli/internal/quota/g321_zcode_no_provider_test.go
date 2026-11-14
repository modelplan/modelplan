// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

// G3-21 (owner, Builds 11 and 12): ZCode is installed and used, but its data folder has no
// provider_config.json (a ZCode Desktop layout, or a sign-in that keeps no plaintext key).
// No reader can ever run, so the row must say so instead of "Waiting for the first reading"
// forever, and the diagnostic must name the cause. Synthetic folders only; no file is read.
func writeZCodeDesktopLayout(t *testing.T, home string) {
	t.Helper()
	dir := filepath.Join(home, ".zcode", "v2")
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"setting.json", "config.json"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(`{"canary":"must-not-be-read"}`), 0o600); err != nil {
			t.Fatal(err)
		}
	}
}

func zaiSource(r Report) (SourceStatus, bool) {
	for _, s := range r.Sources {
		if s.Source == "native:zai" {
			return s, true
		}
	}
	return SourceStatus{}, false
}

func zaiDiagnostic(t *testing.T, p Paths, now time.Time) ReaderDiagnostic {
	t.Helper()
	for _, row := range ReaderDiagnostics(p, now) {
		if row.Provider == "zai" {
			return row
		}
	}
	t.Fatal("no zai diagnostic row")
	return ReaderDiagnostic{}
}

func TestG321ZCodeWithoutProviderFileIsNotSupportedYet(t *testing.T) {
	isolateHome(t)
	home, _ := os.UserHomeDir()
	writeZCodeDesktopLayout(t, home)
	now := time.Date(2026, 11, 7, 20, 0, 0, 0, time.UTC)
	p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
	if _, ok := p.ReaderAccessGrant("zai"); ok {
		t.Fatal("no provider file, yet a ZCode key route was admitted")
	}
	s, ok := zaiSource(ReadPermitted(p, now))
	if !ok || s.ErrorCode != "unsupported_login" {
		t.Fatalf("ZCode without a provider file reports %+v (found=%t), want unsupported_login", s, ok)
	}
	if d := zaiDiagnostic(t, p, now); d.Detected != "yes" || d.State != "unavailable:no_provider_file" {
		t.Fatalf("diagnostic = %+v", d)
	}
}

// The new status never overrides a user's choice or appears without ZCode.
func TestG321ZCodeWithoutProviderFileRespectsDecisions(t *testing.T) {
	now := time.Date(2026, 11, 7, 20, 0, 0, 0, time.UTC)
	t.Run("no zcode folder", func(t *testing.T) {
		isolateHome(t)
		p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
		if s, ok := zaiSource(ReadPermitted(p, now)); ok {
			t.Fatalf("phantom ZCode source %+v", s)
		}
	})
	t.Run("glm denied", func(t *testing.T) {
		isolateHome(t)
		home, _ := os.UserHomeDir()
		writeZCodeDesktopLayout(t, home)
		if _, err := consent.EnsureStore(consent.Path()); err != nil {
			t.Fatal(err)
		}
		if err := consent.Change(consent.Path(), func(s *consent.State) error {
			s.Tools["zai"] = consent.Record{Allowed: false, ConsentTextVersion: consent.TextVersion}
			return nil
		}); err != nil {
			t.Fatal(err)
		}
		p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
		if s, ok := zaiSource(ReadPermitted(p, now)); ok && s.ErrorCode == "unsupported_login" {
			t.Fatalf("a GLM denial was replaced by %+v", s)
		}
	})
	t.Run("readers off", func(t *testing.T) {
		isolateHome(t)
		home, _ := os.UserHomeDir()
		writeZCodeDesktopLayout(t, home)
		t.Setenv("MODELPLAN_READERS", "off")
		p := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", consent.Capture())
		if s, ok := zaiSource(ReadPermitted(p, now)); ok && s.ErrorCode == "unsupported_login" {
			t.Fatalf("readers off still reported %+v", s)
		}
	})
}

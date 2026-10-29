// SPDX-License-Identifier: MIT
package connections

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func TestDiagnoseUsesCapturedAdmissionForEveryConnection(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_NATIVE", "")
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		for _, tool := range []string{"claude", "kiro"} {
			s.Tools[tool] = consent.Record{Keychain: "allowed"}
			if err := consent.Set(s, tool, true, "native:"+tool, "native", time.Now()); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	admission := consent.Capture()
	if err := consent.Change(consent.Path(), func(s *consent.State) error {
		for tool := range s.Tools {
			if err := consent.Set(s, tool, false, "", "", time.Now()); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	// Intermediate diagnostics must describe the same attempt as the report.
	// The command's final generation fence will discard this stale attempt.
	captured := DiagnoseWithAdmission(Env{}, quota.Report{}, admission)
	seen := map[string]bool{}
	for _, c := range captured {
		if c.ID == "claude-code" || c.ID == "native:kiro" {
			seen[c.ID] = true
			if c.Authorization.Status != "yes" {
				t.Fatalf("second consent read changed diagnostics: %+v", c)
			}
		}
	}
	if !seen["claude-code"] || !seen["native:kiro"] {
		t.Fatalf("captured route missing: %+v", captured)
	}
	for _, c := range Diagnose(Env{}, quota.Report{}) {
		if c.ID == "claude-code" && c.Authorization.Reason != "consent_denied" {
			t.Fatalf("fresh command ignored revoke: %+v", c)
		}
	}
}

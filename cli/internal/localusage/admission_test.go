// SPDX-License-Identifier: MIT
package localusage

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/testenv"
)

func TestHistoryCapturedAdmissionKeepsLiveValidity(t *testing.T) {
	testenv.IsolateHome(t)
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_HISTORY", "")
	home, _ := os.UserHomeDir()
	if err := os.MkdirAll(filepath.Join(home, ".copilot", "session-state"), 0700); err != nil {
		t.Fatal(err)
	}
	if err := setSource(home, "identity", true); err != nil {
		t.Fatal(err)
	}
	change := func(allowed bool) {
		t.Helper()
		if err := consent.Change(consent.Path(), func(s *consent.State) error {
			return consent.Set(s, "copilot", allowed, "native:copilot", "native", time.Now())
		}); err != nil {
			t.Fatal(err)
		}
	}
	change(true)
	admission := consent.Capture()
	change(false)
	_, old := ProductionHistoryAccessWithAdmission(home, "copilot", false, admission)
	if !old.Allowed || old.StillValid == nil || old.StillValid() {
		t.Fatal("captured policy or live fence lost", old)
	}
	_, current := ProductionHistoryAccess(home, "copilot", false)
	if current.Allowed {
		t.Fatal("fresh admission ignored revoke")
	}
}

// SPDX-License-Identifier: MIT
package quota

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
)

func TestCapturedProductionAdmissionDoesNotDisableLiveRevocation(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "automatic")
	t.Setenv("MODELPLAN_NATIVE", "")
	home, _ := os.UserHomeDir()
	if err := os.MkdirAll(filepath.Join(home, ".claude"), 0700); err != nil {
		t.Fatal(err)
	}
	productionConsent(t, "claude", true)
	admission := consent.Capture()
	captured := ProductionPathsWithAdmission(t.TempDir(), "1.0.0", admission)
	live := ProductionPaths(t.TempDir(), "1.0.0")
	grant, ok := captured.ReaderAccessGrant("claude")
	if !ok || grant.StillValid == nil || !grant.StillValid() {
		t.Fatal("missing captured grant", grant)
	}
	productionConsent(t, "claude", false)
	if grant.StillValid() {
		t.Fatal("immutable view bypassed live reader revocation")
	}
	selected, err := Selections(captured)
	if err != nil || len(selected) != 1 || selected[0].Origin != "consent.json" {
		t.Fatalf("captured selection reread consent: %+v %v", selected, err)
	}
	if selected, err := Selections(live); err != nil || len(selected) != 0 {
		t.Fatalf("worker selection froze stale consent: %+v %v", selected, err)
	}
	report := ReadPermitted(captured, time.Now())
	if len(report.Accounts) != 0 || len(report.Sources) != 1 || report.Sources[0].Reason != "consent-changed" {
		t.Fatalf("reader's live publication fence bypassed: %+v", report)
	}
}

func TestReadDeclaredRetainsEveryLocalCandidateWhenReadersOff(t *testing.T) {
	isolateHome(t)
	t.Setenv("MODELPLAN_READERS", "off")
	file := filepath.Join(t.TempDir(), "local.json")
	body := `{"schemaVersion":1,"plans":[{"planId":"plan-only"}],"windows":[{"planId":"window-only","kind":"weekly"}],"resetCards":[{"planId":"card-only","kind":"weekly"}]}`
	if err := os.WriteFile(file, []byte(body), 0600); err != nil {
		t.Fatal(err)
	}
	p := Paths{LocalFile: file}
	before, _ := os.ReadFile(file)
	if r := ReadPermitted(p, time.Now()); len(r.Accounts) != 0 {
		t.Fatal("quota readers-off bytes/behavior changed", r)
	}
	r := ReadDeclared(p, time.Now())
	plans := map[string]bool{}
	for _, a := range r.Accounts {
		if a.Source != "user" {
			t.Fatal("tool account in declared report", a)
		}
		plans[a.Plan] = true
	}
	if len(plans) != 3 || !plans["plan-only"] || !plans["window-only"] || !plans["card-only"] {
		t.Fatal(plans)
	}
	after, _ := os.ReadFile(file)
	if string(before) != string(after) {
		t.Fatal("declaration read changed local.json")
	}
}

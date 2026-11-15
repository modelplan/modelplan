// SPDX-License-Identifier: MIT
package snapshot_test

import (
	"testing"

	"github.com/modelplan/modelplan/cli/internal/contracttest"
	"github.com/modelplan/modelplan/cli/internal/quota"
	"github.com/modelplan/modelplan/cli/internal/snapshot"
)

// The desktop shows the snapshot's plan text as is: Codex's Pro tier ids arrive as their names,
// while the report the history and advice are keyed on keeps the id.
func TestSnapshotNamesCodexProTiers(t *testing.T) {
	in := snapshot.Input{Now: contracttest.Now, Report: quota.Report{Accounts: []quota.Account{{Source: "codex", Plan: "prolite"}, {Source: "codexbar:zai", Plan: "GLM Coding Plan"}}}}
	s := snapshot.Build(in)
	if s.Accounts[0].Plan != "Pro 100" || s.Accounts[1].Plan != "GLM Coding Plan" || in.Report.Accounts[0].Plan != "prolite" {
		t.Fatalf("%q %q %q", s.Accounts[0].Plan, s.Accounts[1].Plan, in.Report.Accounts[0].Plan)
	}
}

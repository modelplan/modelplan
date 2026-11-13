// SPDX-License-Identifier: MIT
package contracttest

import (
	"github.com/modelplan/modelplan/cli/internal/history"
	"time"
)

// EffortLedger is authored synthetic quota history, never an installed user's data.
func EffortLedger(at time.Time, effort string, fast bool, uses ...float64) history.Ledger {
	l := history.Ledger{SchemaVersion: 1}
	for i, used := range uses {
		reset := at.Add(-time.Hour - time.Duration(i)*7*24*time.Hour)
		l.Cycles = append(l.Cycles, history.Cycle{Source: "codex", Plan: "synthetic-plan", Kind: "weekly", WindowMinutes: 10080, ResetsAt: reset,
			FirstAt: reset.Add(-6 * 24 * time.Hour), LastAt: reset.Add(-24 * time.Hour), FirstUsed: 0, LastUsed: used, HitLimit: used >= 100,
			Spent: []history.Share{{Model: "native-z", Effort: effort, Fast: fast, Points: used}}})
	}
	return l
}

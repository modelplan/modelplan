// SPDX-License-Identifier: MIT
package wire

import (
	"testing"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

func TestWindowSourceRequiresCapability(t *testing.T) {
	source := rows.WindowSourceLocalHistory
	projection := rows.Projection{Rows: []rows.Row{{Accounts: []rows.Account{{Windows: []rows.Window{{Source: &source}}}}}}}
	old := ProjectWithEvents(projection, nil, false)
	if old.Rows[0].Accounts[0].Windows[0].Source != nil { t.Fatal("old client received source") }
	newer := ProjectWithEvents(projection, nil, false, true)
	if got := newer.Rows[0].Accounts[0].Windows[0].Source; got == nil || *got != source { t.Fatalf("source missing: %v", got) }
	if projection.Rows[0].Accounts[0].Windows[0].Source == nil { t.Fatal("old client projection mutated source view") }
}

// SPDX-License-Identifier: MIT
package wire

import (
	"encoding/json"
	"github.com/modelplan/modelplan/cli/internal/rows"
	"strings"
	"testing"
)

func TestAccountTodayRequiresNegotiatedCapability(t *testing.T) {
	tokens := int64(120)
	original := rows.Projection{Rows: []rows.Row{{Accounts: []rows.Account{{Today: &rows.AccountToday{ObservedOutputTokens: &tokens, BindingBasis: "source-wide-current-binding"}}}}}}
	legacy := ProjectWithEvents(original, nil, false, true, true, false, false)
	if legacy.Rows[0].Accounts[0].Today != nil {
		t.Fatal("unnegotiated client received today")
	}
	negotiated := ProjectWithEvents(original, nil, false, false, false, false, true)
	if negotiated.Rows[0].Accounts[0].Today == nil || original.Rows[0].Accounts[0].Today == nil {
		t.Fatal("projection lost or mutated today")
	}
	raw, err := json.Marshal(negotiated.Rows[0].Accounts[0].Today)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(raw), "null") || strings.Contains(string(raw), "generationTps") || strings.Contains(string(raw), "runningSessions") {
		t.Fatalf("unknown values must be absent: %s", raw)
	}
}

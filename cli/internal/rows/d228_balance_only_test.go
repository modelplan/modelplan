// SPDX-License-Identifier: MIT
package rows

import "testing"

// D228 (owner 2026-11-13): a reading with a balance and no usage percentage (Grok's X Subscription
// billing) is a fresh row that says so, not an unreadable one; a money balance keeps its currency.
func TestD228BalanceOnlyReadingSaysUsageIsNotReported(t *testing.T) {
	balance := 0.0
	in := sampleInput()
	in.Accounts[0].Windows = nil
	in.Accounts[0].Credits = &CreditsInput{Balance: &balance, Unit: "money", Currency: "USD"}
	out := Build(in)
	if err := Validate(in, out); err != nil {
		t.Fatal(err)
	}
	row := rowByID(t, out, "codex")
	if row.State != StateFresh || row.Reason.Code != CodeUsageNotReported {
		t.Fatalf("state %s code %s", row.State, row.Reason.Code)
	}
	if c := row.Accounts[0].Credits; c == nil || c.Currency != "USD" || c.Unit != "money" {
		t.Fatalf("currency lost: %+v", c)
	}
	// A reading with a usage percentage stays plain ok; a bogus or non-money currency is dropped.
	in = sampleInput()
	in.Accounts[0].Credits = &CreditsInput{Balance: &balance, Unit: "credits", Currency: "USD"}
	out = Build(in)
	row = rowByID(t, out, "codex")
	if row.Reason.Code != CodeOK || row.Accounts[0].Credits.Currency != "" {
		t.Fatalf("code %s currency %q", row.Reason.Code, row.Accounts[0].Credits.Currency)
	}
	in.Accounts[0].Credits = &CreditsInput{Balance: &balance, Unit: "money", Currency: "usd$"}
	if c := rowByID(t, Build(in), "codex").Accounts[0].Credits; c.Currency != "" {
		t.Fatalf("invalid currency exported: %q", c.Currency)
	}
}

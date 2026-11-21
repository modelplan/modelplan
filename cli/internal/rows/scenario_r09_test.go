// SPDX-License-Identifier: MIT
package rows

// Spec-data scenario R-09 (tier-1 producer half): "An unknown-unit balance is
// supplied / Read CLI JSON and the App card / JSON preserves the original numeric
// value; the card is honest about the unknown unit." D11 ("取整数加千分位") applies
// only at display: the CLI JSON boundary keeps the raw number and the unit
// knowledge without fabricating money or credits.

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestR09RawBalanceAndUnknownUnitPreservedInJSON(t *testing.T) {
	for _, test := range []struct {
		name     string
		balance  float64
		unit     string
		wantUnit string
		wantJSON string
	}{
		{"large fraction", 1234567.891, "points", "other", "1234567.891"},
		{"positive fraction below one", 0.004, "points", "other", "0.004"},
		{"known unit passes through", 42.5, "money", "money", "42.5"},
	} {
		t.Run(test.name, func(t *testing.T) {
			in := sampleInput()
			in.Accounts[0].Credits = &CreditsInput{Balance: &test.balance, Unit: test.unit}
			got := Build(in)
			if err := Validate(in, got); err != nil {
				t.Fatal(err)
			}
			a := rowByID(t, got, "codex").Accounts[0]
			if a.Credits == nil || a.Credits.Balance == nil {
				t.Fatalf("credits must survive the projection, got %+v", a.Credits)
			}
			if *a.Credits.Balance != test.balance {
				t.Fatalf("the original numeric value must be preserved, got %v want %v", *a.Credits.Balance, test.balance)
			}
			if a.Credits.Unit != test.wantUnit {
				t.Fatalf("unit knowledge must not be fabricated, got %q want %q", a.Credits.Unit, test.wantUnit)
			}
			data, err := json.Marshal(got)
			if err != nil {
				t.Fatal(err)
			}
			if !strings.Contains(string(data), test.wantJSON) {
				t.Fatalf("CLI JSON must keep the raw number for display-only D11 formatting, got %s", data)
			}
		})
	}
}

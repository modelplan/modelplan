// SPDX-License-Identifier: MIT
package rows

import (
	"fmt"
	"testing"
	"time"
)

func TestResetCardsStatesAndDeduplication(t *testing.T) {
	now := time.Date(2026, 11, 3, 12, 0, 0, 0, time.UTC)
	expires := now.Add(time.Hour)
	source := []ResetCardSource{{Source: ResetCardCodexAccount, ObservedAt: now}}
	zero, two := 0, 2
	a := ResetCardItem{ID: fmt.Sprintf("%064x", 1), ExpiresAt: &expires}
	b := ResetCardItem{ID: fmt.Sprintf("%064x", 2), ExpiresAt: &expires}
	tests := []struct {
		name  string
		input *ResetCards
		state ResetCardState
		count *int
	}{
		{"unknown", nil, ResetCardUnknown, nil},
		{"complete zero", &ResetCards{State: ResetCardComplete, Count: &zero, Sources: source}, ResetCardComplete, &zero},
		{"several", &ResetCards{State: ResetCardComplete, Count: &two, Items: []ResetCardItem{a, b}, Sources: source}, ResetCardComplete, &two},
		{"capped", &ResetCards{State: ResetCardComplete, Count: &two, Items: []ResetCardItem{a}, Truncated: true, Sources: source}, ResetCardPartial, &two},
		{"invalid identity", &ResetCards{State: ResetCardComplete, Count: &two, Items: []ResetCardItem{{ID: "secret"}}, Sources: source}, ResetCardUnknown, nil},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := sanitizeResetCards(tc.input, now)
			if got.State != tc.state || (got.Count == nil) != (tc.count == nil) || got.Count != nil && *got.Count != *tc.count {
				t.Fatalf("unexpected facts: %+v", got)
			}
		})
	}
	left := sanitizeResetCards(&ResetCards{State: ResetCardComplete, Count: &two, Items: []ResetCardItem{a, b}, Sources: source}, now)
	other := *left
	other.Sources = []ResetCardSource{{Source: ResetCardCodexBar, ObservedAt: now}}
	merged := mergeResetCards([]*ResetCards{left, &other})
	if merged.State != ResetCardComplete || merged.Count == nil || *merged.Count != 2 || len(merged.Items) != 2 || len(merged.Sources) != 2 || merged.EarliestExpiresAt == nil || !merged.EarliestExpiresAt.Equal(expires) {
		t.Fatalf("duplicate source was not deduplicated: %+v", merged)
	}
	incomplete := mergeResetCards([]*ResetCards{left, unknownResetCards()})
	if incomplete.State != ResetCardPartial || incomplete.Count != nil {
		t.Fatalf("unknown source asserted completeness: %+v", incomplete)
	}
	many := make([]ResetCardItem, 65)
	for i := range many {
		many[i] = ResetCardItem{ID: fmt.Sprintf("%064x", i+1), ExpiresAt: &expires}
	}
	first := *left
	first.Items = many[:33]
	n := 33
	first.Count = &n
	second := *left
	second.Items = many[33:]
	n2 := 32
	second.Count = &n2
	capped := mergeResetCards([]*ResetCards{&first, &second})
	if capped.State != ResetCardPartial || !capped.Truncated || len(capped.Items) != 64 || capped.Count != nil {
		t.Fatalf("union cap was not reported: %+v", capped)
	}
}

func TestResetCardsFollowAdmissionAndDelivery(t *testing.T) {
	in := sampleInput()
	count := 1
	expiry := in.Now.Add(time.Hour)
	id := fmt.Sprintf("%064x", 42)
	in.Accounts[0].ResetCards = &ResetCards{State: ResetCardComplete, Count: &count, Items: []ResetCardItem{{ID: id, ExpiresAt: &expiry}}, Sources: []ResetCardSource{{Source: ResetCardCodexAccount, ObservedAt: in.Now.Add(-time.Minute)}}}
	projection := Build(in)
	if err := Validate(in, projection); err != nil {
		t.Fatal(err)
	}
	a := rowByID(t, projection, "codex").Accounts[0]
	if a.ResetCards == nil || a.ResetCards.State != ResetCardComplete || a.ResetCards.Count == nil || *a.ResetCards.Count != 1 || len(a.ResetCards.Sources) != 1 {
		t.Fatalf("observation lost: %+v", a.ResetCards)
	}
	in.Consents[0].State = ConsentDenied
	revoked := Build(in)
	for _, row := range revoked.Rows {
		for _, account := range row.Accounts {
			if account.ResetCards != nil && len(account.ResetCards.Items) != 0 {
				t.Fatal("revoked card survived")
			}
		}
	}
	in.Consents[0].State = ConsentAllowed
	in.ConsentChanged = true
	changed := Build(in)
	for _, row := range changed.Rows {
		for _, account := range row.Accounts {
			if account.ResetCards != nil && len(account.ResetCards.Items) != 0 {
				t.Fatal("changed consent resurrected card")
			}
		}
	}
}

func TestCompleteZeroIsAReadingWithoutWindows(t *testing.T) {
	in := sampleInput()
	zero := 0
	in.Accounts[0].Windows = nil
	in.Accounts[0].ResetCards = &ResetCards{State: ResetCardComplete, Count: &zero, Sources: []ResetCardSource{{Source: ResetCardCodexAccount, ObservedAt: in.Now.Add(-time.Minute)}}}
	projection := Build(in)
	if err := Validate(in, projection); err != nil {
		t.Fatal(err)
	}
	account := rowByID(t, projection, "codex").Accounts[0]
	if account.ValueState != ValueStateCurrent || account.ResetCards == nil || account.ResetCards.State != ResetCardComplete || account.ResetCards.Count == nil || *account.ResetCards.Count != 0 {
		t.Fatalf("known zero lost: %+v", account)
	}
}

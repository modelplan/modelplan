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
	if capped.State != ResetCardPartial || !capped.Truncated || len(capped.Items) != 64 || capped.Count == nil || *capped.Count != 65 || capped.EarliestExpiresAt == nil {
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

func TestResetCardMergeKeepsEarliestAndFreshestSource(t *testing.T) {
	now := time.Date(2026, 11, 3, 12, 0, 0, 0, time.UTC)
	first, second := make([]ResetCardItem, 33), make([]ResetCardItem, 32)
	for i := 0; i < 65; i++ {
		expiry := now.Add(time.Duration(65-i) * time.Minute)
		item := ResetCardItem{ID: fmt.Sprintf("%064x", i+1), ExpiresAt: &expiry}
		if i < 33 {
			first[i] = item
		} else {
			second[i-33] = item
		}
	}
	n1, n2 := len(first), len(second)
	left := &ResetCards{State: ResetCardComplete, Count: &n1, Items: first, Sources: []ResetCardSource{{Source: ResetCardCodexAccount, ObservedAt: now.Add(-time.Minute)}}}
	right := &ResetCards{State: ResetCardComplete, Count: &n2, Items: second, Sources: []ResetCardSource{{Source: ResetCardCodexBar, ObservedAt: now}}}
	got := mergeResetCards([]*ResetCards{left, right})
	if got.State != ResetCardPartial || !got.Truncated || got.Count == nil || *got.Count != 65 || len(got.Items) != 64 || got.EarliestExpiresAt == nil || !got.EarliestExpiresAt.Equal(now.Add(time.Minute)) || got.Items[0].ID != fmt.Sprintf("%064x", 65) || got.Items[63].ID == fmt.Sprintf("%064x", 1) || got.Sources[0].Source != ResetCardCodexBar {
		t.Fatalf("bad merged facts: %+v", got)
	}
	// Differing times alone do not make a complete union partial.
	left.Items, right.Items = first[:1], second[:1]
	n1, n2 = 1, 1
	got = mergeResetCards([]*ResetCards{left, right})
	if got.State != ResetCardComplete || got.Count == nil || *got.Count != 2 || got.Sources[0].Source != ResetCardCodexBar {
		t.Fatalf("different healthy times: %+v", got)
	}
	right.Sources[0].ObservedAt = left.Sources[0].ObservedAt
	got = mergeResetCards([]*ResetCards{right, left})
	if got.Sources[0].Source != ResetCardCodexAccount {
		t.Fatalf("unstable tie break: %+v", got.Sources)
	}
}

func TestResetCardsUseOwnFreshnessDeadline(t *testing.T) {
	in := sampleInput()
	count := 1
	expiry := in.Now.Add(time.Hour)
	for _, tc := range []struct {
		name string
		age  time.Duration
		want ResetCardState
	}{
		{"fresh", time.Hour - time.Second, ResetCardComplete},
		{"deadline", time.Hour, ResetCardUnknown},
		{"old", 2 * time.Hour, ResetCardUnknown},
	} {
		t.Run(tc.name, func(t *testing.T) {
			in.Accounts[0].ResetCards = &ResetCards{State: ResetCardComplete, Count: &count, Items: []ResetCardItem{{ID: fmt.Sprintf("%064x", 1), ExpiresAt: &expiry}}, Sources: []ResetCardSource{{Source: ResetCardCodexAccount, ObservedAt: in.Now.Add(-tc.age)}}}
			p := Build(in)
			if err := Validate(in, p); err != nil {
				t.Fatal(err)
			}
			a := rowByID(t, p, "codex").Accounts[0]
			if a.ResetCards.State != tc.want {
				t.Fatalf("got %+v", a.ResetCards)
			}
			if len(a.Windows) == 0 {
				t.Fatal("fresh quota windows lost")
			}
		})
	}
}

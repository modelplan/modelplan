// SPDX-License-Identifier: MIT
package rows

import (
	"testing"
	"time"
)

func TestActivityStaysOnItsVerifiedAccountAndExpires(t *testing.T) {
	in := sampleInput()
	ref := "aaaaaaaaaaaaaaaa"
	other := "bbbbbbbbbbbbbbbb"
	in.Accounts[0].SubscriptionRef = &ref
	second := in.Accounts[0]
	second.SubscriptionRef = &other
	in.Accounts = append(in.Accounts, second)
	in.Activities = []ActivityInput{{ToolID: "codex", SubscriptionRef: ref, SessionRef: "cccccccccccccccc", BindingVerified: true, Phase: ActivityPhaseTool, RecordAt: in.Now, ExpiresAt: in.Now.Add(5 * time.Minute)}}
	p := Build(in)
	if err := Validate(in, p); err != nil {
		t.Fatal(err)
	}
	a := rowByID(t, p, "codex").Accounts
	if len(a) != 2 {
		t.Fatal("two accounts required")
	}
	for _, v := range a {
		if *v.SubscriptionRef == ref && len(v.Activity) != 1 {
			t.Fatal("bound account missing activity")
		}
		if *v.SubscriptionRef == other && len(v.Activity) != 0 {
			t.Fatal("peer account borrowed activity")
		}
	}
	in.Activities[0].BindingVerified = false
	for _, v := range rowByID(t, Build(in), "codex").Accounts {
		if len(v.Activity) != 0 {
			t.Fatal("unverified binding displayed")
		}
	}
	in.Activities[0].BindingVerified = true
	in.Now = in.Now.Add(5 * time.Minute)
	for _, v := range rowByID(t, Build(in), "codex").Accounts {
		if len(v.Activity) != 0 {
			t.Fatal("expired activity displayed")
		}
	}
}

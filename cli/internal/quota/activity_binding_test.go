// SPDX-License-Identifier: MIT
package quota

import "testing"

func TestUniqueSubscriptionRefsDoesNotCollapseAccounts(t *testing.T) {
	accounts:=[]Account{{Source:"codex",Subscription:&Binding{Ref:"one",Status:"verified"}},{Source:"codex",Subscription:&Binding{Ref:"two",Status:"verified"}},{Source:"claude-code",Subscription:&Binding{Ref:"three",Status:"verified"}}}
	refs:=UniqueSubscriptionRefs(accounts)
	if refs["codex"]!="" || refs["claude-code"]!="three" {t.Fatalf("source fallback invented a binding: %v",refs)}
	accounts[1].Subscription.Ref="one"
	if UniqueSubscriptionRefs(accounts)["codex"]!="one"{t.Fatal("same verified subscription should remain unique")}
}

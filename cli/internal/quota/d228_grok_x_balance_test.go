package quota

import (
	"encoding/json"
	"testing"
)

// D228: an X Subscription billing reply without creditUsagePercent and with no additional-usage
// cap yields the USD balance only, not an empty "Additional usage" window drawn as "--".
func TestD228GrokXSubscriptionWithoutPercentIsBalanceOnly(t *testing.T) {
	var b grokBilling
	if err := json.Unmarshal([]byte(`{"config":{"isUnifiedBillingUser":true,"prepaidBalance":{"val":0},"onDemandUsed":{"val":0},"onDemandCap":{"val":0}}}`), &b); err != nil {
		t.Fatal(err)
	}
	a, ok := parseGrokBilling(b, grokNow)
	if !ok || a == nil {
		t.Fatal("balance-only reply rejected")
	}
	if len(a.Windows) != 0 {
		t.Fatalf("empty additional-usage window kept: %+v", a.Windows)
	}
	if a.Credits == nil || a.Credits.Currency != "USD" || a.Credits.Balance == nil || *a.Credits.Balance != 0 || a.Plan != "The X Subscription" {
		t.Fatalf("balance: %+v", a.Credits)
	}
	in := managedRowsAccount("grok", "k", a, t.TempDir(), grokNow, true)
	if in.Credits == nil || in.Credits.Currency != "USD" {
		t.Fatalf("currency not passed to rows: %+v", in.Credits)
	}
}

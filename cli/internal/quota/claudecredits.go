package quota

import (
	"context"
	"math"
	"net/http"
	"strings"
	"time"
)

// The OAuth prepaid route is beta. The amount/currency shape follows CodexBar's
// ClaudeWebAPIFetcher prepaid response at 0.81.0 (MIT); authentication here uses
// only the explicitly admitted OAuth account, never browser cookies. No project
// or organization enumeration and no top-up/reset operation is performed.
func readClaudeCredits(ctx context.Context, c *http.Client, org, token string, now time.Time) (*Credits, string, time.Time) {
	if !claudeID.MatchString(org) {
		return nil, "not-supported", time.Time{}
	}
	var v struct {
		Amount   *float64 `json:"amount"`
		Currency string   `json:"currency"`
	}
	state, retry := claudeGet(ctx, c, "/api/oauth/organizations/"+org+"/prepaid/credits", token, &v, now)
	if state != "" {
		return nil, state, retry
	}
	if v.Amount == nil || !strings.EqualFold(v.Currency, "usd") || math.IsNaN(*v.Amount) || math.IsInf(*v.Amount, 0) || *v.Amount < 0 || *v.Amount > 1e14 {
		return nil, "not-supported", retry
	}
	amount := *v.Amount / 100
	return &Credits{Balance: &amount, Currency: "USD", Unit: "money", ObservedAt: now.UTC()}, "", retry
}

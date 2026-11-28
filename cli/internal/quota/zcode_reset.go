// SPDX-License-Identifier: MIT
//
// ZCode Coding Plan reset opportunities (build-6 feedback, 2026-11-27): the extra resets ZCode
// grants to a Coding Plan account ("重置机会"), one per five-hour or weekly window, each with an
// expiry. They are the GLM account's reserve and travel as Account.Cards (kind five_hour or
// weekly), exactly like Codex's banked resets travel as kind full.
//
// No panel app (CodexBar, Pulse, Token Monitor, ccusage) reads this endpoint, so the route follows
// ZCode's own client (https://github.com/zai-org/ZCode, v4.0.0, a4b44451):
// packages/services/src/usage-stats/providers/bigmodelUsageQuotaProvider.ts
// (getCodingPlanResetStatus, createCodingPlanResetHeaders, codingPlanResetStatusDataSchema).
// Behaviour only; the code is our own.
//
// ModelPlan limits: GET /status only (never /opportunity, /use or /history/read, which spend or
// change state); the z.ai family only (a BigModel sign-in is never sent to zcode.z.ai); the personal
// scope only; best effort, so a failure here never changes the quota reading; both tokens stay in
// memory for one read.
package quota

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

// zcodeResetURL is ZCode's Coding Plan reset status endpoint on its own origin.
const zcodeResetURL = "https://zcode.z.ai/api/v1/coding-plan/reset/status"

// zcodeResetAuth is what the status call needs besides the quota credential: ZCode's own JWT, the
// MaaS sign-in token and ZCode's device id. Empty when the store lacks any of them.
type zcodeResetAuth struct {
	jwt, maas, deviceMid string
}

func (a zcodeResetAuth) ready() bool { return a.jwt != "" && a.maas != "" && a.deviceMid != "" }

// zcodeResetCredentials opens the two tokens from the (already decrypted-on-demand) store. Only the
// z.ai family: zcode.z.ai is an international host. A token that is expired, oversized or carries
// a control character is dropped, never sent.
func zcodeResetCredentials(store map[string]any, open func(string) string, family, kind, dir string, now time.Time) zcodeResetAuth {
	// A team Coding Plan is looked up with the organization and project headers
	// (bigmodelUsageQuotaProvider.ts createCodingPlanResetHeaders, resolveTeamPlanContext), which are not read
	// here: the team keeps its quota and shows no reserve rather than a personal one.
	if family != "zai" || kind == "team-coding-plan" || store == nil {
		return zcodeResetAuth{}
	}
	token := func(name string) string {
		raw, _ := store[name].(string)
		v := strings.TrimSpace(open(raw))
		if v == "" || len(v) > 8192 || strings.ContainsAny(v, "\r\n\x00") {
			return ""
		}
		return v
	}
	jwt := token("zcodejwttoken")
	if jwt == "" || zcodeJWTExpired(jwt, now) {
		return zcodeResetAuth{}
	}
	maas := token("oauth:" + family + ":access_token")
	if maas == "" {
		return zcodeResetAuth{}
	}
	return zcodeResetAuth{jwt: jwt, maas: maas, deviceMid: zcodeDeviceMid(dir)}
}

// zcodeMaxExpiryMs bounds an expiry to the JSON time range (year 9999); a larger value would pass
// time.UnixMilli and then fail to marshal, losing the whole reading.
const zcodeMaxExpiryMs = 253402300799000

// zcodeResetResponse is the status envelope: code 0 is success, expire_at is Unix milliseconds.
type zcodeResetResponse struct {
	Code *int `json:"code"`
	Data *struct {
		FiveHour []zcodeResetOpportunity `json:"available_five_hour_resets"`
		Week     []zcodeResetOpportunity `json:"available_week_resets"`
	} `json:"data"`
}
type zcodeResetOpportunity struct {
	ExpireAt json.RawMessage `json:"expire_at"`
}

// parseZCodeResets maps the status to cards: one card per kind and expiry (Count = how many share
// it), the already expired dropped. A well-formed empty status is no cards and ok; a body that is
// not the documented shape is not ok, so a changed API never reads as "no resets".
func parseZCodeResets(r zcodeResetResponse, now time.Time) (cards []Card, ok bool) {
	if r.Code == nil || *r.Code != 0 || r.Data == nil || len(r.Data.FiveHour) > 1000 || len(r.Data.Week) > 1000 {
		return nil, false
	}
	for _, group := range []struct {
		kind  string
		items []zcodeResetOpportunity
	}{{"five_hour", r.Data.FiveHour}, {"weekly", r.Data.Week}} {
		byTime := map[time.Time]int{}
		for _, item := range group.items {
			ms, err := strconv.ParseInt(strings.Trim(strings.TrimSpace(string(item.ExpireAt)), `"`), 10, 64)
			if err != nil || ms <= 0 || ms > zcodeMaxExpiryMs {
				return nil, false // an opportunity without a usable expiry is a changed shape
			}
			at := time.UnixMilli(ms).UTC()
			if at.After(now) {
				byTime[at]++
			}
		}
		times := make([]time.Time, 0, len(byTime))
		for t := range byTime {
			times = append(times, t)
		}
		sort.Slice(times, func(i, j int) bool { return times[i].Before(times[j]) })
		for _, t := range times {
			n, at := byTime[t], t
			cards = append(cards, Card{Kind: group.kind, Count: &n, ExpiresAt: &at})
		}
	}
	return cards, true
}

// withZCodeResets adds the reserve to a good reading. A failure leaves the reading as it was and
// is not reported: the reserve is an extra, not the quota.
func withZCodeResets(ctx context.Context, c *http.Client, login zcodeLogin, e codexbarEntry, now time.Time) codexbarEntry {
	if e.Status != "ok" || !login.reset.ready() || ctx.Err() != nil {
		return e
	}
	headers := map[string]string{
		"Authorization":            "Bearer " + login.reset.jwt,
		"X-Bigmodel-Authorization": login.reset.maas,
		"Bigmodel-Target-Type":     "PERSONAL",
		"X-Device-Mid":             login.reset.deviceMid,
	}
	var r zcodeResetResponse
	if getJSONHeaders(ctx, c, zcodeResetURL, headers, &r) != nil {
		return e
	}
	if cards, ok := parseZCodeResets(r, now); ok {
		e.Cards = cards
	}
	return e
}

// liveCards: the cards still unexpired at now (a cached reading outlives its cards).
func liveCards(cards []Card, now time.Time) []Card {
	var out []Card
	for _, c := range cards {
		if c.ExpiresAt == nil || c.ExpiresAt.After(now) {
			out = append(out, c)
		}
	}
	return out
}

// zcodeResetFacts: the rows view of the same cards (widget "Reserve ↺N"). Items carry an id
// derived from kind, expiry and position, so two resets with one expiry stay two items. Nil when
// there is nothing to say; "partial" never applies because the endpoint lists every opportunity.
func zcodeResetFacts(cards []Card, observed, now time.Time) *rows.ResetCards {
	cards = liveCards(cards, now) // the same instant as Account.Cards, so both surfaces drop the same expired card
	if len(cards) == 0 || observed.IsZero() {
		return nil
	}
	facts := &rows.ResetCards{State: rows.ResetCardComplete, Sources: []rows.ResetCardSource{{Source: rows.ResetCardZCodeAccount, ObservedAt: observed.UTC()}}}
	total, allExpiring := 0, true
	for _, c := range cards {
		n := 1
		if c.Count != nil {
			n = *c.Count
		}
		when := "never"
		var at *time.Time
		if c.ExpiresAt != nil {
			t := c.ExpiresAt.UTC()
			at, when = &t, strconv.FormatInt(t.UnixMilli(), 10)
		} else {
			allExpiring = false
		}
		for i := 0; i < n; i++ {
			total++
			if len(facts.Items) >= 64 {
				facts.Truncated, facts.State = true, rows.ResetCardPartial
				continue
			}
			sum := sha256.Sum256([]byte("zcode-reset|" + c.Kind + "|" + when + "|" + strconv.Itoa(i)))
			facts.Items = append(facts.Items, rows.ResetCardItem{ID: hex.EncodeToString(sum[:]), ExpiresAt: at})
			if at != nil && (facts.EarliestExpiresAt == nil || at.Before(*facts.EarliestExpiresAt)) {
				facts.EarliestExpiresAt = at
			}
		}
	}
	facts.Count = &total
	if !allExpiring || facts.State != rows.ResetCardComplete {
		facts.EarliestExpiresAt = nil
	}
	return facts
}

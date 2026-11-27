// SPDX-License-Identifier: MIT
package quota

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/consent"
	"github.com/modelplan/modelplan/cli/internal/rows"
)

// The reserve of a ZCode Coding Plan account: the extra five-hour and weekly resets from
// GET /api/v1/coding-plan/reset/status (ZCode's own client, zai-org/ZCode a4b44451, bigmodelUsageQuotaProvider.ts).
// The fixture body has the shape ZCode's codingPlanResetStatusDataSchema parses: envelope code 0,
// expire_at in Unix milliseconds, snake_case.

const zcodeMaasCanary = "maas-token-canary-reset"

var zcodeResetClock = time.Date(2026, 11, 21, 12, 0, 0, 0, time.UTC)

func zcodeResetBody(code int, five, week []time.Time) string {
	list := func(ts []time.Time) []map[string]any {
		out := []map[string]any{}
		for _, t := range ts {
			out = append(out, map[string]any{"expire_at": t.UnixMilli()})
		}
		return out
	}
	b, _ := json.Marshal(map[string]any{"code": code, "msg": "ok", "data": map[string]any{
		"available_five_hour_resets": list(five), "available_week_resets": list(week),
		"latest_five_hour_reset_history": nil, "latest_week_reset_history": map[string]any{"used_at": zcodeResetClock.Add(-48 * time.Hour).UnixMilli()},
		"has_unread_history": false}})
	return string(b)
}

// addMaasToken puts the MaaS sign-in token into the encrypted store, as ZCode keeps it.
func addMaasToken(t *testing.T, dir string) {
	t.Helper()
	path := filepath.Join(dir, "credentials.json")
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	store := map[string]any{}
	if err := json.Unmarshal(b, &store); err != nil {
		t.Fatal(err)
	}
	store["oauth:zai:access_token"] = zcodeTestEncrypt(t, zcodeMaasCanary, zcodeTestSecret)
	out, _ := json.Marshal(store)
	if err := os.WriteFile(path, out, 0o600); err != nil {
		t.Fatal(err)
	}
}

type zcodeRoutes struct {
	mu   sync.Mutex
	seen []*http.Request
}

func (z *zcodeRoutes) requests() []*http.Request {
	z.mu.Lock()
	defer z.mu.Unlock()
	return append([]*http.Request(nil), z.seen...)
}

// newZCodeRouteServer answers by path: the quota, the Start Plan balance and the reset status.
func newZCodeRouteServer(t *testing.T, quota, billing, reset string, resetStatus int) *zcodeRoutes {
	t.Helper()
	z := &zcodeRoutes{}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		z.mu.Lock()
		z.seen = append(z.seen, r.Clone(context.Background()))
		z.mu.Unlock()
		switch r.URL.Path {
		case "/api/monitor/usage/quota/limit":
			_, _ = w.Write([]byte(quota))
		case "/api/v1/zcode-plan/billing/balance":
			_, _ = w.Write([]byte(billing))
		case "/api/v1/coding-plan/reset/status":
			w.WriteHeader(resetStatus)
			_, _ = w.Write([]byte(reset))
		default:
			w.WriteHeader(404)
		}
	}))
	t.Cleanup(server.Close)
	old := nativeClient
	t.Cleanup(func() { nativeClient = old })
	nativeClient = readerFixtureClient(t, server, "api.z.ai", "zcode.z.ai")
	return z
}

func zcodeResetSetup(t *testing.T, kind string, withMaas bool) (cache string, dir string, jwt string) {
	t.Helper()
	isolateHome(t)
	t.Setenv("Z_AI_API_KEY", "")
	home, _ := os.UserHomeDir()
	jwt = zcodeTestJWT(time.Now().Add(time.Hour))
	dir = writeZCodeLogin(t, home, zcodeFixture{family: "zai", kind: kind, accountKey: kind != "start-plan", jwt: jwt, deviceMid: true})
	if withMaas {
		addMaasToken(t, dir)
	}
	grantZCodeKeychain(t, "allow")
	return t.TempDir(), dir, jwt
}

func readZCodeReset(t *testing.T, cache string) (Report, *Account) {
	t.Helper()
	p := ProductionPathsWithAdmission(cache, "1.0.0", consent.Capture())
	if err := ExecuteScopeRefresh(context.Background(), p, consent.ScopeZaiAccountUsageSavedLogin, zcodeResetClock); err != nil {
		t.Fatalf("refresh: %v", err)
	}
	r := ReadPermitted(p, zcodeResetClock)
	return r, zcodeAccount(r)
}

// Coding Plan: the reserve follows the quota in one read, with ZCode's two tokens and device id,
// and reaches the account as cards (cockpit) and as rows facts (widget).
func TestZCodeCodingPlanReserveCards(t *testing.T) {
	cache, _, jwt := zcodeResetSetup(t, "individual-coding-plan", true)
	soon, later := zcodeResetClock.Add(30*time.Hour), zcodeResetClock.Add(100*time.Hour)
	z := newZCodeRouteServer(t, zcodeQuotaBody, "", zcodeResetBody(0, []time.Time{soon, soon}, []time.Time{later}), 200)
	r, a := readZCodeReset(t, cache)
	reqs := z.requests()
	if len(reqs) != 2 || reqs[0].URL.Path != "/api/monitor/usage/quota/limit" || reqs[1].URL.Path != "/api/v1/coding-plan/reset/status" {
		t.Fatalf("requests: %d", len(reqs))
	}
	if reqs[1].Method != http.MethodGet || reqs[1].Host != "zcode.z.ai" || reqs[1].URL.RawQuery != "" {
		t.Fatalf("status request: %s %s?%s", reqs[1].Method, reqs[1].Host, reqs[1].URL.RawQuery)
	}
	h := reqs[1].Header
	if h.Get("Authorization") != "Bearer "+jwt || h.Get("X-Bigmodel-Authorization") != zcodeMaasCanary ||
		h.Get("Bigmodel-Target-Type") != "PERSONAL" || h.Get("X-Device-Mid") != zcodeMidCanary {
		t.Fatalf("status headers: %v", h)
	}
	if a == nil || len(a.Windows) == 0 {
		t.Fatalf("quota row missing: %+v", a)
	}
	if len(a.Cards) != 2 || a.Cards[0].Kind != "five_hour" || *a.Cards[0].Count != 2 || !a.Cards[0].ExpiresAt.Equal(soon) ||
		a.Cards[1].Kind != "weekly" || *a.Cards[1].Count != 1 || !a.Cards[1].ExpiresAt.Equal(later) {
		t.Fatalf("cards: %+v", a.Cards)
	}
	f := a.ResetCards
	if f == nil || f.State != rows.ResetCardComplete || f.Count == nil || *f.Count != 3 || len(f.Items) != 3 ||
		f.EarliestExpiresAt == nil || !f.EarliestExpiresAt.Equal(soon) ||
		len(f.Sources) != 1 || f.Sources[0].Source != rows.ResetCardZCodeAccount {
		t.Fatalf("rows facts: %+v", f)
	}
	assertNoZCodeSecret(t, cache, r)
	for _, secret := range []string{zcodeMaasCanary, jwt} {
		if b, _ := json.Marshal(r); strings.Contains(string(b), secret) {
			t.Fatal("a token reached the report")
		}
	}
}

// Start Plan: billing first, then the reserve on the same host.
func TestZCodeStartPlanReserveCards(t *testing.T) {
	cache, _, _ := zcodeResetSetup(t, "start-plan", true)
	at := zcodeResetClock.Add(6 * time.Hour)
	billing := `{"code":200,"data":{"plans":[{"name":"ZCode Start Plan","status":"active","plan_id":"p1","entitlements":[{"entitlement_id":"e1","period":"daily"}]}],
	 "balances":[{"entitlement_id":"e1","plan_id":"p1","show_name":"GLM-5.3","total_units":1000,"used_units":250,"remaining_units":750,"expires_at":` + jsonInt(at.Unix()) + `}]}}`
	z := newZCodeRouteServer(t, "", billing, zcodeResetBody(0, nil, []time.Time{zcodeResetClock.Add(48 * time.Hour)}), 200)
	_, a := readZCodeReset(t, cache)
	reqs := z.requests()
	if len(reqs) != 2 || reqs[0].URL.Path != "/api/v1/zcode-plan/billing/balance" || reqs[1].URL.Path != "/api/v1/coding-plan/reset/status" {
		t.Fatalf("requests: %d", len(reqs))
	}
	if a == nil || len(a.Cards) != 1 || a.Cards[0].Kind != "weekly" || *a.Cards[0].Count != 1 {
		t.Fatalf("cards: %+v", a)
	}
}

// No MaaS token in the store: the quota is read as before, the reserve call is never made.
func TestZCodeReserveNeedsTheMaasToken(t *testing.T) {
	cache, _, _ := zcodeResetSetup(t, "individual-coding-plan", false)
	z := newZCodeRouteServer(t, zcodeQuotaBody, "", zcodeResetBody(0, []time.Time{zcodeResetClock.Add(time.Hour)}, nil), 200)
	_, a := readZCodeReset(t, cache)
	if n := len(z.requests()); n != 1 {
		t.Fatalf("%d requests, want the quota only", n)
	}
	if a == nil || len(a.Windows) == 0 || len(a.Cards) != 0 || a.ResetCards != nil {
		t.Fatalf("account: %+v", a)
	}
}

// A failing or reshaped status never touches the quota reading and is never read as "no resets"
// with a stale card kept: the account simply has no cards.
func TestZCodeReserveFailureKeepsQuota(t *testing.T) {
	for name, tc := range map[string]struct {
		body   string
		status int
	}{
		"http 500":      {"{}", 500},
		"http 401":      {"{}", 401},
		"envelope code": {zcodeResetBody(2007, nil, nil), 200},
		"not json":      {"<html>", 200},
		"no expiry":     {`{"code":0,"data":{"available_five_hour_resets":[{}],"available_week_resets":[]}}`, 200},
		"no data":       {`{"code":0}`, 200},
	} {
		t.Run(name, func(t *testing.T) {
			cache, _, _ := zcodeResetSetup(t, "individual-coding-plan", true)
			newZCodeRouteServer(t, zcodeQuotaBody, "", tc.body, tc.status)
			_, a := readZCodeReset(t, cache)
			if a == nil || len(a.Windows) == 0 || *a.Windows[0].UsedPercent != 40 {
				t.Fatalf("quota lost: %+v", a)
			}
			if len(a.Cards) != 0 || a.ResetCards != nil {
				t.Fatalf("cards from a bad status: %+v %+v", a.Cards, a.ResetCards)
			}
		})
	}
}

// An empty list is a reading of "none": no cards and no rows facts, and an expired one is dropped.
func TestZCodeReserveEmptyAndExpired(t *testing.T) {
	cache, _, _ := zcodeResetSetup(t, "individual-coding-plan", true)
	newZCodeRouteServer(t, zcodeQuotaBody, "", zcodeResetBody(0, []time.Time{zcodeResetClock.Add(-time.Minute)}, nil), 200)
	_, a := readZCodeReset(t, cache)
	if a == nil || len(a.Cards) != 0 || a.ResetCards != nil {
		t.Fatalf("expired reset shown: %+v", a)
	}
}

// Only the status is ever called: no /opportunity, /use or /history/read, and no BigModel sign-in
// is sent to zcode.z.ai.
func TestZCodeReserveRequestSet(t *testing.T) {
	cache, _, _ := zcodeResetSetup(t, "individual-coding-plan", true)
	z := newZCodeRouteServer(t, zcodeQuotaBody, "", zcodeResetBody(0, nil, nil), 200)
	readZCodeReset(t, cache)
	for _, r := range z.requests() {
		if strings.Contains(r.URL.Path, "opportunity") || strings.HasSuffix(r.URL.Path, "/use") || strings.Contains(r.URL.Path, "history") || r.Method != http.MethodGet {
			t.Fatalf("forbidden request %s %s", r.Method, r.URL.Path)
		}
	}
}

func TestParseZCodeResetsShape(t *testing.T) {
	code := 0
	soon := zcodeResetClock.Add(time.Hour).UnixMilli()
	raw := func(v int64) json.RawMessage { b, _ := json.Marshal(v); return b }
	str := json.RawMessage(`"` + jsonInt(soon) + `"`) // a string-typed number is read too
	r := zcodeResetResponse{Code: &code, Data: &struct {
		FiveHour []zcodeResetOpportunity `json:"available_five_hour_resets"`
		Week     []zcodeResetOpportunity `json:"available_week_resets"`
	}{FiveHour: []zcodeResetOpportunity{{raw(soon)}, {str}}}}
	cards, ok := parseZCodeResets(r, zcodeResetClock)
	if !ok || len(cards) != 1 || *cards[0].Count != 2 {
		t.Fatalf("cards %+v ok=%t", cards, ok)
	}
	bad := 5
	r.Code = &bad
	if _, ok := parseZCodeResets(r, zcodeResetClock); ok {
		t.Fatal("a non-zero envelope code was accepted")
	}
}

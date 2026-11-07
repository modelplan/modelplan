package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/rows"
)

var acctNow = time.Date(2026, 10, 16, 8, 0, 0, 0, time.UTC)

const acctResponse = `{"ordinaryUsageAllowed":true,"accountId":"acct-secret","rateLimits":null,
 "rateLimitsByLimitId":{"codex":{"limitId":"codex","planType":"pro",
   "primary":{"usedPercent":12,"windowDurationMins":300,"resetsAt":1792148400},
   "secondary":{"usedPercent":48,"windowDurationMins":10080,"resetsAt":1792649570}}},
 "rateLimitResetCredits":{"availableCount":2,"credits":[
   {"id":"cr-secret-1","resetType":"codexRateLimits","status":"available","grantedAt":1791000000,"expiresAt":1793299977,"title":"Full reset","description":null},
   {"id":"cr-secret-2","resetType":"codexRateLimits","status":"available","grantedAt":1791000000,"expiresAt":1793987862,"title":"Full reset","description":null},
   {"id":"cr-secret-3","resetType":"codexRateLimits","status":"redeemed","grantedAt":1790000000,"expiresAt":null,"title":null,"description":null}]}}`

// fakeCodex answers initialize and account/rateLimits/read like `codex app-server` and records
// every method it was asked for.
func fakeCodex(t *testing.T, result string) (bin, log string) {
	dir := t.TempDir()
	bin, log = filepath.Join(dir, "codex"), filepath.Join(dir, "calls")
	script := `#!/bin/sh
[ "$1" = app-server ] || exit 2
while IFS= read -r line; do
  m=$(printf '%s' "$line" | sed -n 's/.*"method":"\([^"]*\)".*/\1/p'); echo "$m" >> "` + log + `"
  case "$line" in
    *'"id":1,'*) echo '{"id":1,"result":{"userAgent":"x"}}' ;;
    *'"method":"account/read"'*) echo '{"id":3,"result":{"account":{"type":"chatgpt","email":"Someone@Example.com","planType":"pro"},"requiresOpenaiAuth":true}}' ;;
    *'"method":"account/rateLimits/read"'*) printf '{"id":2,"result":%s}\n' '` + strings.ReplaceAll(result, "\n", "") + `' ;;
  esac
done
`
	if err := os.WriteFile(bin, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return bin, log
}

func TestRefreshReadsTheAccountWithoutIdsAndNeverConsumes(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	bin, log := fakeCodex(t, acctResponse)
	if !AccountDue(cache, acctNow) {
		t.Fatal("no reading yet: due")
	}
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	calls, _ := os.ReadFile(log)
	if got := strings.Fields(string(calls)); strings.Join(got, ",") != "initialize,initialized,account/rateLimits/read,account/read" {
		t.Fatalf("calls = %v", got)
	}
	b, _ := os.ReadFile(accountPath(cache))
	m, _ := os.ReadFile(subscriptionsPath(cache))
	for _, f := range [][]byte{b, m} {
		if strings.Contains(strings.ToLower(string(f)), "secret") || strings.Contains(strings.ToLower(string(f)), "example.com") {
			t.Fatalf("ids cached: %s", f)
		}
	}
	ref := loadAccount(cache).SubscriptionRef
	if len(ref) != 16 {
		t.Fatalf("subscription = %q", ref)
	}
	s := loadAccount(cache)
	if s.Status != "ok" || s.Plan != "pro" || len(s.Windows) != 2 || s.Credits.Count != 2 || len(s.Credits.Expiries) != 2 {
		t.Fatalf("snap = %+v", s)
	}
	if AccountDue(cache, acctNow.Add(4*time.Minute)) || !AccountDue(cache, acctNow.Add(5*time.Minute)) {
		t.Fatal("refresh at most every 5 minutes")
	}
	// The same account keeps its reference; the report carries it as verified.
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow.Add(2*time.Hour)); err != nil || loadAccount(cache).SubscriptionRef != ref {
		t.Fatal("the reference is stable")
	}
	r := Report{}
	applyAccount(&r, cache, acctNow.Add(2*time.Hour))
	if s := r.Accounts[0].Subscription; s == nil || s.Ref != ref || s.Status != "verified" || s.Basis != "codex-account" {
		t.Fatalf("binding = %+v", s)
	}
}

func TestFailedRefreshWaitsLongerAndOffMeansOff(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	if err := RefreshCodexAccount(context.Background(), cache, "", acctNow); err != nil {
		t.Fatal(err)
	}
	if loadAccount(cache).Status != "error" || AccountDue(cache, acctNow.Add(10*time.Minute)) || !AccountDue(cache, acctNow.Add(31*time.Minute)) {
		t.Fatal("a failure is retried after half an hour")
	}
	t.Setenv("MODELPLAN_CODEX_ACCOUNT", "off")
	if AccountDue(t.TempDir(), acctNow) {
		t.Fatal("off is off")
	}
}

func TestAccountReadingMergesWithLogsAndAddsCredits(t *testing.T) {
	isolateHome(t)
	var resp rlResponse
	if err := json.Unmarshal([]byte(acctResponse), &resp); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	boundSnap := func(r *rlResponse) *accountSnap {
		s := snapFrom(r, acctNow)
		s.SubscriptionRef = "0123456789abcdef"
		return s
	}
	binding := func() *Binding { return &Binding{Ref: "0123456789abcdef", Status: "verified"} }
	if err := save(cache, boundSnap(&resp)); err != nil {
		t.Fatal(err)
	}
	old := acctNow.Add(-2 * time.Hour)
	r := Report{Accounts: []Account{{Source: "codex", Subscription: binding(), Plan: "pro", ObservedAt: old, Harness: &Harness{Model: "gpt-6-astra"},

		Windows: []Window{{Kind: "five_hour", UsedPercent: ptr(70.0), WindowMinutes: 300, ObservedAt: old}}}},
		Sources: []SourceStatus{{Source: "codex", Status: "ok"}}}
	applyAccount(&r, cache, acctNow)
	a := r.Accounts[0]
	if len(a.Windows) != 2 || *a.Windows[0].UsedPercent != 12 || *a.Windows[1].UsedPercent != 48 || a.Via != "codex-account" || a.Harness.Model != "gpt-6-astra" {
		t.Fatalf("merged = %+v", a)
	}
	if len(a.Cards) != 2 || a.Cards[0].Kind != "full" || *a.Cards[0].Count != 1 || !a.Cards[0].ExpiresAt.Equal(time.Unix(1793299977, 0)) {
		t.Fatalf("cards = %+v", a.Cards)
	}

	// No logs at all: the reading stands alone and the source says why.
	alone := Report{Sources: []SourceStatus{{Source: "codex", Status: "missing"}}}
	applyAccount(&alone, cache, acctNow)
	if len(alone.Accounts) != 1 || alone.Sources[0].Status != "ok" || len(alone.Accounts[0].Windows) != 2 {
		t.Fatalf("alone = %+v", alone)
	}
	// Too old: ignored.
	stale := Report{}
	applyAccount(&stale, cache, acctNow.Add(7*time.Hour))
	if len(stale.Accounts) != 0 {
		t.Fatal("a reading older than 6h is ignored")
	}
}

func TestUsageCreditsFromAccountAndLogs(t *testing.T) {
	isolateHome(t)
	withCredits := strings.Replace(acctResponse, `"planType":"pro",`, `"planType":"pro","credits":{"hasCredits":true,"unlimited":false,"balance":"73172.5"},`, 1)
	var resp rlResponse
	if err := json.Unmarshal([]byte(withCredits), &resp); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	boundSnap := func(r *rlResponse) *accountSnap {
		s := snapFrom(r, acctNow)
		s.SubscriptionRef = "0123456789abcdef"
		return s
	}
	binding := func() *Binding { return &Binding{Ref: "0123456789abcdef", Status: "verified"} }
	if err := save(cache, boundSnap(&resp)); err != nil {

		t.Fatal(err)
	}
	// The logs' older balance gives way to the newer account reading.
	old := acctNow.Add(-time.Hour)
	r := Report{Accounts: []Account{{Source: "codex", Subscription: binding(), Plan: "pro", ObservedAt: old, Credits: &Credits{Balance: ptr(80000), ObservedAt: old}}}}

	applyAccount(&r, cache, acctNow)
	c := r.Accounts[0].Credits
	if c == nil || c.Balance == nil || *c.Balance != 73172.5 || !c.ObservedAt.Equal(acctNow) {
		t.Fatalf("credits = %+v", c)
	}
	Evaluate(&r.Accounts[0], acctNow.Add(20*time.Minute))
	if *c.AgeMinutes != 20 {
		t.Fatalf("age = %d", *c.AgeMinutes)
	}

	// A reading without the field (older Codex) leaves the logs' balance alone; one that says
	// there are none clears it.
	none := strings.Replace(acctResponse, `"planType":"pro",`, `"planType":"pro","credits":{"hasCredits":false,"unlimited":false,"balance":null},`, 1)
	var older rlResponse
	_ = json.Unmarshal([]byte(acctResponse), &older)
	_ = save(cache, boundSnap(&older))
	r = Report{Accounts: []Account{{Source: "codex", Subscription: binding(), ObservedAt: old, Credits: &Credits{Balance: ptr(5), ObservedAt: old}}}}

	applyAccount(&r, cache, acctNow)
	if r.Accounts[0].Credits == nil {
		t.Fatal("a reading without the field keeps the logs' balance")
	}
	var empty rlResponse
	_ = json.Unmarshal([]byte(none), &empty)
	_ = save(cache, boundSnap(&empty))

	applyAccount(&r, cache, acctNow)
	if r.Accounts[0].Credits != nil {
		t.Fatal("no credits now: cleared")
	}

	// Session logs: the latest turn's balance; unlimited without a figure; bad figures dropped.
	dir := t.TempDir()
	p := filepath.Join(dir, "rollout-2026-10-16T07-00-00-x.jsonl")
	line := func(ts, credits string) string {
		return `{"timestamp":"` + ts + `","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":100,"window_minutes":10080,"resets_at":1792649570},"credits":` + credits + `,"plan_type":"plus"}}}` + "\n"
	}
	_ = os.WriteFile(p, []byte(line("2026-10-16T07:00:00Z", `{"has_credits":true,"unlimited":false,"balance":"900"}`)+
		line("2026-10-16T07:30:00Z", `{"has_credits":true,"unlimited":false,"balance":"880.25"}`)), 0o600)
	if got := scanRollout(p).credits; got == nil || *got.Balance != 880.25 {
		t.Fatalf("log credits = %+v", got)
	}
	for credits, want := range map[string]string{
		`{"has_credits":false,"unlimited":false,"balance":null}`: "none",
		`{"has_credits":true,"unlimited":true,"balance":null}`:   "unlimited",
		`{"has_credits":true,"unlimited":false,"balance":"-3"}`:  "none",
		`{"has_credits":true,"unlimited":false,"balance":12.5}`:  "12.5",
	} {
		_ = os.WriteFile(p, []byte(line("2026-10-16T07:00:00Z", credits)), 0o600)
		got, c := "none", scanRollout(p).credits
		switch {
		case c != nil && c.Unlimited:
			got = "unlimited"
		case c != nil:
			got = strconv.FormatFloat(*c.Balance, 'f', -1, 64)
		}
		if got != want {
			t.Errorf("%s: got %s want %s", credits, got, want)
		}
	}
}

func TestCreditsWithoutDetailsAreCounted(t *testing.T) {
	isolateHome(t)
	cards := creditCards(3, nil)
	if len(cards) != 1 || *cards[0].Count != 3 || cards[0].ExpiresAt != nil {
		t.Fatalf("cards = %+v", cards)
	}
}

func ptr(v float64) *float64 { return &v }

func TestResetCreditCountRequiresExplicitNumber(t *testing.T) {
	for _, tc := range []struct {
		name, payload string
		wantPresent   bool
	}{
		{"absent object", `{}`, false},
		{"missing count", `{"rateLimitResetCredits":{}}`, false},
		{"null count", `{"rateLimitResetCredits":{"availableCount":null}}`, false},
		{"explicit zero", `{"rateLimitResetCredits":{"availableCount":0}}`, true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var response rlResponse
			if err := json.Unmarshal([]byte(tc.payload), &response); err != nil {
				t.Fatal(err)
			}
			got := snapFrom(&response, acctNow).Credits
			if (got != nil) != tc.wantPresent {
				t.Fatalf("unexpected reset-credit availability: %+v", got)
			}
			if got != nil && got.Count != 0 {
				t.Fatalf("expected zero, got %d", got.Count)
			}
		})
	}
}

func TestResetCardsUseOpaqueDeduplicatedIDsAndReportCap(t *testing.T) {
	isolateHome(t)
	var response rlResponse
	if err := json.Unmarshal([]byte(acctResponse), &response); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	snap := snapFrom(&response, acctNow)
	attachResetCardIdentities(snap, &response, cache)
	if snap.Credits == nil || !snap.Credits.IdentityComplete || len(snap.Credits.Items) != 2 {
		t.Fatalf("missing identities: %+v", snap.Credits)
	}
	encoded, err := json.Marshal(snap)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(encoded), "cr-secret") {
		t.Fatal("provider ID leaked into cache")
	}
	again := snapFrom(&response, acctNow)
	attachResetCardIdentities(again, &response, cache)
	if again.Credits.Items[0].ID != snap.Credits.Items[0].ID {
		t.Fatal("identity was not stable")
	}
	response.RateLimitResetCredit.Credits = append(response.RateLimitResetCredit.Credits, response.RateLimitResetCredit.Credits[0])
	duplicate := snapFrom(&response, acctNow)
	attachResetCardIdentities(duplicate, &response, cache)
	if len(duplicate.Credits.Items) != 2 {
		t.Fatal("duplicate ID was not removed")
	}
	for len(response.RateLimitResetCredit.Credits) < 65 {
		response.RateLimitResetCredit.Credits = append(response.RateLimitResetCredit.Credits, response.RateLimitResetCredit.Credits[0])
	}
	capped := snapFrom(&response, acctNow)
	attachResetCardIdentities(capped, &response, cache)
	if !capped.Credits.Truncated || capped.Credits.IdentityComplete {
		t.Fatal("truncated input asserted completeness")
	}
}

func TestResetCardsForgetRemovesCapturedFacts(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	bin, _ := fakeCodex(t, acctResponse)
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	before := Report{}
	applyAccount(&before, cache, acctNow)
	if len(before.Accounts) != 1 || before.Accounts[0].ResetCards == nil || len(before.Accounts[0].ResetCards.Items) != 2 {
		t.Fatalf("missing admitted facts: %+v", before.Accounts)
	}
	if err := ForgetTool(Paths{Cache: cache}, "codex"); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(accountPath(cache)); !os.IsNotExist(err) {
		t.Fatalf("cache survived forget: %v", err)
	}
	after := Report{}
	applyAccount(&after, cache, acctNow)
	if len(after.Accounts) != 0 {
		t.Fatal("forgotten cards resurrected")
	}
}

func TestCachedResetCountPresence(t *testing.T) {
	isolateHome(t)
	for _, tc := range []struct {
		name, value string
		known       bool
		count       int
	}{
		{"missing", "", false, 0}, {"null", `"count":null,`, false, 0},
		{"malformed", `"count":"zero",`, false, 0}, {"zero", `"count":0,`, true, 0},
		{"positive", `"count":1,`, true, 1},
	} {
		t.Run(tc.name, func(t *testing.T) {
			cache := t.TempDir()
			if err := os.MkdirAll(filepath.Dir(accountPath(cache)), 0700); err != nil {
				t.Fatal(err)
			}
			raw := `{"schemaVersion":1,"status":"ok","observedAt":"2026-10-16T08:00:00Z","credits":{` + tc.value + `"identityObserved":true,"identityComplete":true}}`
			if err := writeAtomic(accountPath(cache), []byte(raw)); err != nil {
				t.Fatal(err)
			}
			report := Report{}
			applyAccount(&report, cache, acctNow)
			if len(report.Accounts) != 1 || report.Accounts[0].ResetCards == nil {
				t.Fatalf("missing account/facts: %+v", report)
			}
			facts := report.Accounts[0].ResetCards
			if !tc.known && facts.State != rows.ResetCardUnknown {
				t.Fatalf("invalid count accepted: %+v", facts)
			}
			if tc.known && (facts.Count == nil || *facts.Count != tc.count) {
				t.Fatalf("valid count lost: %+v", facts)
			}
		})
	}
}

func TestAccountMergeRequiresVerifiedMatchingBinding(t *testing.T) {
	isolateHome(t)
	for _, tc := range []struct {
		name, ref, status string
		want              int
	}{
		{"matching", "0123456789abcdef", "verified", 1},
		{"different", "fedcba9876543210", "verified", 2},
		{"unverified", "0123456789abcdef", "unverified", 2},
		// An unbound session-log account is not a second source while the live reading is
		// available (owner decision 2026-11-06, G3-20 option B).
		{"missing", "", "", 1},
	} {
		t.Run(tc.name, func(t *testing.T) {
			cache := t.TempDir()
			snap := &accountSnap{SchemaVersion: 1, Status: "ok", ObservedAt: acctNow, SubscriptionRef: "0123456789abcdef"}
			if err := save(cache, snap); err != nil {
				t.Fatal(err)
			}
			a := Account{Source: "codex", ObservedAt: acctNow}
			if tc.ref != "" {
				a.Subscription = &Binding{Ref: tc.ref, Status: tc.status}
			}
			report := Report{Accounts: []Account{a}}
			applyAccount(&report, cache, acctNow)
			if len(report.Accounts) != tc.want {
				t.Fatalf("got %d accounts, want %d", len(report.Accounts), tc.want)
			}
		})
	}
}

func TestOldResetReadingDoesNotBorrowAccountFreshness(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	old, expiry := acctNow.Add(-2*time.Hour), acctNow.Add(time.Hour)
	snap := &accountSnap{SchemaVersion: 1, Status: "ok", ObservedAt: old, SubscriptionRef: "0123456789abcdef", Credits: &accountResetCredits{Count: 1, IdentityObserved: true, IdentityComplete: true, Items: []resetCardIdentity{{ID: strings.Repeat("a", 64), ExpiresAt: &expiry}}}}
	if err := save(cache, snap); err != nil {
		t.Fatal(err)
	}
	report := Report{Accounts: []Account{{Source: "codex", ObservedAt: acctNow, Subscription: &Binding{Ref: snap.SubscriptionRef, Status: "verified"}, Windows: []Window{{Kind: "weekly", ObservedAt: acctNow}}}}}
	applyAccount(&report, cache, acctNow)
	if len(report.Accounts) != 1 {
		t.Fatalf("matching binding failed: %+v", report.Accounts)
	}
	a := report.Accounts[0]
	if a.ResetCards == nil || len(a.ResetCards.Sources) != 1 || !a.ResetCards.Sources[0].ObservedAt.Equal(old) {
		t.Fatalf("lost reader observation: %+v", a.ResetCards)
	}
	until := acctNow.Add(time.Hour)
	ref := snap.SubscriptionRef
	in := rows.Input{Now: acctNow, ConsentGeneration: 1,
		Catalogue: []rows.CatalogueEntry{{ToolID: "codex", Detected: true, ReaderExists: true}},
		Consents:  []rows.ConsentRecord{{ToolID: "codex", Generation: 1, State: rows.ConsentAllowed}},
		Profiles:  []rows.ProfileState{{ToolID: "codex", ProfileKey: "synthetic", LatestAttempt: rows.AttemptResultSucceeded, ObservedAt: &a.ObservedAt, WithinFreshness: true, FreshUntil: &until}},
		Accounts:  []rows.AccountInput{{ToolID: "codex", ProfileKey: "synthetic", Route: rows.RouteRuntimeRPC, SubscriptionRef: &ref, ResetCards: a.ResetCards}},
	}
	p := rows.Build(in)
	if err := rows.Validate(in, p); err != nil {
		t.Fatal(err)
	}
	for _, r := range p.Rows {
		for _, a := range r.Accounts {
			if a.ResetCards != nil && a.ResetCards.State != rows.ResetCardUnknown {
				t.Fatalf("old cards admitted: %+v", a.ResetCards)
			}
		}
	}
}

func TestCodexRuntimeNeverMergesUnverifiedOrDifferentAccount(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	var resp rlResponse
	if err := json.Unmarshal([]byte(acctResponse), &resp); err != nil {
		t.Fatal(err)
	}
	snap := snapFrom(&resp, acctNow)
	snap.SubscriptionRef = "0123456789abcdef"
	if err := save(cache, snap); err != nil {
		t.Fatal(err)
	}
	for _, binding := range []*Binding{nil, {Ref: snap.SubscriptionRef, Status: "unverified"}, {Ref: "fedcba9876543210", Status: "verified"}} {
		r := Report{Accounts: []Account{{Source: "codex", Subscription: binding, ObservedAt: acctNow.Add(-time.Hour), Windows: []Window{{Kind: "weekly", ObservedAt: acctNow.Add(-time.Hour)}}}}}
		applyAccount(&r, cache, acctNow)
		if binding == nil {
			// Owner decision B: an unbound session-log reading is not shown beside the live
			// reading and gives it nothing.
			if len(r.Accounts) != 1 || r.Accounts[0].Via != "codex-account" || len(r.Accounts[0].Windows) != 2 {
				t.Fatalf("live reading with an unbound log: %+v", r.Accounts)
			}
			continue
		}
		if len(r.Accounts) != 2 || r.Accounts[0].Via == "codex-account" || r.Accounts[1].Via != "codex-account" {
			t.Fatalf("unbound readings were combined: %+v", r.Accounts)

		}
	}
}

// A brief hold on the consent lock must not lose a finished reading: the failed save used
// to leave no snapshot and pushed the next read out by the failure wait.
func TestRefreshKeepsTheReadingThroughABriefConsentLock(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	bin, _ := fakeCodex(t, acctResponse)
	state, _ := consent.Current()
	held, done := make(chan struct{}), make(chan error, 1)
	go func() {
		done <- consent.Publish(state.Fence(), func() error { close(held); time.Sleep(700 * time.Millisecond); return nil })
	}()
	<-held
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatalf("a brief consent lock lost the reading: %v", err)
	}
	if s := loadAccount(cache); s == nil || s.Status != "ok" {
		t.Fatalf("snapshot = %+v", s)
	}
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}

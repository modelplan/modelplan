package quota

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
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
	cache := t.TempDir()
	bin, log := fakeCodex(t, acctResponse)
	if !AccountDue(cache, acctNow) {
		t.Fatal("no reading yet: due")
	}
	if err := RefreshCodexAccount(context.Background(), cache, bin, acctNow); err != nil {
		t.Fatal(err)
	}
	calls, _ := os.ReadFile(log)
	if got := strings.Fields(string(calls)); strings.Join(got, ",") != "initialize,initialized,account/rateLimits/read" {
		t.Fatalf("calls = %v", got)
	}
	b, _ := os.ReadFile(accountPath(cache))
	if strings.Contains(string(b), "secret") {
		t.Fatalf("ids cached: %s", b)
	}
	s := loadAccount(cache)
	if s.Status != "ok" || s.Plan != "pro" || len(s.Windows) != 2 || s.Credits.Count != 2 || len(s.Credits.Expiries) != 2 {
		t.Fatalf("snap = %+v", s)
	}
	if AccountDue(cache, acctNow.Add(4*time.Minute)) || !AccountDue(cache, acctNow.Add(5*time.Minute)) {
		t.Fatal("refresh at most every 5 minutes")
	}
}

func TestFailedRefreshWaitsLongerAndOffMeansOff(t *testing.T) {
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
	var resp rlResponse
	if err := json.Unmarshal([]byte(acctResponse), &resp); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	if err := save(cache, snapFrom(&resp, acctNow)); err != nil {
		t.Fatal(err)
	}
	old := acctNow.Add(-2 * time.Hour)
	r := Report{Accounts: []Account{{Source: "codex", Plan: "pro", ObservedAt: old, Harness: &Harness{Model: "gpt-6-astra"},
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

func TestCreditsWithoutDetailsAreCounted(t *testing.T) {
	cards := creditCards(3, nil)
	if len(cards) != 1 || *cards[0].Count != 3 || cards[0].ExpiresAt != nil {
		t.Fatalf("cards = %+v", cards)
	}
}

func ptr(v float64) *float64 { return &v }

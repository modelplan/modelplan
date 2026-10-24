package quota

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestClaudeCodeSubscription(t *testing.T) {
	isolateHome(t)
	home, cache := t.TempDir(), t.TempDir()
	t.Setenv("HOME", home)
	cfg := filepath.Join(home, ".claude.json")
	write := func(account string) {
		t.Helper()
		body := `{"numStartups":3,"projects":{"/home/u/x":{"history":[1,2,3]}},"oauthAccount":{"accountUuid":"` + account + `","organizationUuid":"org-1","emailAddress":"person@example.com","displayName":"Person"},"tips":{}}`
		if err := os.WriteFile(cfg, []byte(body), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	in := StatuslineInput{SessionID: "s"}
	in.Model.ID = "claude-opus-5-5"
	five := 20.0
	in.RateLimits = &struct {
		FiveHour   *ccWindow `json:"five_hour"`
		SevenDay   *ccWindow `json:"seven_day"`
		SpendLimit *ccWindow `json:"spend_limit"`
	}{FiveHour: &ccWindow{UsedPercentage: &five}}
	ref := func(now time.Time) string {
		t.Helper()
		if err := RecordClaudeCode(cache, in, now); err != nil {
			t.Fatal(err)
		}
		as, _ := readClaudeCode(cache, "")
		if s := as[0].Subscription; s != nil {
			if s.Status != "verified" || s.Basis != "claude-config" {
				t.Fatalf("binding = %+v", s)
			}
			return s.Ref
		}
		return ""
	}
	now := time.Now()
	write("acct-1")
	a := ref(now)
	if len(a) != 16 || ref(now.Add(2*time.Minute)) != a {
		t.Fatalf("ref = %q", a)
	}
	for _, p := range []string{snapshotPath(cache), subscriptionsPath(cache)} {
		b, _ := os.ReadFile(p)
		for _, leak := range []string{"acct-1", "org-1", "example.com", "Person", "/home/u"} {
			if strings.Contains(string(b), leak) {
				t.Fatalf("%q in %s", leak, p)
			}
		}
	}
	// Signing in to another account changes the file, and the reference with it.
	time.Sleep(10 * time.Millisecond)
	write("acct-2")
	if b := ref(now.Add(4 * time.Minute)); b == "" || b == a {
		t.Fatalf("another account: %q", b)
	}
	write("acct-1")
	os.Chtimes(cfg, now.Add(time.Hour), now.Add(time.Hour))
	if ref(now.Add(6*time.Minute)) != a {
		t.Fatal("the first account comes back with its reference")
	}
	t.Setenv("MODELPLAN_IDENTITY", "off")
	if ref(now.Add(8*time.Minute)) != "" {
		t.Fatal("off is off")
	}
	t.Setenv("MODELPLAN_IDENTITY", "")
	os.Remove(cfg)
	if ref(now.Add(10*time.Minute)) != "" {
		t.Fatal("signed out: no subscription")
	}
}

func TestSubscriptionsMap(t *testing.T) {
	isolateHome(t)
	cache := t.TempDir()
	now := time.Now()
	a := assignSubscription(cache, "api-key:zai", "key-one", now)
	if a == "" || assignSubscription(cache, "api-key:zai", "key-one", now.Add(2*time.Hour)) != a {
		t.Fatal("stable")
	}
	if b := assignSubscription(cache, "api-key:zai", "key-two", now); b == "" || b == a {
		t.Fatal("another key, another subscription")
	}
	if c := assignSubscription(cache, "api-key:opencodego", "key-one", now); c == a {
		t.Fatal("the same string under another basis is another identity")
	}
	b, _ := os.ReadFile(subscriptionsPath(cache))
	if strings.Contains(string(b), "key-one") {
		t.Fatal("identity stored")
	}
	// An unreadable map is left alone and yields no reference.
	os.WriteFile(subscriptionsPath(cache), []byte("{"), 0o600)
	if assignSubscription(cache, "api-key:zai", "key-one", now) != "" {
		t.Fatal("unreadable map")
	}
	if b, _ := os.ReadFile(subscriptionsPath(cache)); string(b) != "{" {
		t.Fatal("unreadable map overwritten")
	}
}

func TestNativeAndCodexBarSubscriptions(t *testing.T) {
	isolateHome(t)
	_, done := zaiServer(t)
	defer done()
	p := nativePaths(t)
	t.Setenv("Z_AI_API_KEY", "test-key")
	SetConnection(p.ConnectionsFile, QuotaSource{Provider: "zai", Backend: BackendNative, Enabled: true})
	now := time.Now()
	if err := RefreshNative(context.Background(), p, now); err != nil {
		t.Fatal(err)
	}
	var got *Binding
	for _, a := range Read(p, now).Accounts {
		if a.Source == "native:zai" {
			got = a.Subscription
		}
	}
	if got == nil || got.Basis != "api-key" || len(got.Ref) != 16 {
		t.Fatalf("native binding = %+v", got)
	}
	b, _ := os.ReadFile(filepath.Join(testdataDir(t), "codexbar", "zai.json"))
	e := parseCodexBar(b, "zai", "", now)
	if e.identity == "" || e.SubscriptionRef != "" {
		t.Fatalf("codexbar identity = %+v", e)
	}
}

func testdataDir(t *testing.T) string {
	wd, _ := os.Getwd()
	return filepath.Join(wd, "testdata")
}

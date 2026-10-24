package advise

import (
	"os"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/quota"
)

func TestQuotaNoticeStateMergeAndExpiry(t *testing.T) {
	cache := t.TempDir()
	account := claude("medium", 88, time.Hour, 300)
	a, b := Load(cache), Load(cache)
	a.BriefDue("thread", "opus", now)
	if got := a.QuotaNotices("thread", &account, now); len(got) != 1 {
		t.Fatalf("low notices: %v", got)
	}
	if err := a.Save(cache, now); err != nil {
		t.Fatal(err)
	}
	// A status-line writer loaded before the hook cannot discard its state.
	b.Once("status-line", now)
	if err := b.Save(cache, now); err != nil {
		t.Fatal(err)
	}
	s := Load(cache)
	if len(s.Briefs) != 1 || len(s.Quotas) != 1 || len(s.QuotaNotices("thread", &account, now)) != 0 {
		t.Fatalf("merged state: %+v", s)
	}
	// Independent hooks adding different windows merge within the same thread too.
	a, b = Load(cache), Load(cache)
	account.Windows[0].Kind = "weekly"
	a.QuotaNotices("thread", &account, now)
	if err := a.Save(cache, now); err != nil {
		t.Fatal(err)
	}
	account.Source = "codex"
	b.QuotaNotices("thread", &account, now)
	if err := b.Save(cache, now); err != nil {
		t.Fatal(err)
	}
	s = Load(cache)
	if len(s.Quotas["thread"].Windows) != 3 {
		t.Fatalf("lost window marks: %+v", s.Quotas)
	}
	data, err := os.ReadFile(path(cache))
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(data), "remaining") || strings.Contains(string(data), "usedPercent") {
		t.Fatalf("quota value persisted: %s", data)
	}
	// The same cleanup pass removes both brief and quota session marks after eight days.
	later := now.Add(seenFor + time.Minute)
	s.Once("cleanup", later)
	if err := s.Save(cache, later); err != nil {
		t.Fatal(err)
	}
	s = Load(cache)
	if len(s.Briefs) != 0 || len(s.Quotas) != 0 {
		t.Fatalf("expired state: %+v", s)
	}
}

func TestQuotaNoticesIndependentWindowsAndPool(t *testing.T) {
	s := Load(t.TempDir())
	a := claude("medium", 85, time.Hour, 300)
	w := a.Windows[0]
	w.Kind, w.UsedPercent = "weekly", f(85.1)
	a.Windows = append(a.Windows, w)
	quota.Evaluate(&a, now)
	got := s.QuotaNotices("thread", &a, now)
	if len(got) != 1 || got[0].Window != "weekly" || got[0].Remaining != 14.9 {
		t.Fatalf("weekly only: %+v", got)
	}
	a.Windows[0].UsedPercent = f(88)
	quota.Evaluate(&a, now)
	got = s.QuotaNotices("thread", &a, now)
	if len(got) != 1 || got[0].Window != "five_hour" {
		t.Fatalf("five hour only: %+v", got)
	}
	// A low window in a different Codex pool is not the prompting model's quota.
	a.Source, a.Pool = "codex", "reserve"
	a.Windows[0].UsedPercent = f(88)
	a.Windows = append(a.Windows, quota.Window{Kind: "weekly", Limit: "reserve", UsedPercent: f(10), ResetsAt: at(time.Hour), ObservedAt: now})
	quota.Evaluate(&a, now)
	if got := s.QuotaNotices("pool-thread", &a, now); len(got) != 0 {
		t.Fatalf("other pool: %+v", got)
	}
}

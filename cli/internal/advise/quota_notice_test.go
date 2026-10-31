package advise

import (
	"os"
	"strings"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
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
	a := claude("medium", 75, time.Hour, 300)
	w := a.Windows[0]
	w.Kind, w.UsedPercent, w.WindowMinutes = "weekly", f(85.1), 10080
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
	a.Windows = append(a.Windows, quota.Window{Kind: "weekly", Limit: "reserve", UsedPercent: f(10), ResetsAt: at(72 * time.Hour), ObservedAt: now})
	quota.Evaluate(&a, now)
	if got := s.QuotaNotices("pool-thread", &a, now); len(got) != 0 {
		t.Fatalf("other pool: %+v", got)
	}
}

func kinds(ns []QuotaNotice) string {
	var out []string
	for _, n := range ns {
		x := n.Kind + ":" + n.Window
		if n.RunsOutIn != nil {
			x += "+runout"
		}
		out = append(out, x)
	}
	return strings.Join(out, ",")
}

func TestQuotaNoticeThresholdsOncePerCycle(t *testing.T) {
	s := Load(t.TempDir())
	notice := func(used float64, reset time.Duration) string {
		a := claude("medium", used, reset, 300)
		return kinds(s.QuotaNotices("thread", &a, now))
	}
	for _, c := range []struct {
		used float64
		want string
	}{{75, ""}, {80, "low:five_hour"}, {85, ""}, {89.5, ""}, {90, "low:five_hour"}, {95, "low:five_hour"}, {99, ""}, {70, ""}, {96, ""}} {
		if got := notice(c.used, 2*time.Hour); got != c.want {
			t.Fatalf("%g%% used: %q, want %q", c.used, got, c.want)
		}
	}
	// The next cycle starts over; a reading that first shows 4% left gets one line, not three.
	if got := notice(96, 7*time.Hour); got != "low:five_hour" {
		t.Fatalf("new cycle: %q", got)
	}
	if got := notice(97, 7*time.Hour); got != "" {
		t.Fatalf("repeat in new cycle: %q", got)
	}
	// Reset jitter is the same cycle.
	if got := notice(97, 7*time.Hour+time.Minute); got != "" {
		t.Fatalf("jitter started a cycle: %q", got)
	}
	if got := kinds(s.QuotaNotices("other", ptr(claude("medium", 96, 7*time.Hour, 300)), now)); got != "low:five_hour" {
		t.Fatalf("other thread: %q", got)
	}
}

func ptr(a quota.Account) *quota.Account { return &a }

func TestQuotaNoticeRunoutWhateverIsLeft(t *testing.T) {
	s := Load(t.TempDir())
	a := claude("medium", 40, 3*time.Hour, 300)
	a.Windows[0].RunsOutInMinutes = n(50)
	got := s.QuotaNotices("thread", &a, now)
	if kinds(got) != "low:five_hour+runout" || got[0].RateOver != "recent" || *got[0].RunsOutIn != 50 {
		t.Fatalf("run-out at 60%% left: %+v", got)
	}
	if got := s.QuotaNotices("thread", &a, now); len(got) != 0 {
		t.Fatalf("repeat run-out: %+v", got)
	}
	// Reaching a threshold later still sends its line, with the current run-out.
	a = claude("medium", 81, 3*time.Hour, 300)
	a.Windows[0].RunsOutInMinutes = n(20)
	if got := kinds(s.QuotaNotices("thread", &a, now)); got != "low:five_hour+runout" {
		t.Fatalf("threshold after run-out: %q", got)
	}
	// A weekly window ignores the hour's burst: only a full day of readings counts.
	w := claude("medium", 40, 3*24*time.Hour, 10080)
	w.Windows[0].Kind, w.Windows[0].RunsOutInMinutes = "weekly", n(50)
	if got := s.QuotaNotices("weekly-thread", &w, now); len(got) != 0 {
		t.Fatalf("weekly burst run-out: %+v", got)
	}
}

func TestQuotaNoticeSurplusOncePerCycle(t *testing.T) {
	s := Load(t.TempDir())
	a := claude("medium", 40, 30*time.Minute, 300)
	if a.Headroom != "spend" {
		t.Fatalf("fixture headroom %q", a.Headroom)
	}
	if got := kinds(s.QuotaNotices("thread", &a, now)); got != "surplus:five_hour" {
		t.Fatalf("surplus: %q", got)
	}
	if got := s.QuotaNotices("thread", &a, now); len(got) != 0 {
		t.Fatalf("repeat surplus: %+v", got)
	}
	// Not while another window is tight: then the account has nothing to spare.
	b := claude("medium", 40, 30*time.Minute, 300)
	b.Windows = append(b.Windows, quota.Window{Kind: "weekly", UsedPercent: f(95), ResetsAt: at(48 * time.Hour), WindowMinutes: 10080, ResetMode: "fixed", ObservedAt: now.Add(-time.Minute)})
	quota.Evaluate(&b, now)
	if got := kinds(s.QuotaNotices("tight-thread", &b, now)); got != "low:weekly" {
		t.Fatalf("surplus beside a tight window: %q", got)
	}
}

func TestQuotaResendOnlyWhatStillHolds(t *testing.T) {
	s := Load(t.TempDir())
	low := claude("medium", 92, 2*time.Hour, 300)
	if s.QuotaResend("thread", &low, now) != nil {
		t.Fatal("resend before any notice")
	}
	s.QuotaNotices("thread", &low, now)
	if r := s.QuotaResend("thread", &low, now); r == nil || r.Kind != "low" || r.Remaining != 8 {
		t.Fatalf("resend: %+v", r)
	}
	if r := s.QuotaResend("thread", ptr(claude("medium", 95, 2*time.Hour, 300)), now); r == nil || r.Remaining != 5 {
		t.Fatalf("resend shows current figures: %+v", r)
	}
	if r := s.QuotaResend("thread", ptr(claude("medium", 60, 2*time.Hour, 300)), now); r != nil {
		t.Fatalf("corrected reading resent: %+v", r)
	}
	if r := s.QuotaResend("thread", ptr(claude("medium", 92, 7*time.Hour, 300)), now); r != nil {
		t.Fatalf("next cycle resent: %+v", r)
	}
	if r := s.QuotaResend("other", &low, now); r != nil {
		t.Fatalf("another thread: %+v", r)
	}
	// A run-out notice holds while the rate still runs the window out.
	pace := claude("medium", 40, 3*time.Hour, 300)
	pace.Windows[0].RunsOutInMinutes = n(50)
	s.QuotaNotices("pace", &pace, now)
	if r := s.QuotaResend("pace", &pace, now); r == nil || r.RunsOutIn == nil {
		t.Fatalf("run-out resend: %+v", r)
	}
	pace.Windows[0].RunsOutInMinutes = nil
	if r := s.QuotaResend("pace", &pace, now); r != nil {
		t.Fatalf("run-out resent after the rate eased: %+v", r)
	}
}

func TestNoticeStepsOnlyAboveStar(t *testing.T) {
	d := fixtureDigest()
	steps := func(effort, attribution string, d *digest.Digest) (*Step, *Step) {
		a := claude(effort, 92, 2*time.Hour, 300)
		a.Harness.Attribution = attribution
		return NoticeSteps(&a, quota.Report{}, d, now)
	}
	down, cheaper := steps("high", "current-thread", d)
	if down == nil || cheaper != nil || down.Effort != "medium" || !down.Recommended || *down.CostRatio >= 1 {
		t.Fatalf("above ★: %+v %+v", down, cheaper)
	}
	if down, _ := steps("max", "current-thread", d); down == nil || down.Effort != "medium" {
		t.Fatalf("max goes to ★, not one step: %+v", down)
	}
	for _, effort := range []string{"medium", "low"} {
		if down, cheaper := steps(effort, "current-thread", d); down != nil || cheaper != nil {
			t.Fatalf("%s: %+v %+v", effort, down, cheaper)
		}
	}
	if down, _ := steps("high", "recent-thread", d); down != nil {
		t.Fatalf("another thread's effort: %+v", down)
	}
	if down, _ := steps("", "current-thread", d); down != nil {
		t.Fatalf("unknown effort: %+v", down)
	}
	// At ★, a model that scores as well for less is named.
	d.Models[1].Efforts[1].Ability = f(70)
	if down, cheaper := steps("medium", "current-thread", d); down != nil || cheaper == nil || cheaper.Model != "claude-sonnet-5-5" {
		t.Fatalf("cheaper at ★: %+v %+v", down, cheaper)
	}
}

func TestQuotaMarksMergeAcrossWritersAndSchemas(t *testing.T) {
	r := now.Add(2 * time.Hour).UTC()
	later := r.Add(5 * time.Hour)
	for _, c := range []struct {
		name         string
		memory, disk QuotaMark
		want         QuotaMark
	}{
		{"same cycle: lowest level, every flag", QuotaMark{ResetAt: r, Level: 20, Surplus: true}, QuotaMark{ResetAt: r.Add(time.Minute), Level: 10, Pace: true},
			QuotaMark{ResetAt: r, Level: 10, Pace: true, Surplus: true}},
		{"disk holds the later cycle", QuotaMark{ResetAt: r, Level: 5}, QuotaMark{ResetAt: later, WasLow: true}, QuotaMark{ResetAt: later, WasLow: true}},
		{"memory holds the later cycle", QuotaMark{ResetAt: later, Level: 20}, QuotaMark{ResetAt: r, Level: 5}, QuotaMark{ResetAt: later, Level: 20}},
		{"old schema on disk", QuotaMark{}, QuotaMark{LowResetAt: r}, QuotaMark{ResetAt: r, Level: 20}},
		{"old schema, recovered", QuotaMark{ResetAt: r, Pace: true}, QuotaMark{LowResetAt: r, Recovered: true}, QuotaMark{ResetAt: r, Pace: true}},
	} {
		cache := t.TempDir()
		disk := Load(cache)
		disk.Quotas = map[string]QuotaSession{"thread": {At: now, Windows: map[string]QuotaMark{"k": c.disk}}}
		disk.changed = true
		if err := disk.Save(cache, now); err != nil {
			t.Fatal(err)
		}
		memory := &State{SchemaVersion: 1, Seen: map[string]time.Time{}, Quotas: map[string]QuotaSession{"thread": {At: now, Windows: map[string]QuotaMark{"k": c.memory}}}, changed: true}
		if err := memory.Save(cache, now); err != nil {
			t.Fatal(err)
		}
		if got := Load(cache).Quotas["thread"].Windows["k"]; got != c.want {
			t.Errorf("%s: got %+v, want %+v", c.name, got, c.want)
		}
	}
}

func TestQuotaNoticeOldMarkIsNotRepeated(t *testing.T) {
	s := Load(t.TempDir())
	a := claude("medium", 88, 2*time.Hour, 300)
	s.Quotas = map[string]QuotaSession{"thread": {At: now, Windows: map[string]QuotaMark{"claude-code|five_hour|": {LowResetAt: a.Windows[0].ResetsAt.UTC()}}}}
	if got := s.QuotaNotices("thread", &a, now); len(got) != 0 {
		t.Fatalf("the old 15%% line repeated as 20%%: %+v", got)
	}
	a = claude("medium", 91, 2*time.Hour, 300)
	if got := kinds(s.QuotaNotices("thread", &a, now)); got != "low:five_hour" {
		t.Fatalf("10%% after an old mark: %q", got)
	}
}

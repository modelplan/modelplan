package advise

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/lineup"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

var now = time.Date(2026, 10, 14, 10, 0, 0, 0, time.UTC)

func f(v float64) *float64 { return &v }
func n(v int) *int         { return &v }
func at(d time.Duration) *time.Time {
	t := now.Add(d)
	return &t
}

func eff(key, label string, ability, cost float64) digest.Effort {
	return digest.Effort{Effort: key, Label: label, Ability: f(ability), Cost: f(cost), CostBasisID: "ref"}
}

func fixtureDigest() *digest.Digest {
	opus := digest.Model{ID: "claude-opus-5-5", Name: "Claude Opus 5.5", DeveloperID: "anthropic", Recommended: "medium",
		HarnessIDs: map[string][]string{"claude-code": {"claude-opus-5-5", "opus"}},
		Efforts:    []digest.Effort{eff("low", "Low", 60, 1), eff("medium", "Med", 70, 2), eff("high", "High", 74.8, 2.74), eff("xhigh", "XHigh", 78.5, 3.97), eff("max", "Max", 78, 7.6)}}
	sonnet := digest.Model{ID: "claude-sonnet-5-5", Name: "Claude Sonnet 5.5", DeveloperID: "anthropic", Recommended: "high",
		HarnessIDs: map[string][]string{"claude-code": {"claude-sonnet-5-5"}},
		Efforts:    []digest.Effort{eff("medium", "Med", 55, 0.8), eff("high", "High", 62, 1.1)}}
	resets := []json.RawMessage{
		json.RawMessage(`{"id":"r-fresh","provider":"openai","eventType":"direct_reset_reported_complete","status":"upstream-confirmed","publishedAt":"2026-10-14T08:00:00Z","url":"https://x.com/a"}`),
		json.RawMessage(`{"id":"r-old","provider":"openai","eventType":"direct_reset_reported_complete","status":"upstream-confirmed","publishedAt":"2026-10-12T08:00:00Z"}`),
		json.RawMessage(`{"id":"r-withdrawn","provider":"openai","eventType":"direct_reset_announced","status":"withdrawn","publishedAt":"2026-10-14T09:00:00Z"}`),
		json.RawMessage(`{"id":"r-grok","provider":"grok","eventType":"direct_reset_announced","status":"upstream-announced","publishedAt":"2026-10-14T09:00:00Z"}`),
	}
	mw := func(kind string, mult float64, prio int, from, to time.Duration) digest.MultiplierWindow {
		return digest.MultiplierWindow{Provider: "zhipu", Kind: kind, Models: []string{"GLM-5.3"}, PlanIDs: []string{"zhipu-cn-legacy"}, Multiplier: f(mult), Priority: prio,
			StartsAt: now.Add(from).Format(time.RFC3339), EndsAt: now.Add(to).Format(time.RFC3339), Status: "TENTATIVE"}
	}
	return &digest.Digest{
		Models: []digest.Model{opus, sonnet},
		Lineups: []digest.PublishedLineup{{DeveloperID: "anthropic", Lineup: lineup.Lineup{Members: []*lineup.Row{
			{ID: "claude-opus-5-5", Ability: 70, Tags: []string{"strongest"}}, {ID: "claude-sonnet-5-5", Ability: 62, Tags: []string{"best_value"}}}}}},
		Resets: resets,
		Multipliers: []digest.MultiplierWindow{
			mw("base", 1, 0, -2*time.Hour, 20*time.Hour), mw("peak", 3, 10, 30*time.Minute, 4*time.Hour),
		},
		MultiplierHorizon: &digest.MultiplierHorizon{From: now.Add(-time.Hour).Format(time.RFC3339), To: now.Add(47 * time.Hour).Format(time.RFC3339)},
	}
}

func claude(effort string, used float64, resetIn time.Duration, windowMin int) quota.Account {
	a := quota.Account{Source: "claude-code", ObservedAt: now.Add(-time.Minute), Harness: &quota.Harness{Model: "claude-opus-5-5", Effort: effort},
		Windows: []quota.Window{{Kind: "five_hour", UsedPercent: f(used), ResetsAt: at(resetIn), WindowMinutes: windowMin, ResetMode: "fixed", ObservedAt: now.Add(-time.Minute)}}}
	quota.Evaluate(&a, now)
	return a
}

func derive(t *testing.T, s *State, d *digest.Digest, as ...quota.Account) []Event {
	t.Helper()
	return Derive(Input{Report: quota.Report{Accounts: as}, Digest: d, State: s, Now: now})
}

func types(es []Event) []string {
	var out []string
	for _, e := range es {
		out = append(out, e.Type)
	}
	return out
}

func TestSurplusSoonStepsUpAndArmsSwitchBack(t *testing.T) {
	d, s := fixtureDigest(), Load(t.TempDir())
	es := derive(t, s, d, claude("medium", 30, 40*time.Minute, 300))
	if len(es) != 1 || es[0].Type != ResetSoonSurplus {
		t.Fatalf("events = %v", types(es))
	}
	st := es[0].Suggest
	if st.Action != "step_up" || st.Effort != "high" || *st.AbilityDelta != 4.8 || *st.CostRatio != 1.37 {
		t.Fatalf("suggest = %+v", st)
	}
	if len(s.Armed) != 1 || !s.Armed[0].ResetAt.Equal(now.Add(40*time.Minute)) {
		t.Fatalf("armed = %+v", s.Armed)
	}

	// 20 minutes after the reset the user is still on High: suggest ★ Med again.
	after := Derive(Input{Report: quota.Report{Accounts: []quota.Account{claudeAt("high", now.Add(60*time.Minute))}}, Digest: d, State: s, Now: now.Add(60 * time.Minute)})
	if len(after) != 1 || after[0].Type != SwitchBack || after[0].Suggest.Action != "switch_back" || after[0].Suggest.Effort != "medium" || !after[0].Suggest.Recommended {
		t.Fatalf("after reset = %+v", after)
	}
	// Already back on ★: nothing to say.
	if es := Derive(Input{Report: quota.Report{Accounts: []quota.Account{claudeAt("medium", now.Add(60*time.Minute))}}, Digest: d, State: s, Now: now.Add(60 * time.Minute)}); len(es) != 0 {
		t.Fatalf("at ★ after reset = %v", types(es))
	}
	// Long after the reset the armed window is dropped.
	s.prune(now.Add(3 * time.Hour))
	if len(s.Armed) != 0 {
		t.Fatalf("armed not pruned: %+v", s.Armed)
	}
}

// claudeAt is a fresh reading taken at t, right after the five-hour window restarted.
func claudeAt(effort string, t time.Time) quota.Account {
	r := t.Add(280 * time.Minute)
	a := quota.Account{Source: "claude-code", ObservedAt: t, Harness: &quota.Harness{Model: "claude-opus-5-5", Effort: effort},
		Windows: []quota.Window{{Kind: "five_hour", UsedPercent: f(3), ResetsAt: &r, WindowMinutes: 300, ResetMode: "fixed", ObservedAt: t}}}
	quota.Evaluate(&a, t)
	return a
}

func TestSurplusAtTopEffortSuggestsNothingOrStrongerModel(t *testing.T) {
	d := fixtureDigest()
	// XHigh is the best-scoring effort (Max scores lower): nothing above it.
	es := derive(t, nil, d, claude("xhigh", 30, 40*time.Minute, 300))
	if es[0].Suggest.Action != "none" {
		t.Fatalf("xhigh: %+v", es[0].Suggest)
	}
	// On Sonnet's top effort the developer's strongest model is suggested.
	a := claude("high", 30, 40*time.Minute, 300)
	a.Harness.Model = "claude-sonnet-5-5"
	es = derive(t, nil, d, a)
	if st := es[0].Suggest; st.Action != "stronger_model" || st.Model != "claude-opus-5-5" || st.Effort != "medium" || *st.CostRatio != 1.82 {
		t.Fatalf("sonnet: %+v", st)
	}
}

func TestSurplusFarFromResetIsQuiet(t *testing.T) {
	// Far below pace after half the window: headroom spend, but the reset is not soon.
	if es := derive(t, nil, fixtureDigest(), claude("medium", 20, 140*time.Minute, 300)); len(es) != 0 {
		t.Fatalf("events = %v", types(es))
	}
}

func TestTightStepsDown(t *testing.T) {
	d := fixtureDigest()
	es := derive(t, nil, d, claude("high", 92, 2*time.Hour, 300))
	if len(es) != 1 || es[0].Type != WindowTight || es[0].Suggest.Effort != "medium" || *es[0].Suggest.CostRatio != 0.73 {
		t.Fatalf("high: %+v", es)
	}
	es = derive(t, nil, d, claude("medium", 92, 2*time.Hour, 300))
	if es[0].Suggest.Effort != "low" || *es[0].Suggest.AbilityDelta != -10 {
		t.Fatalf("medium: %+v", es[0].Suggest)
	}
}

func TestExhaustedSuggestsCardThenAllowanceBack(t *testing.T) {
	s := Load(t.TempDir())
	a := quota.Account{Source: "user", Plan: "zhipu-cn-pro", ObservedAt: now.Add(-time.Minute),
		Windows: []quota.Window{{Kind: "five_hour", UsedPercent: f(100), ResetsAt: at(time.Hour), ResetMode: "fixed", ObservedAt: now.Add(-time.Minute)}},
		Cards:   []quota.Card{{Kind: "five_hour", Count: n(2), ExpiresAt: at(30 * time.Hour)}}}
	quota.Evaluate(&a, now)
	es := derive(t, s, nil, a)
	if types(es)[0] != WindowExhausted || es[0].Suggest.Action != "use_card" || es[1].Type != CardsExpiring {
		t.Fatalf("events = %+v", es)
	}
	later := now.Add(70 * time.Minute)
	quota.Evaluate(&a, later) // the old reading: pace reset_passed
	es = Derive(Input{Report: quota.Report{Accounts: []quota.Account{a}}, State: s, Now: later})
	if len(es) == 0 || es[0].Type != SwitchBack || es[0].Suggest.Action != "none" {
		t.Fatalf("after reset = %+v", es)
	}
}

func TestRateBoundaryWithinTheHour(t *testing.T) {
	a := quota.Account{Source: "user", Plan: "zhipu-cn-legacy", Windows: []quota.Window{}}
	quota.Evaluate(&a, now)
	es := derive(t, nil, fixtureDigest(), a)
	if len(es) != 1 || es[0].Type != PeakStartsSoon || *es[0].Rate.From != 1 || *es[0].Rate.To != 3 || *es[0].InMinutes != 30 || es[0].Rate.Status != "TENTATIVE" {
		t.Fatalf("events = %+v", es)
	}
	// Inside the peak, its end is an off-peak boundary.
	es = Derive(Input{Report: quota.Report{Accounts: []quota.Account{a}}, Digest: fixtureDigest(), Now: now.Add(4*time.Hour - 20*time.Minute)})
	if len(es) != 1 || es[0].Type != OffpeakStartsSoon || *es[0].Rate.To != 1 {
		t.Fatalf("in peak = %+v", es)
	}
	// Another plan sees nothing.
	b := quota.Account{Source: "user", Plan: "zhipu-cn-pro", Windows: []quota.Window{}}
	if es := derive(t, nil, fixtureDigest(), b); len(es) != 0 {
		t.Fatalf("other plan = %v", types(es))
	}
}

func TestConflictingTopPriorityRateIsUnknown(t *testing.T) {
	d := fixtureDigest()
	extra := d.Multipliers[1]
	extra.Multiplier = f(2)
	d.Multipliers = append(d.Multipliers, extra)
	r, status := rateAt(d.Multipliers, "zhipu-cn-legacy", "GLM-5.3", now.Add(time.Hour))
	if r != nil || status != "unknown" {
		t.Fatalf("rate = %v %s", r, status)
	}
}

func TestPublicResetOnlyFreshAndForCodexUsers(t *testing.T) {
	d := fixtureDigest()
	codex := quota.Account{Source: "codex", ObservedAt: now.Add(-time.Minute), Windows: []quota.Window{}}
	quota.Evaluate(&codex, now)
	es := derive(t, nil, d, codex)
	if len(es) != 1 || es[0].Type != PublicReset || es[0].Public.ID != "r-fresh" || es[0].Source != "codex" {
		t.Fatalf("codex = %+v", es)
	}
	if es := derive(t, nil, d, claude("medium", 20, 3*time.Hour, 300)); len(es) != 0 {
		t.Fatalf("claude only = %v", types(es))
	}
}

func TestOldHarnessReadingIsQuiet(t *testing.T) {
	a := claude("medium", 100, 40*time.Minute, 300)
	a.ObservedAt = now.Add(-7 * time.Hour)
	if es := derive(t, nil, fixtureDigest(), a); len(es) != 0 {
		t.Fatalf("events = %v", types(es))
	}
}

func TestStateSeenAndMerge(t *testing.T) {
	dir := t.TempDir()
	es := derive(t, nil, fixtureDigest(), claude("high", 92, 2*time.Hour, 300))
	a := Load(dir)
	if len(a.Unseen(es)) != 1 {
		t.Fatal("fresh state should see the event as new")
	}
	a.MarkSeen(es, now)
	// Another process armed a window meanwhile; saving must keep both.
	b := Load(dir)
	b.arm([]Event{{Type: WindowTight, Key: "other", Source: "codex", Window: "weekly", At: at(time.Hour)}})
	if err := b.Save(dir, now); err != nil {
		t.Fatal(err)
	}
	if err := a.Save(dir, now); err != nil {
		t.Fatal(err)
	}
	c := Load(dir)
	if len(c.Unseen(es)) != 0 || len(c.Armed) != 1 || c.Armed[0].Key != "other" {
		t.Fatalf("merged = %+v", c)
	}
}

func TestFiveHourSurplusWhileWeekDecidesSpend(t *testing.T) {
	a := claude("medium", 35, 40*time.Minute, 300)
	a.Windows = append(a.Windows, quota.Window{Kind: "weekly", UsedPercent: f(30), ResetsAt: at(72 * time.Hour), WindowMinutes: 10080, ResetMode: "fixed", ObservedAt: now})
	quota.Evaluate(&a, now)
	if a.Headroom != "spend" || a.Deciding != "weekly" {
		t.Fatalf("headroom %s/%s", a.Headroom, a.Deciding)
	}
	es := derive(t, nil, fixtureDigest(), a)
	if len(es) != 1 || es[0].Type != ResetSoonSurplus || es[0].Window != "five_hour" {
		t.Fatalf("events = %+v", es)
	}
}

func TestCodexSurplusMentionsFastClaudeNever(t *testing.T) {
	d := fixtureDigest()
	astra := digest.Model{ID: "astra", Name: "GPT-6 Astra", DeveloperID: "openai", Recommended: "medium",
		HarnessIDs: map[string][]string{"codex": {"gpt-6-astra"}},
		Efforts:    []digest.Effort{eff("medium", "Med", 51, 3.4), eff("high", "High", 54, 4.1)}}
	d.Models = append(d.Models, astra)
	id, opus := "astra", "opus-id"
	d.Models[0].ID = opus
	tier := func(id, harness, billsTo string, model *string) digest.SpeedTier {
		t := digest.SpeedTier{ID: id, Harness: harness, Tier: "fast", Label: "Fast",
			Billing: []digest.SpeedBilling{{Account: "subscription", BillsTo: billsTo, Ratio: 2.5}}}
		m := digest.SpeedTierModel{ModelID: model}
		m.Speed.Qualifier = "unstated"
		t.Models = []digest.SpeedTierModel{m}
		return t
	}
	d.Speed = []digest.SpeedTier{tier("codex-fast", "codex", "plan-quota", &id), tier("claude-code-fast", "claude-code", "usage-credits", &opus)}
	codex := quota.Account{Source: "codex", ObservedAt: now.Add(-time.Minute), Harness: &quota.Harness{Model: "gpt-6-astra", Effort: "medium"},
		Windows: []quota.Window{{Kind: "five_hour", UsedPercent: f(20), ResetsAt: at(50 * time.Minute), WindowMinutes: 300, ResetMode: "fixed", ObservedAt: now}}}
	quota.Evaluate(&codex, now)
	es := derive(t, nil, d, codex)
	if len(es) == 0 || es[0].Speed == nil || es[0].Speed.QuotaRatio != 2.5 || es[0].Suggest.Effort != "high" {
		t.Fatalf("codex = %+v", es)
	}
	es = derive(t, nil, d, claude("medium", 30, 40*time.Minute, 300))
	if len(es) != 1 || es[0].Speed != nil {
		t.Fatalf("claude = %+v", es[0])
	}
}

func TestSwitchBackOncePerWindow(t *testing.T) {
	s := Load(t.TempDir())
	r1, r2 := now.Add(-30*time.Minute), now.Add(-10*time.Minute)
	s.arm([]Event{
		{Type: ResetSoonSurplus, Key: "a", Source: "claude-code", Window: "five_hour", At: &r1},
		{Type: WindowTight, Key: "b", Source: "claude-code", Window: "five_hour", At: &r2},
		{Type: ResetSoonSurplus, Key: "c", Source: "claude-code", Window: "five_hour", At: &r2},
	})
	es := s.switchBack(quota.Report{Accounts: []quota.Account{claudeAt("high", now)}}, fixtureDigest(), now)
	if len(es) != 1 || !es[0].At.Equal(r2) || es[0].Suggest.Effort != "medium" {
		t.Fatalf("events = %+v", es)
	}
}

func TestAnnouncedResetSpendsAheadAndSwitchesBackOnlyOnProof(t *testing.T) {
	ann := func(id, status string, through time.Duration) json.RawMessage {
		return json.RawMessage(`{"id":"` + id + `","provider":"openai","eventType":"direct_reset_announced","status":"` + status +
			`","publishedAt":"` + now.Add(-time.Hour).Format(time.RFC3339) + `","url":"https://x.com/r","schedule":{"precision":"deadline","from":"` +
			now.Add(through).Format(time.RFC3339) + `","through":"` + now.Add(through).Format(time.RFC3339) + `","label":"before 16:00"}}`)
	}
	withResets := func(rs ...json.RawMessage) *digest.Digest {
		d := fixtureDigest()
		d.Models = append(d.Models, digest.Model{ID: "astra", Name: "GPT-6 Astra", DeveloperID: "openai", Recommended: "medium",
			HarnessIDs: map[string][]string{"codex": {"gpt-6-astra"}},
			Efforts:    []digest.Effort{eff("medium", "Med", 51, 3.4), eff("high", "High", 54, 4.1)}})
		d.Resets = rs
		return d
	}
	weekReset := now.Add(6 * 24 * time.Hour)
	codex := func(effort string, observed time.Time, weekUsed float64, weekResets time.Time) quota.Account {
		a := quota.Account{Source: "codex", ObservedAt: observed, Harness: &quota.Harness{Model: "gpt-6-astra", Effort: effort},
			Windows: []quota.Window{
				{Kind: "five_hour", UsedPercent: f(10), ResetsAt: at(3 * time.Hour), WindowMinutes: 300, ResetMode: "fixed", ObservedAt: observed},
				{Kind: "weekly", UsedPercent: f(weekUsed), ResetsAt: &weekResets, WindowMinutes: 10080, ResetMode: "fixed", ObservedAt: observed}}}
		quota.Evaluate(&a, observed)
		return a
	}
	d, s := withResets(ann("r-ann", "upstream-announced", 6*time.Hour)), Load(t.TempDir())
	es := derive(t, s, d, codex("medium", now.Add(-time.Minute), 48, weekReset))
	if len(es) != 1 || es[0].Type != AnnouncedSurplus || es[0].Window != "weekly" || *es[0].RemainingPercent != 52 ||
		es[0].Suggest.Effort != "high" || es[0].Public.ID != "r-ann" || es[0].Public.When != "before 16:00" || *es[0].InMinutes != 360 {
		t.Fatalf("events = %+v", es)
	}
	if len(s.Armed) != 1 || !s.Armed[0].ResetAt.Equal(now.Add(6*time.Hour)) || !s.Armed[0].WindowResetAt.Equal(weekReset) {
		t.Fatalf("armed = %+v", s.Armed)
	}

	// After the announced time the week still shows its old reset: not proof, say nothing.
	later := now.Add(7 * time.Hour)
	same := Derive(Input{Report: quota.Report{Accounts: []quota.Account{codex("high", later, 70, weekReset)}}, Digest: d, State: s, Now: later})
	if len(same) != 0 {
		t.Fatalf("unproven reset = %v", types(same))
	}
	// A reading after it with a restarted week: the reset reached this account, back to ★.
	fresh := Derive(Input{Report: quota.Report{Accounts: []quota.Account{codex("high", later, 0, later.Add(7*24*time.Hour))}}, Digest: d, State: s, Now: later})
	if len(fresh) != 1 || fresh[0].Type != SwitchBack || fresh[0].Suggest.Effort != "medium" || !fresh[0].Suggest.Recommended {
		t.Fatalf("after proven reset = %+v", fresh)
	}

	for name, c := range map[string]struct {
		d *digest.Digest
		a quota.Account
	}{
		"little left":           {d, codex("medium", now.Add(-time.Minute), 85, weekReset)},
		"week resets first":     {d, codex("medium", now.Add(-time.Minute), 48, now.Add(5*time.Hour))},
		"beyond a day":          {withResets(ann("r-far", "upstream-announced", 30*time.Hour)), codex("medium", now.Add(-time.Minute), 48, weekReset)},
		"withdrawn":             {withResets(ann("r-w", "withdrawn", 6*time.Hour)), codex("medium", now.Add(-time.Minute), 48, weekReset)},
		"announced time passed": {withResets(ann("r-past", "upstream-announced", -time.Hour)), codex("medium", now.Add(-time.Minute), 48, weekReset)},
	} {
		for _, e := range derive(t, nil, c.d, c.a) {
			if e.Type == AnnouncedSurplus {
				t.Errorf("%s: %+v", name, e)
			}
		}
	}
	// The same announcement for a Claude Code user is not theirs.
	if es := derive(t, nil, d, claude("medium", 20, 3*time.Hour, 300)); len(es) != 0 {
		t.Fatalf("claude = %v", types(es))
	}
}

func TestCodexFullResetCreditsCountForEveryWindow(t *testing.T) {
	one, exp := 1, now.Add(30*time.Hour)
	codex := quota.Account{Source: "codex", Plan: "pro", ObservedAt: now.Add(-time.Minute),
		Windows: []quota.Window{{Kind: "weekly", UsedPercent: f(100), ResetsAt: at(50 * time.Hour), WindowMinutes: 10080, ResetMode: "fixed", ObservedAt: now}},
		Cards:   []quota.Card{{Kind: "full", Count: &one, ExpiresAt: &exp}}}
	quota.Evaluate(&codex, now)
	es := derive(t, nil, &digest.Digest{}, codex)
	if len(es) != 2 || es[0].Type != WindowExhausted || es[0].Suggest.Action != "use_card" || es[1].Type != CardsExpiring || es[1].Window != "full" {
		t.Fatalf("events = %+v", es)
	}
}

func TestTaskStartBriefListsOptionsAndTheCurrentLadder(t *testing.T) {
	b := TaskStart(func() *quota.Account { a := claude("high", 30, 3*time.Hour, 300); return &a }(), fixtureDigest(), now)
	if b == nil || b.Model != "Claude Opus 5.5" || b.Effort != "High" || b.AtRec || len(b.Models) != 2 || b.Models[0].Name != "Claude Opus 5.5" {
		t.Fatalf("brief = %+v", b)
	}
	var med *BriefStep
	for i := range b.Ladder {
		if b.Ladder[i].Label == "Med" {
			med = &b.Ladder[i]
		}
	}
	if med == nil || !med.Recommended || *med.AbilityDelta != -4.8 || *med.CostRatio != 0.73 {
		t.Fatalf("ladder = %+v", b.Ladder)
	}
	if TaskStart(&quota.Account{Source: "user"}, fixtureDigest(), now) != nil {
		t.Fatal("no brief for a manual plan")
	}
	s := Load(t.TempDir())
	if !s.Once("task_start|t1", now) || s.Once("task_start|t1", now) {
		t.Fatal("once per thread")
	}
}

func TestDefaultIsBestValueUnlessItIsMuchWeaker(t *testing.T) {
	d := fixtureDigest()
	sonnet := func() *quota.Account {
		a := claude("high", 30, 3*time.Hour, 300)
		a.Harness.Model = "claude-sonnet-5-5"
		return &a
	}
	// Sonnet (best value) scores 8 below Opus (strongest): the default is Opus ★Med.
	b := TaskStart(sonnet(), d, now)
	if b.Default == nil || b.Default.Name != "Claude Opus 5.5" || b.DefaultReason != "strongest" || b.AtDefault || len(b.DefaultLadder) != 5 {
		t.Fatalf("default = %+v / %s", b.Default, b.DefaultReason)
	}
	// Within 3 points, the best value wins.
	d.Lineups[0].Members[1].Ability = 68
	b = TaskStart(sonnet(), d, now)
	if b.Default.Name != "Claude Sonnet 5.5" || b.DefaultReason != "best_value" || !b.AtDefault || b.DefaultLadder != nil {
		t.Fatalf("default = %+v / %s at=%v", b.Default, b.DefaultReason, b.AtDefault)
	}
}

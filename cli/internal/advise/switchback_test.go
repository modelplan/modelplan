package advise

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// after: Derive at t with a reading taken then, on a restarted five-hour window.
func after(s *State, d *digest.Digest, t time.Time, as ...quota.Account) []Event {
	return Derive(Input{Report: quota.Report{Accounts: as}, Digest: d, State: s, Now: t})
}

func TestSwitchBackReturnsToTheConfigurationInUseWhenAdvised(t *testing.T) {
	d := fixtureDigest()
	later := now.Add(60 * time.Minute)

	// On High (above ★) with a surplus: step up to XHigh. After the reset: High again, not ★.
	s := Load(t.TempDir())
	derive(t, s, d, claude("high", 30, 40*time.Minute, 300))
	es := after(s, d, later, claudeAt("xhigh", later))
	if len(es) != 1 || es[0].Suggest.Effort != "high" || es[0].Suggest.Recommended || *es[0].Suggest.CostRatio != 0.69 {
		t.Fatalf("back from xhigh = %+v", es)
	}

	// Tight on High and the user stayed: nothing to undo after the reset (no nag towards ★).
	s = Load(t.TempDir())
	derive(t, s, d, claude("high", 92, 40*time.Minute, 300))
	if es := after(s, d, later, claudeAt("high", later)); len(es) != 0 {
		t.Fatalf("advice not followed = %v", types(es))
	}
	// Tight on High and the user stepped down to Low: back to High.
	if es := after(s, d, later, claudeAt("low", later)); len(es) != 1 || es[0].Suggest.Effort != "high" || *es[0].Suggest.CostRatio != 2.74 {
		t.Fatalf("back from low = %+v", es)
	}

	// A second hint on the same window cycle (surplus at Med, then tight on XHigh) keeps Med.
	s = Load(t.TempDir())
	derive(t, s, d, claude("medium", 30, 40*time.Minute, 300))
	derive(t, s, d, claude("xhigh", 95, 40*time.Minute, 300))
	es = after(s, d, later, claudeAt("xhigh", later))
	if len(es) != 1 || es[0].Suggest.Effort != "medium" || !es[0].Suggest.Recommended {
		t.Fatalf("earliest configuration = %+v", es)
	}
}

func TestSwitchBackWaitsForTheNextPromptAndLeavesTheStatusLineSoon(t *testing.T) {
	d, s := fixtureDigest(), Load(t.TempDir())
	derive(t, s, d, claude("medium", 30, 40*time.Minute, 300))
	// Back the next morning, still on XHigh: the hint is still due.
	morning := now.Add(14 * time.Hour)
	es := after(s, d, morning, claudeAt("xhigh", morning))
	if len(es) != 1 || es[0].Type != SwitchBack || !es[0].InStatusLine(morning) {
		t.Fatalf("next morning = %+v", es)
	}
	// The status line drops it 90 minutes after it first showed; the hook said it once anyway.
	es = after(s, d, morning.Add(2*time.Hour), claudeAt("xhigh", morning.Add(2*time.Hour)))
	if len(es) != 1 || es[0].InStatusLine(morning.Add(2*time.Hour)) {
		t.Fatalf("two hours on = %+v", es)
	}
	if es := after(s, d, now.Add(25*time.Hour), claudeAt("xhigh", now.Add(25*time.Hour))); len(es) != 0 {
		t.Fatalf("a day on = %v", types(es))
	}
}

func codexFixture() *digest.Digest {
	d := fixtureDigest()
	astra := digest.Model{ID: "astra", Name: "GPT-6 Astra", DeveloperID: "openai", Recommended: "medium",
		HarnessIDs: map[string][]string{"codex": {"gpt-6-astra"}},
		Efforts:    []digest.Effort{eff("medium", "Med", 51, 3.4), eff("high", "High", 54, 4.1)}}
	d.Models = append(d.Models, astra)
	id := "astra"
	tier := digest.SpeedTier{ID: "codex-fast", Harness: "codex", Tier: "fast", Label: "Fast",
		Billing: []digest.SpeedBilling{{Account: "subscription", BillsTo: "plan-quota", Ratio: 2.5}}}
	m := digest.SpeedTierModel{ModelID: &id}
	m.Speed.Qualifier = "unstated"
	tier.Models = []digest.SpeedTierModel{m}
	d.Speed = []digest.SpeedTier{tier}
	d.Resets = nil // public reset news is another test's
	return d
}

func codexAt(effort, tier string, used float64, resetAt time.Time, t time.Time) quota.Account {
	a := quota.Account{Source: "codex", ObservedAt: t, Harness: &quota.Harness{Model: "gpt-6-astra", Effort: effort, ServiceTier: tier},
		Windows: []quota.Window{{Kind: "five_hour", UsedPercent: f(used), ResetsAt: &resetAt, WindowMinutes: 300, ResetMode: "fixed", ObservedAt: t}}}
	quota.Evaluate(&a, t)
	return a
}

func TestCodexFastGoesOffAfterTheResetAndFirstWhenTight(t *testing.T) {
	d, s := codexFixture(), Load(t.TempDir())
	reset := now.Add(50 * time.Minute)
	es := derive(t, s, d, codexAt("medium", "", 20, reset, now))
	if len(es) != 1 || es[0].Speed == nil || es[0].Fast != nil {
		t.Fatalf("surplus = %+v", es)
	}
	// The user turned Fast on for the surplus; with Fast on there is no "or turn on Fast".
	if es := derive(t, nil, d, codexAt("medium", "fast", 25, reset, now)); es[0].Speed != nil || es[0].Fast == nil {
		t.Fatalf("surplus with fast = %+v", es[0])
	}
	later := now.Add(70 * time.Minute)
	es = after(s, d, later, codexAt("medium", "fast", 2, later.Add(280*time.Minute), later))
	if len(es) != 1 || !es[0].FastOff || es[0].Suggest.Action != "none" || es[0].Fast.QuotaRatio != 2.5 {
		t.Fatalf("fast after reset = %+v", es)
	}
	// Stepped up as well: back to Med and Fast off in one hint.
	es = after(s, d, later, codexAt("high", "fast", 2, later.Add(280*time.Minute), later))
	if len(es) != 1 || !es[0].FastOff || es[0].Suggest.Effort != "medium" {
		t.Fatalf("high and fast after reset = %+v", es)
	}
	// Fast was already on when advised: leaving it on is the user's earlier choice.
	s = Load(t.TempDir())
	derive(t, s, d, codexAt("medium", "fast", 20, reset, now))
	if es := after(s, d, later, codexAt("medium", "fast", 2, later.Add(280*time.Minute), later)); len(es) != 0 {
		t.Fatalf("fast from before = %+v", es)
	}

	// Tight with Fast on: the event carries it, so turning Fast off is said first.
	es = derive(t, nil, d, codexAt("high", "fast", 93, reset, now))
	if len(es) != 1 || es[0].Type != WindowTight || es[0].Fast == nil || es[0].Suggest.Effort != "medium" {
		t.Fatalf("tight with fast = %+v", es)
	}
}

func TestArmedConfigurationSurvivesSaveAndLoad(t *testing.T) {
	dir, d := t.TempDir(), codexFixture()
	s := Load(dir)
	derive(t, s, d, codexAt("medium", "", 20, now.Add(50*time.Minute), now))
	if err := s.Save(dir, now); err != nil {
		t.Fatal(err)
	}
	later := now.Add(70 * time.Minute)
	s = Load(dir)
	es := after(s, d, later, codexAt("high", "fast", 2, later.Add(280*time.Minute), later))
	if len(es) != 1 || !es[0].FastOff || es[0].Suggest.Effort != "medium" {
		t.Fatalf("after reload = %+v", es)
	}
	if err := s.Save(dir, later); err != nil {
		t.Fatal(err)
	}
	if a := Load(dir).Armed; len(a) != 1 || a[0].From == nil || a[0].From.Effort != "medium" || a[0].From.Fast || a[0].Noted == nil || !a[0].Noted.Equal(later) {
		t.Fatalf("armed on disk = %+v", a)
	}
}

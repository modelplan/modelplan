package advise

import (
	"testing"
	"time"

	"github.com/modelplan/modelplan/cli/internal/digest"
	"github.com/modelplan/modelplan/cli/internal/lineup"
	"github.com/modelplan/modelplan/cli/internal/quota"
)

// The published October 2026 figures: Fable 5.1 is beaten by Opus 5.5 at ★, GPT-6 Astra is
// equivalent to GPT-6.1 Sol for more.
func betterDigest() *digest.Digest {
	cc := func(ids ...string) map[string][]string { return map[string][]string{"claude-code": ids} }
	cx := func(ids ...string) map[string][]string { return map[string][]string{"codex": ids} }
	return &digest.Digest{
		Models: []digest.Model{
			{ID: "fable", Name: "Claude Fable 5.1", DeveloperID: "anthropic", Recommended: "medium", HarnessIDs: cc("claude-fable-5-1"),
				Efforts: []digest.Effort{eff("low", "Low", 48.9, 4.71), eff("medium", "Med", 52.9, 5.61), eff("high", "High", 56.8, 7.77), eff("xhigh", "XHigh", 60.1, 10.66), eff("max", "Max", 60.8, 13.34)}},
			{ID: "opus", Name: "Claude Opus 5.5", DeveloperID: "anthropic", Recommended: "medium", HarnessIDs: cc("claude-opus-5-5"),
				Efforts: []digest.Effort{eff("low", "Low", 38.8, 1.23), eff("medium", "Med", 55.4, 2.91), eff("high", "High", 60.2, 3.98), eff("xhigh", "XHigh", 64.0, 5.78), eff("max", "Max", 67.5, 11.1)}},
			{ID: "astra", Name: "GPT-6 Astra", DeveloperID: "openai", Recommended: "medium", HarnessIDs: cx("gpt-6-astra"),
				Efforts: []digest.Effort{eff("low", "Low", 45.0, 2.21), eff("medium", "Med", 51.4, 3.40), eff("high", "High", 53.9, 3.97), eff("xhigh", "XHigh", 56.5, 4.75), eff("max", "Max", 57.0, 7.03)}},
			{ID: "sol-6.1", Name: "GPT-6.1 Sol", DeveloperID: "openai", Recommended: "medium", HarnessIDs: cx("gpt-6.1-sol"),
				Efforts: []digest.Effort{eff("low", "Low", 42.4, 0.41), eff("medium", "Med", 51.2, 0.61), eff("high", "High", 53.8, 0.85), eff("xhigh", "XHigh", 56.1, 1.01), eff("max", "Max", 55.5, 1.44)}},
		},
		Lineups: []digest.PublishedLineup{
			{DeveloperID: "anthropic", Lineup: lineup.Lineup{Tie: 1, Members: []*lineup.Row{
				{ID: "opus", Tags: []string{"strongest", "best_value"}}, {ID: "fable", Tags: []string{"dominated"}, DominatedBy: &lineup.Dominance{ID: "opus", Kind: "weaker"}}}}},
			{DeveloperID: "openai", Lineup: lineup.Lineup{Tie: 1, Members: []*lineup.Row{
				{ID: "sol-6.1", Tags: []string{"strongest", "best_value"}}, {ID: "astra", Tags: []string{"equivalent_costlier"}, DominatedBy: &lineup.Dominance{ID: "sol-6.1", Kind: "equivalent"}}}}},
		},
	}
}

func onModel(source, model, effort string) quota.Account {
	return onModelAt(source, model, effort, now)
}

func onModelAt(source, model, effort string, t time.Time) quota.Account {
	resets := t.Add(5 * 24 * time.Hour)
	a := quota.Account{Source: source, ObservedAt: t.Add(-time.Minute), Harness: &quota.Harness{Model: model, Effort: effort},
		Windows: []quota.Window{{Kind: "weekly", UsedPercent: f(20), ResetsAt: &resets, WindowMinutes: 10080, ResetMode: "fixed", ObservedAt: t.Add(-time.Minute)}}}
	quota.Evaluate(&a, t)
	return a
}

func better(es []Event) *Event {
	for i := range es {
		if es[i].Type == BetterModel {
			return &es[i]
		}
	}
	return nil
}

func TestBeatenModelsNameTheBetterOne(t *testing.T) {
	d := betterDigest()
	for _, c := range []struct {
		source, model, effort string
		to, label, kind       string
		delta, ratio          float64
	}{
		{"claude-code", "claude-fable-5-1", "medium", "opus", "Med", "stronger", 2.5, 0.52},
		{"claude-code", "claude-fable-5-1", "", "opus", "Med", "stronger", 2.5, 0.52}, // the default effort is ★
		{"claude-code", "claude-fable-5-1", "xhigh", "opus", "High", "equivalent", 0.1, 0.37},
		{"claude-code", "claude-fable-5-1", "max", "opus", "High", "equivalent", -0.6, 0.3}, // the cheapest within a tie
		{"codex", "gpt-6-astra", "medium", "sol-6.1", "Med", "equivalent", -0.2, 0.18},
		{"codex", "gpt-6-astra", "max", "sol-6.1", "XHigh", "equivalent", -0.9, 0.14},
	} {
		e := better(derive(t, nil, d, onModel(c.source, c.model, c.effort)))
		if e == nil {
			t.Fatalf("%s %s: no better model", c.model, c.effort)
		}
		s := e.Suggest
		if s.Model != c.to || s.Label != c.label || s.Kind != c.kind || *s.AbilityDelta != c.delta || *s.CostRatio != c.ratio || e.Current == nil || e.Current.Model == c.to || e.Severity != "info" {
			t.Errorf("%s %s: %+v (Δ%v ×%v) from %+v", c.model, c.effort, s, *s.AbilityDelta, *s.CostRatio, e.Current)
		}
	}
	for _, c := range []struct{ name, source, model, effort string }{
		{"a model nothing beats", "claude-code", "claude-opus-5-5", "medium"},
		{"the better model is not in this harness", "codex", "claude-fable-5-1", "medium"},
	} {
		if e := better(derive(t, nil, d, onModel(c.source, c.model, c.effort))); e != nil {
			t.Errorf("%s: %+v", c.name, e.Suggest)
		}
	}
	// Saving too little is not worth a hint.
	d.Models[1].Efforts[1].Cost = f(5.0) // Opus Med at 0.89× Fable Med
	d.Models[1].Efforts[2].Cost = f(5.5)
	d.Models[1].Efforts[3].Cost = f(5.6)
	if e := better(derive(t, nil, d, onModel("claude-code", "claude-fable-5-1", "medium"))); e != nil {
		t.Errorf("a small saving: %+v", e.Suggest)
	}
}

func TestBetterModelIsToldOnceAndShownForAWeek(t *testing.T) {
	d := betterDigest()
	cache := t.TempDir()
	s := Load(cache)
	es := derive(t, s, d, onModel("claude-code", "claude-fable-5-1", "medium"))
	e := better(es)
	if e == nil || !e.InStatusLine(now) || len(s.Unseen([]Event{*e})) != 1 {
		t.Fatalf("first time: %+v", e)
	}
	s.MarkSeen([]Event{*e}, now)
	if err := s.Save(cache, now); err != nil {
		t.Fatal(err)
	}
	for _, c := range []struct {
		after          time.Duration
		status, unseen bool
	}{
		{6 * 24 * time.Hour, true, false},
		{8 * 24 * time.Hour, false, false},  // still remembered after the usual 8 days
		{89 * 24 * time.Hour, false, false}, // a user still on Fable chose it
		{91 * 24 * time.Hour, true, true},   // three months on, said again
	} {
		later := now.Add(c.after)
		s := Load(cache)
		s.prune(later)
		es := Derive(Input{Report: quota.Report{Accounts: []quota.Account{onModelAt("claude-code", "claude-fable-5-1", "medium", later)}}, Digest: d, State: s, Now: later})
		e := better(es)
		if e == nil || e.InStatusLine(later) != c.status || (len(s.Unseen([]Event{*e})) == 1) != c.unseen {
			t.Errorf("after %v: status %v unseen %v", c.after, e.InStatusLine(later), len(s.Unseen([]Event{*e})))
		}
	}
	// The status line alone also stops after a week, from when it first showed it.
	cache2 := t.TempDir()
	s2 := Load(cache2)
	e2 := better(derive(t, s2, d, onModel("codex", "gpt-6-astra", "medium")))
	s2.NoteShown(*e2, now)
	s2.Save(cache2, now)
	s3 := Load(cache2)
	later := now.Add(8 * 24 * time.Hour)
	e3 := better(Derive(Input{Report: quota.Report{Accounts: []quota.Account{onModelAt("codex", "gpt-6-astra", "medium", later)}}, Digest: d, State: s3, Now: later}))
	if e3.InStatusLine(later) || len(s3.Unseen([]Event{*e3})) != 1 {
		t.Errorf("status line only: shown %v, the hook still tells it once %v", e3.InStatusLine(later), len(s3.Unseen([]Event{*e3})))
	}
}

func TestTightOnABeatenModelOffersTheBetterOneFirst(t *testing.T) {
	d := betterDigest()
	a := onModel("codex", "gpt-6-astra", "medium")
	a.Windows[0].UsedPercent = f(90)
	quota.Evaluate(&a, now)
	es := derive(t, nil, d, a)
	if len(es) < 2 || es[0].Type != WindowTight || es[1].Type != BetterModel {
		t.Fatalf("events = %v", types(es))
	}
	if alt := es[0].Alternative; alt == nil || alt.Model != "sol-6.1" || alt.Label != "Med" || alt.Kind != "equivalent" {
		t.Fatalf("alternative = %+v", es[0].Alternative)
	}
}

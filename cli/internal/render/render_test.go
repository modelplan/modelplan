package render

import (
	"strings"
	"testing"

	"github.com/modelplan/modelplan/cli/internal/digest"
)

func TestStatuslineReviewedIdentityAndLocalizedUnknown(t *testing.T) {
	d := &digest.Digest{Models: []digest.Model{
		{ID: "fable", Name: "Claude Fable 5.1", DeveloperID: "anthropic", Recommended: "medium", HarnessIDs: map[string][]string{"claude-code": {"claude-fable-5-1"}}, Efforts: []digest.Effort{{Effort: "medium", Label: "Med"}}},
		{ID: "astra", Name: "GPT-6 Astra", DeveloperID: "openai", Recommended: "medium", HarnessIDs: map[string][]string{"codex": {"gpt-6-astra"}}, Efforts: []digest.Effort{{Effort: "medium", Label: "Med"}}},
	}}
	for _, lang := range []struct {
		name    string
		text    Text
		unknown string
	}{{"zh", ZH, "未核对型号"}, {"en", EN, "id not reviewed"}} {
		t.Run(lang.name, func(t *testing.T) {
			s := Style{T: lang.text}
			for _, tc := range []struct {
				name, harness, id, display, want string
			}{
				{"unreviewed-version", "claude-code", "claude-opus-5", "Opus 5", "ModelPlan · " + lang.unknown + " Opus 5"},
				{"raw-id", "claude-code", "claude-future", "", "ModelPlan · " + lang.unknown + " claude-future"},
				{"human-name", "claude-code", "", "Claude Fable 5.1", "ModelPlan · " + lang.unknown + " Claude Fable 5.1"},
				{"wrong-harness", "claude-code", "gpt-6-astra", "GPT-6 Astra", "ModelPlan · " + lang.unknown + " GPT-6 Astra"},
				{"fable-native", "claude-code", "claude-fable-5-1", "Claude Fable 5.1", "Fable 5.1 ★Med"},
				{"astra-native", "codex", "gpt-6-astra", "GPT-6 Astra", "GPT-6 Astra ★Med"},
			} {
				t.Run(tc.name, func(t *testing.T) {
					raw := tc.display
					if raw == "" {
						raw = tc.id
					}
					got := s.Statusline(d, d.Match(tc.harness, tc.id, tc.display), "", false, raw, false)
					if !strings.Contains(got, tc.want) || strings.Contains(got, "未收录") || strings.Contains(got, "not listed") {
						t.Fatalf("got %q; want %q", got, tc.want)
					}
				})
			}
			if got := s.Statusline(nil, nil, "", false, "", false); got != "▲ ModelPlan" {
				t.Fatalf("missing model id should not claim an unreviewed id: %q", got)
			}
		})
	}
}

func TestStatuslineMarksEffortsAboveAndBelowStar(t *testing.T) {
	f := func(v float64) *float64 { return &v }
	m := &digest.Model{ID: "claude-opus-5-5", Name: "Claude Opus 5.5", Recommended: "medium",
		Efforts: []digest.Effort{{Effort: "low", Label: "Low", Ability: f(60)}, {Effort: "medium", Label: "Med", Ability: f(70)}, {Effort: "high", Label: "High", Ability: f(74.8)}}}
	d := &digest.Digest{Models: []digest.Model{*m}}
	m = &d.Models[0]
	s := Style{Color: true, T: ZH}
	if got := s.Statusline(d, m, "high", false, "", true); !strings.Contains(got, "\x1b[38;5;221mHigh\x1b[0m\x1b[38;5;244m (★Med)") || !strings.Contains(got, "74.8") {
		t.Errorf("above = %q", got)
	}
	if got := s.Statusline(d, m, "low", false, "", true); !strings.Contains(got, "\x1b[38;5;117mLow\x1b[0m") {
		t.Errorf("below = %q", got)
	}
	if got := (Style{T: ZH, Narrow: true}).Statusline(d, m, "high", false, "", true); got != "▲ Opus 5.5 High (★Med)" {
		t.Errorf("narrow drops the ability: %q", got)
	}
}

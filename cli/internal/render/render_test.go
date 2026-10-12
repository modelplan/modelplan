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
				{"unreviewed-version", "claude-code", "claude-opus-5", "Opus 5", "Model Plan · " + lang.unknown + " Opus 5"},
				{"raw-id", "claude-code", "claude-future", "", "Model Plan · " + lang.unknown + " claude-future"},
				{"human-name", "claude-code", "", "Claude Fable 5.1", "Model Plan · " + lang.unknown + " Claude Fable 5.1"},
				{"wrong-harness", "claude-code", "gpt-6-astra", "GPT-6 Astra", "Model Plan · " + lang.unknown + " GPT-6 Astra"},
				{"fable-native", "claude-code", "claude-fable-5-1", "Claude Fable 5.1", "Fable 5.1 ★Med"},
				{"astra-native", "codex", "gpt-6-astra", "GPT-6 Astra", "GPT-6 Astra ★Med"},
			} {
				t.Run(tc.name, func(t *testing.T) {
					raw := tc.display
					if raw == "" {
						raw = tc.id
					}
					got := s.Statusline(d, d.Match(tc.harness, tc.id, tc.display), "", false, raw)
					if !strings.Contains(got, tc.want) || strings.Contains(got, "未收录") || strings.Contains(got, "not listed") {
						t.Fatalf("got %q; want %q", got, tc.want)
					}
				})
			}
			if got := s.Statusline(nil, nil, "", false, ""); got != "▲ Model Plan" {
				t.Fatalf("missing model id should not claim an unreviewed id: %q", got)
			}
		})
	}
}

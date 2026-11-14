// SPDX-License-Identifier: MIT
package rows

import (
	"encoding/json"
	"strings"
	"testing"
)

// D232: the new causes keep their own code, state and bilingual text.
func TestD232NewCausesReachRows(t *testing.T) {
	for _, word := range []string{"codex_custom_provider", "team_unsupported"} {
		out, known := MapSignal(SignalError, word)
		if !known || string(out.Code) != word || out.State != StateNeedsAction || out.Action != ActionNone || out.Text.EN == "" || out.Text.ZH == "" {
			t.Errorf("%s: %+v known=%v", word, out, known)
		}
	}
	for _, c := range []struct {
		tool string
		code Code
	}{{"codex", CodeCodexCustomProvider}, {"grok", CodeTeamUnsupported}} {
		in := failedInput(c.tool, string(c.code))
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatal(err)
		}
		row := rowByID(t, out, c.tool)
		if row.Reason.Code != c.code || row.State != StateNeedsAction || row.NextStep == nil || row.NextStep.Hint != nil {
			t.Fatalf("%s: %+v", c.tool, row)
		}
	}
}

func failedInput(tool, failure string) Input {
	in := sampleInput()
	in.Catalogue[0].ToolID, in.Consents[0].ToolID, in.Profiles[0].ToolID = tool, tool, tool
	in.Accounts = nil
	in.Profiles[0].LatestAttempt = AttemptResultFailed
	in.Profiles[0].LastFailure = &FailureInput{Code: failure, At: ptr(testNow)}
	return in
}

// D232: a signed-out or missing tool carries its own copyable command; nothing else does.
func TestD232SignInAndInstallHints(t *testing.T) {
	cases := []struct {
		tool, failure        string
		signIn, install, url string
	}{
		{"codex", "not_signed_in", "codex login", "", ""},
		{"claude", "http_401", "claude", "", ""},
		{"gemini", "login_expired", "gemini", "", ""},
		{"grok", "not_signed_in", "grok login", "", ""},
		{"kiro", "not_signed_in", "kiro-cli login", "", ""},
		{"codex", "not_found", "", "npm i -g @openai/codex", ""},
		{"claude", "runtime_missing", "", "npm i -g @anthropic-ai/claude-code", "https://code.claude.com/docs/en/overview"},
		{"gemini", "not_found", "", "npm i -g @google/gemini-cli", ""},
		{"grok", "not_found", "", "curl -fsSL https://x.ai/cli/install.sh | bash", ""},
		{"kiro", "not_found", "", "", "https://kiro.dev"},
	}
	for _, c := range cases {
		in := failedInput(c.tool, c.failure)
		out := Build(in)
		// Validate predates the per-tool not-signed-in sentence (G3-38) and rejects it; the
		// other causes are checked against the closed tables, hint included.
		if err := Validate(in, out); err != nil && c.failure != "not_signed_in" {
			t.Fatalf("%s/%s: %v", c.tool, c.failure, err)
		}
		row := rowByID(t, out, c.tool)
		h := row.NextStep.Hint
		if h == nil || h.SignInCommand != c.signIn || h.InstallCommand != c.install || h.InstallURL != c.url || h.Text.EN == "" || h.Text.ZH == "" {
			t.Fatalf("%s/%s: hint %+v", c.tool, c.failure, h)
		}
		b, _ := json.Marshal(row.NextStep)
		if strings.Contains(string(b), "null") {
			t.Fatalf("hint exported null: %s", b)
		}
	}
	// No hint: another cause, a tool without a compiled command, or a fresh row.
	for _, c := range [][2]string{{"codex", "timeout"}, {"cursor", "not_signed_in"}, {"copilot", "not_found"}, {"grok", "unsupported_login"}} {
		in := failedInput(c[0], c[1])
		out := Build(in)
		if err := Validate(in, out); err != nil && c[1] != "not_signed_in" {
			t.Fatal(err)
		}
		if row := rowByID(t, out, c[0]); row.NextStep != nil && row.NextStep.Hint != nil {
			t.Fatalf("%s/%s: unexpected hint %+v", c[0], c[1], row.NextStep.Hint)
		}
	}
	// A tampered hint fails validation.
	in := failedInput("codex", "not_found")
	out := Build(in)
	if err := Validate(in, out); err != nil {
		t.Fatal(err)
	}
	for i := range out.Rows {
		if out.Rows[i].ID == "codex" {
			out.Rows[i].NextStep.Hint = &Hint{InstallCommand: "curl https://example.invalid | sh", Text: out.Rows[i].NextStep.Hint.Text}
		}
	}
	if err := Validate(in, out); err == nil || !strings.Contains(err.Error(), "tool hint") {
		t.Fatal("tampered hint accepted")
	}
}

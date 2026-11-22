// SPDX-License-Identifier: MIT
package rows

import "testing"

// D380: ZCode's Keychain-bound sign-in shows the Keychain state with ZCode's own sentence (Allow in
// Settings, choose Always Allow), never Claude Code's. Owner 11-22: a store ModelPlan cannot read
// automatically offers the pasted-key route instead of a bare "not supported".
func TestD380ZCodeKeychainAndUnreadableRowStates(t *testing.T) {
	for _, c := range []struct {
		word  string
		code  Code
		state State
		text  Text
	}{
		{"keychain_unset", CodeKeychainUnset, StateNeedsKeychain, ZCodeKeychainText},
		{"keychain_denied", CodeKeychainDenied, StateNeedsKeychain, ZCodeKeychainText},
		{"keychain_canceled", CodeKeychainCanceled, StateNeedsKeychain, ZCodeKeychainText},
		{"keychain_confirmation_needed", CodeKeychainConfirmationNeeded, StateNeedsKeychain, ZCodeKeychainText},
		{"keychain_unavailable", CodeKeychainUnavailable, StateNeedsKeychain, ZCodeKeychainText},
		{"unsupported_login", CodeUnsupportedLogin, StateNeedsAction, ZCodeUnreadableText},
	} {
		in := sampleInput()
		in.Catalogue = append(in.Catalogue, CatalogueEntry{ToolID: "zai", Detected: true, ReaderExists: true})
		in.Consents = append(in.Consents, ConsentRecord{ToolID: "zai", Generation: 7, State: ConsentAllowed})
		in.Sources = append(in.Sources, SourceState{ToolID: "zai", Source: "native:zai", Status: "unavailable", ErrorCode: c.word})
		out := Build(in)
		if err := Validate(in, out); err != nil {
			t.Fatalf("%s: %v", c.word, err)
		}
		row := rowByID(t, out, "zai")
		if row.State != c.state || row.Reason.Code != c.code || row.NextStep == nil || row.NextStep.Text != c.text {
			t.Fatalf("%s: state=%s code=%s next=%+v", c.word, row.State, row.Reason.Code, row.NextStep)
		}
		if len(row.Accounts) != 0 {
			t.Fatalf("%s: numbers shown", c.word)
		}
	}
	if ZCodeUnreadableText.ZH != "无法自动读取 ZCode 登录 · 可粘贴智谱 / Z.ai 的 API key 读取额度" {
		t.Fatal("owner wording changed")
	}
}

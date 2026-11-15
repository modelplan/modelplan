// SPDX-License-Identifier: MIT
package quota

import "testing"

// The quota monitor answers HTTP 200 with a body code 500 for a key that has no Coding Plan. The
// fixture is Token Monitor's (tests/shared/zaiLimits.test.js@b6b5548, "keeps a no-plan body code
// 500 as a state"; docs/providers/zai.md: "code:500 (a key without a subscription) is a state, not
// a failure"). It is the plan's absence, not a server error. Not yet checked against a real key.
func TestZaiBodyCode500IsNoPlan(t *testing.T) {
	e := zaiParse(t, `{"code":500,"msg":"当前用户不存在coding plan"}`)
	if e.Status != "error" || e.ErrorCode != "no_plan" || e.Error != "no_plan" || len(e.Windows) != 0 {
		t.Fatalf("%+v", e)
	}
	if ReaderErrorCode("no_plan") != "no_plan" {
		t.Fatal("no_plan is not a reader cause code")
	}
	// A documented API error envelope with 500 is still the server's.
	if e := zaiParse(t, `{"error":{"code":"500","message":"synthetic"}}`); e.ErrorCode != "http_5xx" {
		t.Fatalf("%+v", e)
	}
}

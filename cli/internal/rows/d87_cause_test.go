// SPDX-License-Identifier: MIT
package rows

import "testing"

// D87 slice 4: each reader failure word keeps its own row code, state and bounded text.
func TestD87ReaderCauseCodesReachRows(t *testing.T) {
	for _, c := range []struct {
		word  string
		code  Code
		state State
	}{
		{"not_found", CodeNotFound, StateNeedsAction},
		{"runtime_missing", CodeRuntimeMissing, StateNeedsAction},
		{"timeout", CodeTimeout, StateFailed},
		{"rpc_error", CodeRPCError, StateFailed},
		{"closed", CodeClosed, StateFailed},
		{"no_key", CodeKeyMissing, StateNeedsAction},
		{"region_refused", CodeRegionRefused, StateNeedsAction},
	} {
		out, known := MapSignal(SignalError, c.word)
		if !known || out.Code != c.code || out.State != c.state || out.Text.EN == "" || out.Text.ZH == "" {
			t.Errorf("%s: %+v known=%v", c.word, out, known)
		}
		if string(c.code) != c.word && c.word != "no_key" {
			t.Errorf("%s: code spelling %q", c.word, c.code)
		}
	}
}

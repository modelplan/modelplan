// SPDX-License-Identifier: MIT
package consent

import (
	"testing"
	"time"
)

func TestKeychainStatusAndAllowsShareLegacyAndAPIPolicy(t *testing.T) {
	for _, tc := range []struct {
		name, tool, reader, backend, choice, mode, want string
		denied                                          bool
	}{
		{"legacy native", "claude", "native:claude", "native", "", Automatic, "allowed", false},
		{"legacy alias", "claude", "native:claude-code", "native", "", Automatic, "allowed", false},
		{"API allow", "claude", "native:claude", "native", "allow", Automatic, "allowed", false},
		{"API unset", "claude", "native:claude", "native", "unset", Automatic, "unset", false},
		{"API deny", "claude", "native:claude", "native", "deny", Automatic, "denied", false},
		{"source Deny", "claude", "native:claude", "native", "", Automatic, "denied", true},
		{"passive legacy", "claude", "native:claude", "native", "", Passive, "denied", false},
		{"off legacy", "claude", "native:claude", "native", "", Off, "denied", false},
		{"Codex", "codex", "native:codex", "native", "allow", Automatic, "unset", false},
		{"helper", "claude", "codexbar:claude", "codexbar", "allow", Automatic, "unset", false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			s := Empty()
			if err := Set(&s, tc.tool, true, tc.reader, tc.backend, time.Now()); err != nil {
				t.Fatal(err)
			}
			r := s.Tools[tc.tool]
			if tc.choice != "" {
				choice := tc.choice
				if choice == "unset" {
					choice = ""
				}
				SetKeychain(&r, choice)
			}
			if tc.denied {
				r.DeniedSources = map[string]bool{"keychain": true}
			}
			s.Tools[tc.tool] = r
			status := s.KeychainStatus(tc.tool, tc.mode)
			if status != tc.want || s.Allows(tc.tool, "keychain", tc.mode) != (status == "allowed") {
				t.Fatal(status, tc.want, s)
			}
		})
	}
}

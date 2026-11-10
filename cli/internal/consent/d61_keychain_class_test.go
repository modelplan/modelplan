// SPDX-License-Identifier: MIT
package consent

import "testing"

// D61 (owner 2026-11-08, #718): before the first-run Done, readers that never prompt may read
// (D27), while any reader that can show a macOS Keychain prompt reads only after the user ticked
// it. The rule follows the scope's access class (ScopeDefinition.Keychain), never a vendor list.
func TestD61KeychainClassWaitsForTheFirstRunChoice(t *testing.T) {
	fresh := Empty()
	prompting, plain := 0, 0
	for _, d := range Definitions() {
		if d.Keychain {
			prompting++
			if got := fresh.KeychainStatus(d.Tool, Automatic); got == "allowed" {
				t.Fatalf("%s can prompt for the Keychain but is allowed before any choice", d.ID)
			}
			continue
		}
		if d.DefaultCheck {
			plain++
			if !fresh.AllowsScope(d.ID, Automatic) {
				t.Fatalf("%s never prompts and is on by default (D27), so it may read before Done", d.ID)
			}
		}
	}
	if prompting == 0 || plain == 0 {
		t.Fatalf("expected both classes in the compiled policy, got %d prompting and %d plain", prompting, plain)
	}
}

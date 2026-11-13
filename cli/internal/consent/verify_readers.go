// SPDX-License-Identifier: MIT
package consent

import (
	"os"
	"strings"
)

// VerifyReadersEnv is a verification-only narrowing switch (device runs on
// the test Macs): a comma list of consent tool IDs. When it is set, every
// permission read through Load or ReadOnly treats each other tool as denied,
// including default-on local and runtime scopes. It never grants anything:
// a listed tool keeps exactly its saved or default decision. An invalid entry
// denies every tool. Unset means no effect. Writes (Change, Transaction)
// reload the file without it, so the narrowing is never persisted.
const VerifyReadersEnv = "MODELPLAN_VERIFY_READERS"

// verifyReaders reports the allowed tool set and whether narrowing applies.
func verifyReaders() (map[string]bool, bool) {
	raw, set := os.LookupEnv(VerifyReadersEnv)
	if !set {
		return nil, false
	}
	allowed := map[string]bool{}
	for _, part := range strings.Split(raw, ",") {
		id := strings.TrimSpace(part)
		if id == "" {
			continue
		}
		if !ValidTool(id) {
			return map[string]bool{}, true
		}
		allowed[id] = true
	}
	return allowed, true
}

// narrowForVerification returns s with every tool outside the verification
// list denied. The caller's maps are copied, never mutated.
func narrowForVerification(s State) State {
	allowed, set := verifyReaders()
	if !set {
		return s
	}
	tools := make(map[string]Record, len(s.Tools))
	for id, r := range s.Tools {
		tools[id] = cloneRecord(r)
	}
	scopes := make(map[string]Record, len(s.Scopes))
	for id, r := range s.Scopes {
		scopes[id] = cloneRecord(r)
	}
	deny := func(m map[string]Record, id string) {
		r, ok := m[id]
		if !ok {
			r = Record{ConsentTextVersion: TextVersion}
		}
		r.Allowed = false
		m[id] = r
	}
	for id := range s.Tools {
		if !allowed[id] {
			deny(tools, id)
		}
	}
	for id := range s.Scopes {
		tool, _, _ := strings.Cut(id, ".")
		if !allowed[tool] {
			deny(scopes, id)
		}
	}
	// A tool record vetoes undecided default-on scopes; a scope record covers
	// the schema-2 path directly.
	for _, d := range Definitions() {
		if !allowed[d.Tool] {
			deny(tools, d.Tool)
			deny(scopes, d.ID)
		}
	}
	s.Tools, s.Scopes = tools, scopes
	return s
}

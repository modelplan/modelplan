// SPDX-License-Identifier: MIT
package appserver

import (
	"strings"
	"time"
)

// RestartDelay is the child supervision contract for clients. A protocol
// mismatch is terminal. The fifth crash in a rolling ten minutes is terminal;
// an explicit user Retry starts a new history. A new child uses a new session.
func RestartDelay(crashes []time.Time, now time.Time, protocolMismatch bool) (time.Duration, bool) {
	if protocolMismatch {
		return 0, false
	}
	count := 0
	for _, at := range crashes {
		if !at.After(now) && now.Sub(at) < 10*time.Minute {
			count++
		}
	}
	if count >= 5 {
		return 0, false
	}
	delay := time.Second
	for i := 1; i < count; i++ {
		delay *= 2
	}
	if delay > 30*time.Second {
		delay = 30 * time.Second
	}
	return delay, true
}

// ChildEnvironmentKeys is the single launch-environment contract. Generators
// publish it for non-Go launchers; return a fresh slice so callers cannot change it.
func ChildEnvironmentKeys() []string {
	return []string{"HOME", "KIMI_CODE_API_KEY", "LANG", "LC_ALL", "LC_CTYPE", "MINIMAX_CODING_API_KEY", "OPENCODE_API_KEY", "PATH", "TMPDIR", "Z_AI_API_KEY"}
}

// ChildEnvironment creates an allow-listed copy without inspecting the host
// environment. Native launchers must also close unrelated FDs, drain stdout and
// stderr concurrently, and close/reap the child on exit/cancel.
func ChildEnvironment(input []string) []string {
	allowed := map[string]bool{}
	for _, key := range ChildEnvironmentKeys() {
		allowed[key] = true
	}
	result := []string{}
	seen := map[string]bool{}
	for _, entry := range input {
		key, _, ok := strings.Cut(entry, "=")
		if ok && allowed[key] && !seen[key] {
			result = append(result, entry)
			seen[key] = true
		}
	}
	return result
}

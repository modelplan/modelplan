// SPDX-License-Identifier: MIT
package consent

import (
	"sort"
	"strings"
)

// ScopeDefinition is compiled authority. Catalogue detection is presence only;
// it cannot add permissions or promote defaults.
type ScopeDefinition struct {
	ID, Tool, Class, Route string
	DefaultCheck           bool
	Keychain               bool
}

func Definitions() []ScopeDefinition {
	var out []ScopeDefinition
	for _, id := range []string{
		ScopeOpenCodeV2LocalHistory, ScopeClaudeLocalHistory, ScopeClaudeAccountUsageSavedLogin,
		ScopeCodexLocalHistory, ScopeCodexRuntimeUsage,
		ScopeCursorLocalHistory, ScopeCursorAccountUsageSavedLogin,
		ScopeGeminiLocalHistory, ScopeGeminiAccountUsageSavedLogin,
		ScopeGrokLocalHistory, ScopeGrokAccountUsageSavedLogin,
		ScopeKimiLocalHistory, ScopeKimiAccountUsageSavedLogin, ScopeKimiAccountUsageAPIKey,
		ScopeKiroRuntimeUsage, ScopeCopilotLocalHistory, ScopeCopilotRuntimeUsage,
		ScopeAntigravityRuntimeUsage, ScopeZaiLocalHistory, ScopeZaiAccountUsageAPIKey,
		ScopeOpenCodeGoLocalHistory, ScopeOpenCodeGoAccountUsageAPIKey,
		ScopeMiniMaxAccountUsageAPIKey, ScopeAmpLocalHistory, ScopeDroidLocalHistory, ScopeQwenLocalHistory,
	} {
		tool, path, _ := strings.Cut(id, ".")
		d := ScopeDefinition{ID: id, Tool: tool}
		switch path {
		case "local_history":
			d.Class, d.Route, d.DefaultCheck = Local, "local_log", true
		case "runtime_usage":
			d.Class, d.Route, d.DefaultCheck = Runtime, "runtime_rpc", true
		case "account_usage.saved_login":
			d.Class, d.Route = Credential, "saved_login_api"
		case "account_usage.api_key":
			d.Class, d.Route = ExplicitKey, "api_key_api"
		}
		if id == ScopeOpenCodeV2LocalHistory {
			d.DefaultCheck = false
		}
		// The GLM Coding Plan key a user saved in their own tool (ZCode's provider file)
		// is a standard route, on by default (owner decision 2026-11-06, G3-21).
		// Claude Code's own saved login is a standard route too (owner decision D27,
		// 2026-11-06, G3-19): read without a consent click. On macOS that login lives in
		// the Keychain, whose read keeps its own recorded choice, so no Keychain prompt
		// appears by default; a Keychain-only login waits for that choice.
		if id == ScopeZaiAccountUsageAPIKey || id == ScopeClaudeAccountUsageSavedLogin {
			d.DefaultCheck = true
		}
		d.Keychain = id == ScopeClaudeAccountUsageSavedLogin
		out = append(out, d)
	}
	return out
}

func Definition(id string) (ScopeDefinition, bool) {
	for _, d := range Definitions() {
		if d.ID == id {
			return d, true
		}
	}
	tool, path, ok := strings.Cut(id, ".")
	if ok && ValidTool(tool) && (path == "account_usage.codexbar" || path == "account_usage.browser_session") {
		return ScopeDefinition{ID: id, Tool: tool, Class: Bridge, Route: strings.TrimPrefix(path, "account_usage.")}, true
	}
	return ScopeDefinition{}, false
}

// ValidScope accepts retired, syntactically valid scopes for tightening only.
// Unknown identifiers never pass allow admission.
func ValidScope(id string) bool {
	parts := strings.Split(id, ".")
	if len(parts) < 2 || len(parts) > 4 {
		return false
	}
	for i, part := range parts {
		if i == 0 {
			if !ValidTool(part) {
				return false
			}
			continue
		}
		if len(part) == 0 || len(part) > 48 {
			return false
		}
		for j, c := range part {
			if (c < 'a' || c > 'z') && (j == 0 || (c < '0' || c > '9') && c != '_') {
				return false
			}
		}
	}
	return true
}

// schemaOneScopes freezes the read paths covered by the shipped tool-level
// grant. Future scopes must not be added here. Helper grants covered a separate
// bridge route; they do not prove access to a native saved-login path.
func schemaOneScopes(tool string, r Record) []string {
	var ids []string
	local := map[string]string{"claude": ScopeClaudeLocalHistory, "codex": ScopeCodexLocalHistory, "gemini": ScopeGeminiLocalHistory, "grok": ScopeGrokLocalHistory, "kimi": ScopeKimiLocalHistory, "copilot": ScopeCopilotLocalHistory, "zai": ScopeZaiLocalHistory, "opencodego": ScopeOpenCodeGoLocalHistory, "amp": ScopeAmpLocalHistory, "droid": ScopeDroidLocalHistory, "qwen": ScopeQwenLocalHistory}
	if id := local[tool]; id != "" {
		ids = append(ids, id)
	}
	if (r.Backend == "codexbar" || r.Backend == "codexbar-compat") && r.ReaderID == "codexbar:"+tool {
		return append(ids, HelperScope(tool, r.BrowserSession))
	}
	if r.Backend != "native" || (r.ReaderID != "native:"+tool && !(tool == "claude" && r.ReaderID == "native:claude-code")) || r.BrowserSession {
		return ids
	}
	remote := map[string]string{"claude": ScopeClaudeAccountUsageSavedLogin, "cursor": ScopeCursorAccountUsageSavedLogin, "gemini": ScopeGeminiAccountUsageSavedLogin, "grok": ScopeGrokAccountUsageSavedLogin, "kimi": ScopeKimiAccountUsageSavedLogin, "codex": ScopeCodexRuntimeUsage, "kiro": ScopeKiroRuntimeUsage, "copilot": ScopeCopilotRuntimeUsage, "antigravity": ScopeAntigravityRuntimeUsage, "zai": ScopeZaiAccountUsageAPIKey, "opencodego": ScopeOpenCodeGoAccountUsageAPIKey, "minimax": ScopeMiniMaxAccountUsageAPIKey}
	if tool == "kimi" && r.KeyEnv != "" {
		remote[tool] = ScopeKimiAccountUsageAPIKey
	}
	if id := remote[tool]; id != "" {
		ids = append(ids, id)
	}
	return ids
}

func setToolScopes(s *State, tool string, r Record) {
	if s.Scopes == nil {
		s.Scopes = map[string]Record{}
	}
	for _, id := range schemaOneScopes(tool, r) {
		d, _ := Definition(id)
		copy := r
		copy.Allowed = r.Allowed && !r.DeniedSources[d.Class]
		s.Scopes[id] = copy
		if !copy.Allowed {
			s.RevokeScope(id)
		}
	}
	// A whole-tool revoke also tightens scopes of retired routes.
	if !r.Allowed {
		for id, old := range s.Scopes {
			if strings.HasPrefix(id, tool+".") {
				old.Allowed = false
				s.RevokeScope(id)
				s.Scopes[id] = old
			}
		}
	}
}

func (s State) AllowsScope(id, mode string) bool {
	if mode == Off {
		return false
	}
	d, known := Definition(id)
	if !known {
		return false
	}
	r, decided := s.Scopes[id]
	if decided {
		if !r.Allowed || r.ConsentTextVersion != TextVersion || r.DeniedSources[d.Class] {
			return false
		}
	} else {
		// Until first-run decisions are made, established local/runtime paths keep
		// their credential-free defaults. A tool denial remains a veto.
		if s.RequireConsent {
			return false
		}
		if !d.DefaultCheck {
			return false
		}
		// An older tool-level allow predates this scope and did not refuse it. A tool
		// denial, a stale consent text, a denied source or a chosen non-native backend
		// still vetoes it, so migration never widens a CodexBar choice.
		if r, decided := s.Tools[d.Tool]; decided && (!r.Allowed || r.ConsentTextVersion != TextVersion || r.DeniedSources[d.Class] || (r.Backend != "" && r.Backend != "native")) {
			return false
		}
	}
	return mode == Automatic || mode == Passive && (d.Class == Local || d.Class == Runtime || d.Class == ExplicitKey)
}

func (s State) scopeFor(tool, class string) string {
	if class == Bridge {
		return HelperScope(tool, s.Tools[tool].BrowserSession)
	}
	if class == "keychain" {
		class = Credential
	}
	if class == Credential {
		// Runtime paths authenticate under their owning runtime.
		if tool == "codex" || tool == "kiro" || tool == "copilot" || tool == "antigravity" {
			class = Runtime
		}
		if tool == "zai" || tool == "minimax" || tool == "opencodego" || tool == "kimi" && s.Tools[tool].KeyEnv != "" {
			class = ExplicitKey
		}
	}
	for _, d := range Definitions() {
		if d.Tool == tool && d.Class == class {
			return d.ID
		}
	}
	return ""
}

func (s State) ScopeDecided(tool, class string) bool {
	_, ok := s.Scopes[s.scopeFor(tool, class)]
	return ok
}

// HelperScope keeps standard and separately authorized browser-session routes
// distinct, including for a retired provider whose native catalogue disappeared.
func HelperScope(tool string, browser bool) string {
	if browser {
		return tool + ".account_usage.browser_session"
	}
	return tool + ".account_usage.codexbar"
}
func SetBrowserSession(s *State, tool string, browser bool) {
	opposite := HelperScope(tool, !browser)
	if old, exists := s.Scopes[opposite]; exists {
		old.Allowed = false
		s.RevokeScope(opposite)
		s.Scopes[opposite] = old
	}
	r := s.Tools[tool]
	r.BrowserSession = browser
	s.Tools[tool] = r
	setToolScopes(s, tool, r)
}

// AutoLocalLogScopes lists the scopes D240 (owner 2026-11-13) allows without a prompt for
// tools installed after the first run: local-log scopes only (session/history logs on this
// Mac; no credential read, no network call), on by default, for a tool with no decision yet.
// Saved-login, runtime and key scopes stay opt-in. Sorted.
func AutoLocalLogScopes(s State, tools map[string]bool) []string {
	var out []string
	for _, d := range Definitions() {
		if !tools[d.Tool] || d.Class != Local || d.Route != "local_log" || !d.DefaultCheck || d.Keychain {
			continue
		}
		if _, decided := s.Tools[d.Tool]; decided {
			continue
		}
		if _, decided := s.Scopes[d.ID]; decided {
			continue
		}
		out = append(out, d.ID)
	}
	sort.Strings(out)
	return out
}

// AutoLaterClosedScopes lists the scopes the D240 grant records as off next to the local-log
// scopes it allows (#924): every undecided runtime, saved-login or key scope of the same tools
// that would pass while undecided (DefaultCheck). Without this, the tool record that the
// local-log grant writes admits that tool's runtime or account reader, so a tool installed
// after the first run would be launched or its account read without a click. Undecided scopes
// that are off by default stay undecided. The user can turn any of them on. Sorted.
func AutoLaterClosedScopes(s State, allowed []string) []string {
	tools := map[string]bool{}
	for _, id := range allowed {
		if d, known := Definition(id); known && d.Class == Local {
			tools[d.Tool] = true
		}
	}
	out := []string{}
	for _, d := range Definitions() {
		if !tools[d.Tool] || d.Class == Local || !d.DefaultCheck {
			continue
		}
		if _, decided := s.Scopes[d.ID]; decided {
			continue
		}
		out = append(out, d.ID)
	}
	sort.Strings(out)
	return out
}

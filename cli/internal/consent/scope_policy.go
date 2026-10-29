// SPDX-License-Identifier: MIT
package consent

import "strings"

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
		ScopeClaudeLocalHistory, ScopeClaudeAccountUsageSavedLogin,
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
	}
	// A whole-tool revoke also tightens scopes of retired routes.
	if !r.Allowed {
		for id, old := range s.Scopes {
			if strings.HasPrefix(id, tool+".") {
				old.Allowed = false
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
		if _, decided := s.Tools[d.Tool]; decided {
			return false
		}
		if !d.DefaultCheck {
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
		s.Scopes[opposite] = old
	}
	r := s.Tools[tool]
	r.BrowserSession = browser
	s.Tools[tool] = r
	setToolScopes(s, tool, r)
}

package consent

// Stable read-scope identifiers shared by persistence, reader admission and the
// app-server. A scope names a read path. New scopes never inherit old grants.
const (
	ScopeClaudeLocalHistory           = "claude.local_history"
	ScopeClaudeAccountUsageSavedLogin = "claude.account_usage.saved_login"
	ScopeCodexLocalHistory            = "codex.local_history"
	ScopeCodexRuntimeUsage            = "codex.runtime_usage"
	ScopeCursorLocalHistory           = "cursor.local_history"
	ScopeCursorAccountUsageSavedLogin = "cursor.account_usage.saved_login"
	ScopeGeminiLocalHistory           = "gemini.local_history"
	ScopeGeminiAccountUsageSavedLogin = "gemini.account_usage.saved_login"
	ScopeGrokLocalHistory             = "grok.local_history"
	ScopeGrokAccountUsageSavedLogin   = "grok.account_usage.saved_login"
	ScopeKimiLocalHistory             = "kimi.local_history"
	ScopeKimiAccountUsageSavedLogin   = "kimi.account_usage.saved_login"
	ScopeKimiAccountUsageAPIKey       = "kimi.account_usage.api_key"
	ScopeKiroRuntimeUsage             = "kiro.runtime_usage"
	ScopeCopilotLocalHistory          = "copilot.local_history"
	ScopeCopilotRuntimeUsage          = "copilot.runtime_usage"
	ScopeAntigravityRuntimeUsage      = "antigravity.runtime_usage"
	ScopeZaiLocalHistory              = "zai.local_history"
	ScopeZaiAccountUsageAPIKey        = "zai.account_usage.api_key"
	ScopeOpenCodeGoLocalHistory       = "opencodego.local_history"
	ScopeOpenCodeGoAccountUsageAPIKey = "opencodego.account_usage.api_key"
	ScopeMiniMaxAccountUsageAPIKey    = "minimax.account_usage.api_key"
	ScopeAmpLocalHistory              = "amp.local_history"
	ScopeDroidLocalHistory            = "droid.local_history"
	ScopeQwenLocalHistory             = "qwen.local_history"
)

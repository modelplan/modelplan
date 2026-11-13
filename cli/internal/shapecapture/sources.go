// SPDX-License-Identifier: MIT
package shapecapture

import (
	"os"
	"path/filepath"
	"sort"
)

// Source is one file family a reader consumes.
type Source struct {
	Label  string   // logical name used in output; never a real path
	Glob   []string // patterns under the tool root
	Format string   // json, jsonl or sqlite
	Newest int      // how many newest matching files to sample
	Allow  Allow
	Tables []string // sqlite only: allow-listed table names
}

// Tool is one supported tool.
type Tool struct {
	Name    string
	Root    func(Env) string
	Sources []Source
	Note    string // shown in the manifest when nothing can be captured
}

// Env carries the locations a capture may read.
type Env struct {
	Home     string
	CacheDir string
	Getenv   func(string) string
}

func (e Env) env(k string) string {
	if e.Getenv != nil {
		return e.Getenv(k)
	}
	return os.Getenv(k)
}

func under(sub ...string) func(Env) string {
	return func(e Env) string { return filepath.Join(append([]string{e.Home}, sub...)...) }
}

var common = Allow{
	"type": Enum, "role": Enum, "status": Enum, "model": Enum, "effort": Enum, "speed": Enum,
	"timestamp": Time, "input_tokens": Struct, "output_tokens": Struct, "total_tokens": Struct,
}

func merge(parts ...Allow) Allow {
	out := Allow{}
	for _, p := range parts {
		for k, v := range p {
			out[k] = v
		}
	}
	return out
}

// Tools lists the supported tools in a fixed order.
func Tools() []Tool {
	return []Tool{
		{Name: "codex", Root: func(e Env) string {
			if h := e.env("CODEX_HOME"); h != "" && filepath.IsAbs(h) {
				return h
			}
			return filepath.Join(e.Home, ".codex")
		}, Sources: []Source{
			{Label: "sessions", Glob: []string{"sessions/*/*/*/*.jsonl"}, Format: "jsonl", Newest: 3, Allow: merge(common, Allow{
				"payload": Struct, "info": Struct, "total_token_usage": Struct, "last_token_usage": Struct,
				"cached_input_tokens": Struct, "reasoning_output_tokens": Struct, "model_context_window": Struct,
				"rate_limits": Struct, "primary": Struct, "secondary": Struct, "used_percent": Struct,
				"window_minutes": Struct, "resets_in_seconds": Struct, "resets_at": Time, "plan_type": Enum,
				"credits": Struct, "has_credits": Struct, "unlimited": Struct, "balance": Struct,
				"reasoning_effort": Enum, "service_tier": Enum, "collaboration_mode": Struct, "mode": Enum,
				"settings": Struct, "started_at_ms": Time, "duration_ms": Struct, "item": Struct, "usage": Struct,
				"error": Struct, "turn_id": Struct, "id": Struct,
			})},
			{Label: "auth", Glob: []string{"auth.json"}, Format: "json", Newest: 1, Allow: Allow{
				"auth_mode": Enum, "tokens": Struct, "id_token": Struct, "access_token": Struct,
				"refresh_token": Struct, "account_id": Struct, "last_refresh": Time, "OPENAI_API_KEY": Struct,
			}},
		}},
		{Name: "claude", Root: func(e Env) string {
			if h := e.env("CLAUDE_CONFIG_DIR"); h != "" && filepath.IsAbs(h) {
				return h
			}
			return filepath.Join(e.Home, ".claude")
		}, Sources: []Source{
			{Label: "sessions", Glob: []string{"projects/*/*.jsonl"}, Format: "jsonl", Newest: 3, Allow: merge(common, Allow{
				"message": Struct, "usage": Struct, "cache_creation_input_tokens": Struct, "cache_read_input_tokens": Struct,
				"cache_creation": Struct, "ephemeral_5m_input_tokens": Struct, "ephemeral_1h_input_tokens": Struct,
				"service_tier": Enum, "stop_reason": Enum, "requestId": Struct, "thinkingDurationMs": Struct,
				"isSidechain": Struct, "isMeta": Struct, "isCompactSummary": Struct, "content": Struct,
				"cwd": Struct, "sessionId": Struct, "version": Struct, "gitBranch": Struct, "userType": Enum,
				"uuid": Struct, "parentUuid": Struct, "id": Struct,
			})},
			{Label: "credentials", Glob: []string{".credentials.json"}, Format: "json", Newest: 1, Allow: Allow{
				"claudeAiOauth": Struct, "accessToken": Struct, "refreshToken": Struct, "expiresAt": Time,
				"scopes": Struct, "subscriptionType": Enum, "rateLimitTier": Enum,
			}},
		}},
		{Name: "gemini", Root: func(e Env) string {
			if h := e.env("GEMINI_HOME"); h != "" && filepath.IsAbs(h) {
				return h
			}
			return filepath.Join(e.Home, ".gemini")
		}, Sources: []Source{
			{Label: "chats", Glob: []string{"tmp/*/chats/*.json", "tmp/*/chats/*.jsonl"}, Format: "json", Newest: 3, Allow: merge(common, Allow{
				"sessionId": Struct, "projectHash": Struct, "startTime": Time, "lastUpdated": Time, "messages": Struct,
				"id": Struct, "content": Struct, "tokens": Struct, "input": Struct, "output": Struct, "cached": Struct,
				"thoughts": Struct, "tool": Struct, "total": Struct, "usageMetadata": Struct, "promptTokenCount": Struct,
				"candidatesTokenCount": Struct, "totalTokenCount": Struct, "cachedContentTokenCount": Struct,
				"thoughtsTokenCount": Struct, "toolUsePromptTokenCount": Struct,
			})},
			{Label: "oauth", Glob: []string{"oauth_creds.json"}, Format: "json", Newest: 1, Allow: Allow{
				"access_token": Struct, "refresh_token": Struct, "scope": Struct, "token_type": Enum,
				"id_token": Struct, "expiry_date": Time,
			}},
		}},
		{Name: "grok", Root: func(e Env) string {
			if h := e.env("GROK_HOME"); h != "" && filepath.IsAbs(h) {
				return h
			}
			return filepath.Join(e.Home, ".grok")
		}, Sources: []Source{
			{Label: "auth", Glob: []string{"auth.json"}, Format: "json", Newest: 1, Allow: Allow{
				"key": Struct, "auth_mode": Enum, "user_id": Struct, "expires_at": Time, "oidc_issuer": Struct,
				"oidc_client_id": Struct, "principal_id": Struct, "principal_type": Enum, "team_id": Struct,
			}},
			{Label: "sessions", Glob: []string{"sessions/*/*.jsonl", "sessions/*.jsonl"}, Format: "jsonl", Newest: 3, Allow: merge(common, Allow{
				"payload": Struct, "data": Struct, "info": Struct, "message": Struct, "token_usage": Struct,
				"tokenUsage": Struct, "usage": Struct, "inputTokens": Struct, "outputTokens": Struct,
				"cacheReadTokens": Struct, "cacheWriteTokens": Struct, "reasoningTokens": Struct, "created_at": Time,
				"session_kind": Enum, "protocol_version": Struct, "num_messages": Struct,
			})},
		}},
		{Name: "antigravity", Root: func(e Env) string { return e.CacheDir }, Sources: []Source{
			{Label: "observed", Glob: []string{"observed/antigravity-v1.json"}, Format: "json", Newest: 1, Allow: Allow{
				"schemaVersion": Struct, "failures": Struct, "availability": Enum, "loginGeneration": Struct,
				"goodGeneration": Struct, "lastGood": Struct, "windows": Struct, "resetTime": Time,
				"remainingFraction": Struct, "modelId": Enum, "observedAt": Time,
			}},
		}, Note: "Antigravity quota comes from the local app endpoint; only the reader's own observed state is captured."},
		{Name: "kiro", Root: under(".kiro"), Note: "The Kiro reader consumes CLI output, not a file; nothing on disk is captured."},
		{Name: "opencode", Root: func(e Env) string {
			if h := e.env("XDG_DATA_HOME"); h != "" && filepath.IsAbs(h) {
				return filepath.Join(h, "opencode")
			}
			return filepath.Join(e.Home, ".local", "share", "opencode")
		}, Sources: []Source{
			{Label: "db", Glob: []string{"opencode.db"}, Format: "sqlite", Newest: 1, Tables: []string{"session_message"}, Allow: Allow{
				"type": Enum, "data": Struct, "time": Struct, "created": Time, "completed": Time, "tokens": Struct,
				"input": Struct, "output": Struct, "reasoning": Struct, "cache": Struct, "read": Struct, "write": Struct,
				"model": Struct, "id": Enum, "modelID": Enum, "providerID": Enum, "role": Enum, "mode": Enum,
			}},
		}},
		{Name: "zcode", Root: under(".zcode", "cli", "db"), Sources: []Source{
			{Label: "db", Glob: []string{"db.sqlite"}, Format: "sqlite", Newest: 1, Tables: []string{"model_usage", "session"}, Allow: Allow{
				"model_id": Enum, "started_at": Time, "completed_at": Time, "output_tokens": Struct,
				"input_tokens": Struct, "cache_read_input_tokens": Struct, "cache_creation_input_tokens": Struct,
			}},
		}},
	}
}

// ToolNames lists the supported tool names.
func ToolNames() []string {
	var n []string
	for _, t := range Tools() {
		n = append(n, t.Name)
	}
	sort.Strings(n)
	return n
}

// newest returns up to n regular files matching the patterns, newest first. Symlinks are skipped.
func newest(root string, patterns []string, n int) []string {
	type fm struct {
		p string
		t int64
	}
	var all []fm
	for _, pat := range patterns {
		matches, _ := filepath.Glob(filepath.Join(root, pat))
		for _, m := range matches {
			fi, err := os.Lstat(m)
			if err != nil || !fi.Mode().IsRegular() {
				continue
			}
			all = append(all, fm{m, fi.ModTime().UnixNano()})
		}
	}
	sort.Slice(all, func(i, j int) bool { return all[i].t > all[j].t })
	var out []string
	for i := 0; i < len(all) && i < n; i++ {
		out = append(out, all[i].p)
	}
	return out
}

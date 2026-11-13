// SPDX-License-Identifier: MIT
package rows

import (
	"net/url"
	"regexp"
	"strings"
)

type title struct{ ID, EN, ZH, Vendor string }

var titles = []title{
	{"claude", "Claude Code", "Claude Code", "claude"}, {"codex", "Codex", "Codex", "openai"},
	{"cursor", "Cursor", "Cursor", "cursor"}, {"copilot", "GitHub Copilot", "GitHub Copilot", "copilot"},
	{"gemini", "Gemini CLI", "Gemini CLI", ""}, {"grok", "Grok Build", "Grok Build", ""},
	{"kimi", "Kimi Code", "Kimi Code", "kimi"}, {"zai", "ZCode / GLM", "ZCode / GLM", "glm"},
	{"qwen", "Qwen", "Qwen", ""}, {"opencodego", "OpenCode Go", "OpenCode Go", "opencode"},
	{"kiro", "Kiro", "Kiro", ""}, {"amp", "Amp", "Amp", ""}, {"droid", "Droid", "Droid", ""},
	{"antigravity", "Antigravity", "Antigravity", ""}, {"minimax", "MiniMax", "MiniMax", ""},
}
var toolPattern = regexp.MustCompile(`^[a-z][a-z0-9-]{0,47}$`)
var refPattern = regexp.MustCompile(`^[a-f0-9]{16}$`)

// CanonicalTool uses fixed source aliases only; it never creates a tool id from
// an arbitrary profile, login, endpoint, or provider label.
func CanonicalTool(value string) string {
	if strings.HasPrefix(value, "native:") {
		value = strings.TrimPrefix(value, "native:")
	} else if strings.HasPrefix(value, "codexbar:") {
		value = strings.TrimPrefix(value, "codexbar:")
	}
	switch value {
	case "claude-code":
		return "claude"
	case "zcode", "glm":
		return "zai"
	case "opencode":
		return "opencodego"
	}
	return value
}
func declaredID(plan string) string { return "declared:" + url.PathEscape(plan) }
func declaredKey(id string) (string, bool) {
	if !strings.HasPrefix(id, "declared:") {
		return "", false
	}
	key, err := url.PathUnescape(strings.TrimPrefix(id, "declared:"))
	return key, err == nil && key != "" && declaredID(key) == id
}
func rowTitle(id string) (Name, *string, int) {
	for i, t := range titles {
		if t.ID == id {
			var vendor *string
			if t.Vendor != "" {
				value := t.Vendor
				vendor = &value
			}
			return Name{EN: t.EN, ZH: t.ZH}, vendor, i
		}
	}
	return Name{EN: "AI tool", ZH: "AI 工具"}, nil, len(titles)
}
func safeRef(ref *string, off bool) *string {
	if off || ref == nil || !refPattern.MatchString(*ref) {
		return nil
	}
	value := *ref
	return &value
}

// Values are compiled labels, never provider names. Lookup is exact after case
// folding; unknown harness plans export only {id:"unknown"}.
var plans = map[string]Name{
	"free": {EN: "Free", ZH: "免费"}, "plus": {EN: "Plus", ZH: "Plus"}, "pro": {EN: "Pro", ZH: "Pro"},
	"max": {EN: "Max", ZH: "Max"}, "team": {EN: "Team", ZH: "团队"}, "teams": {EN: "Teams", ZH: "团队"},
	"business": {EN: "Business", ZH: "企业"}, "enterprise": {EN: "Enterprise", ZH: "企业"},
	"ultra": {EN: "Ultra", ZH: "Ultra"}, "premium": {EN: "Premium", ZH: "Premium"},
	"grok build": {EN: "Grok Build", ZH: "Grok Build"}, "the x subscription": {EN: "The X Subscription", ZH: "The X Subscription"},
	"kimi code": {EN: "Kimi Code", ZH: "Kimi Code"}, "kimi code (china)": {EN: "Kimi Code (China)", ZH: "Kimi Code（中国）"},
	"minimax": {EN: "MiniMax", ZH: "MiniMax"},
}

func planValue(raw, declared string) Plan {
	if declared != "" {
		name := Name{EN: declared, ZH: declared, UserAuthored: true}
		return Plan{ID: declared, Name: &name}
	}
	id := strings.ToLower(raw)
	if name, ok := plans[id]; ok {
		return Plan{ID: id, Name: &name}
	}
	// Cursor's reader has its own fixed vocabulary, not arbitrary plan suffixes.
	if strings.HasPrefix(id, "cursor ") {
		suffix := strings.TrimPrefix(id, "cursor ")
		switch suffix {
		case "hobby", "pro", "pro+", "pro-plus", "ultra", "business", "teams", "plus", "premium", "super", "free":
			name := Name{EN: "Cursor " + suffix, ZH: "Cursor " + suffix}
			return Plan{ID: "cursor-" + suffix, Name: &name}
		}
	}
	return Plan{ID: "unknown"}
}

var limitKeys = map[string]bool{"main": true, "reserve": true, "premium_interactions": true, "code_review": true, "requests": true, "tokens": true, "spend": true, "credits": true, "five_hour": true, "daily": true, "weekly": true, "monthly": true, "other": true}
var poolKeys = map[string]bool{"main": true, "reserve": true, "code_review": true, "premium_interactions": true, "other": true}

func limitKey(raw string) string {
	if raw == "" {
		return "main"
	}
	if limitKeys[raw] {
		return raw
	}
	return "other"
}
func poolKey(raw string) string {
	if raw == "" {
		return "main"
	}
	if poolKeys[raw] {
		return raw
	}
	return "other"
}

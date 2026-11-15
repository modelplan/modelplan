// SPDX-License-Identifier: MIT
package quota

// Codex custom model provider check (D232). Behaviour reference: CodexBar
// Sources/CodexBarCore/Providers/Codex/CodexCLIBackendConfiguration.swift at
// steipete/CodexBar 7447bc77c2497323d9c41e40164ce705533493c8 (MIT, Copyright (c) 2026
// Peter Steinberger; notice in desktop/third-party/NOTICES.md). Independent Go
// implementation: no source is vendored.
//
// When Codex is set to a model provider other than OpenAI (Amazon Bedrock or any
// custom provider that does not use the ChatGPT login), its app-server has no ChatGPT
// plan limits to report. ModelPlan reads Codex's config.toml read-only and bounded, keeps
// none of its values, and only answers whether that is the case.

import (
	"path/filepath"
	"strings"

	"github.com/pelletier/go-toml/v2"
)

type codexProviderConfig struct {
	ModelProvider *string `toml:"model_provider"`
	Providers     map[string]struct {
		RequiresOpenAIAuth *bool `toml:"requires_openai_auth"`
	} `toml:"model_providers"`
}

// codexUsesCustomProvider is true only when config.toml names a model provider that is
// not OpenAI's and that does not declare the ChatGPT login. A missing, unreadable or
// malformed file answers false, so the ordinary failure code stays.
func codexUsesCustomProvider(codexHome string) bool {
	if codexHome == "" || !filepath.IsAbs(codexHome) {
		return false
	}
	b, status := readBounded(filepath.Join(codexHome, "config.toml"), 256<<10)
	if status != "" {
		return false
	}
	var cfg codexProviderConfig
	if toml.Unmarshal(b, &cfg) != nil || cfg.ModelProvider == nil {
		return false
	}
	id := strings.TrimSpace(*cfg.ModelProvider)
	switch strings.ToLower(id) {
	case "", "openai", "chatgpt":
		return false
	}
	if p, ok := cfg.Providers[id]; ok && p.RequiresOpenAIAuth != nil && *p.RequiresOpenAIAuth {
		return false
	}
	return true
}

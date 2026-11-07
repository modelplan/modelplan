package quota

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ZaiConfigSource is a CLIJIT-authorised selected profile, never an automatic
// search list. Paths stay transient. No project-level configuration is scanned.
// OpenCodeProvider must be the active provider; a model name alone proves nothing.
type ZaiConfigSource struct{ Tool, SettingsPath, AuthPath, OpenCodeProvider, Region string }
type zaiConfigSourceKey struct{}

// RefreshConfiguredZai uses the existing native Z.ai reader after both consent
// and endpoint provenance checks. The caller routes it as provider "zai", under
// the same provider lock/gate as any other Z.ai source. No new provider alias.
func RefreshConfiguredZai(ctx context.Context, cache string, source ZaiConfigSource, now time.Time) ZaiConfigResult {
	ctx = context.WithValue(ctx, zaiConfigSourceKey{}, source)
	collectZaiConfig(ctx, nil, cache, now)
	return ReadZaiConfigCache(ctx, cache, now)
}

// ZaiConfigRegion accepts only the vendor's documented Coding Plan endpoints.
// Exact hosts, HTTPS and fixed paths: no lookalike suffix, custom port, userinfo,
// query, fragment, gateway or forwarding from another provider's base URL.
func ZaiConfigRegion(base string) string {
	u, err := url.Parse(base)
	if err != nil || u.Scheme != "https" || u.User != nil || u.Port() != "" || u.RawQuery != "" || u.Fragment != "" || u.RawPath != "" {
		return ""
	}
	path := strings.TrimSuffix(u.Path, "/")
	if path != "/api/anthropic" && path != "/api/coding/paas/v4" {
		return ""
	}
	switch u.Host {
	case "api.z.ai":
		return "global"
	case "open.bigmodel.cn":
		return "bigmodel-cn"
	}
	return ""
}

// zaiConfigFile refuses symlinks at every path component and checks the opened
// inode. Only bounded regular files from the authorised profile are inspected.
func zaiConfigFile(path string) ([]byte, error) {
	if !filepath.IsAbs(path) {
		return nil, codeError("file_unreadable", "configuration unavailable")
	}
	for p := filepath.Clean(path); ; p = filepath.Dir(p) {
		fi, err := os.Lstat(p)
		if err != nil {
			code := "file_unreadable"
			if os.IsNotExist(err) {
				code = "file_missing"
			}
			return nil, codeError(code, "configuration unavailable")
		}
		if fi.Mode()&os.ModeSymlink != 0 {
			return nil, codeError("file_unreadable", "configuration unavailable")
		}
		if p == filepath.Dir(p) {
			break
		}
	}
	before, err := os.Lstat(path)
	if err != nil || !before.Mode().IsRegular() || before.Size() > 256<<10 {
		return nil, codeError("file_unreadable", "configuration unavailable")
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, codeError("file_unreadable", "configuration unavailable")
	}
	defer f.Close()
	after, err := f.Stat()
	if err != nil || !os.SameFile(before, after) {
		return nil, codeError("file_unreadable", "configuration unavailable")
	}
	b, err := io.ReadAll(io.LimitReader(f, 256<<10+1))
	if err != nil || len(b) > 256<<10 {
		return nil, codeError("file_unreadable", "configuration unavailable")
	}
	return b, nil
}
func zaiConfiguredKey(source ZaiConfigSource) (region, key, state string) {
	region, key, state, _ = zaiConfiguredKeyCode(source)
	return
}
func zaiConfiguredKeyCode(source ZaiConfigSource) (region, key, state, code string) {
	b, err := zaiConfigFile(source.SettingsPath)
	if err != nil {
		return "", "", "not_detected", errorCode(err)
	}
	switch source.Tool {
	case "claude-code":
		var cfg struct {
			Env struct {
				Base  string `json:"ANTHROPIC_BASE_URL"`
				Token string `json:"ANTHROPIC_AUTH_TOKEN"`
				Key   string `json:"ANTHROPIC_API_KEY"`
			} `json:"env"`
		}
		if json.Unmarshal(b, &cfg) != nil {
			return "", "", "not_supported_yet", "parse_error"
		}
		region = ZaiConfigRegion(cfg.Env.Base)
		if region == "" {
			return "", "", "not_supported_yet", "unsupported_login"
		}
		key = cfg.Env.Token
		if key == "" {
			key = cfg.Env.Key
		}
	case "opencode":
		// Explicit matching provider options are required; do not harvest arbitrary
		// saved auth slots, infer selection from a filename or assume default hosts.
		var cfg struct {
			Provider map[string]struct {
				Options struct {
					Base string `json:"baseURL"`
					Key  string `json:"apiKey"`
				} `json:"options"`
			} `json:"provider"`
		}
		if json.Unmarshal(b, &cfg) != nil || source.OpenCodeProvider == "" {
			return "", "", "not_supported_yet", "unsupported_login"
		}
		provider, ok := cfg.Provider[source.OpenCodeProvider]
		if !ok {
			return "", "", "not_supported_yet", "unsupported_login"
		}
		region = ZaiConfigRegion(provider.Options.Base)
		if region == "" {
			return "", "", "not_supported_yet", "unsupported_login"
		}
		key = provider.Options.Key
		if strings.HasPrefix(key, "{env:") && strings.HasSuffix(key, "}") {
			name := strings.TrimSuffix(strings.TrimPrefix(key, "{env:"), "}")
			if !envName.MatchString(name) {
				return "", "", "not_supported_yet", "unsupported_login"
			}
			key = os.Getenv(name)
		} else if strings.ContainsAny(key, "{}") {
			return "", "", "not_supported_yet", "unsupported_login"
		}
		if key == "" && source.AuthPath != "" {
			b, err = zaiConfigFile(source.AuthPath)
			if err != nil {
				return "", "", "not_detected", errorCode(err)
			}
			var auth map[string]struct {
				Type string `json:"type"`
				Key  string `json:"key"`
			}
			if json.Unmarshal(b, &auth) != nil || auth[source.OpenCodeProvider].Type != "api" {
				return "", "", "not_supported_yet", "unsupported_login"
			}
			key = auth[source.OpenCodeProvider].Key
		}
	case "zcode":
		region, key, state, code = zcodeProviderKey(b)
		if state != "" {
			return "", "", state, code
		}
	default:
		return "", "", "not_supported_yet", "unsupported_login"
	}
	key = strings.TrimSpace(key)
	if key == "" {
		return "", "", "expired_login", "unsupported_login"
	}
	if len(key) > 4096 || strings.ContainsAny(key, "\r\n\x00") {
		return "", "", "not_supported_yet", "unsupported_login"
	}
	return region, key, "", ""
}
func fetchZaiConfig(ctx context.Context, c *http.Client, _, _ string, now time.Time) codexbarEntry {
	e, _ := fetchZaiConfigKey(ctx, c, now)
	return e
}

// fetchZaiConfigKey also returns the key it read, so the caller can record which subscription
// answered without opening the file again. The key itself is never stored.
func fetchZaiConfigKey(ctx context.Context, c *http.Client, now time.Time) (codexbarEntry, string) {
	source, ok := ctx.Value(zaiConfigSourceKey{}).(ZaiConfigSource)
	if !ok {
		return codexbarEntry{Status: "error", ErrorCode: "unsupported_login", Error: zaiConfigNext("not_supported_yet")}, ""
	}
	region, key, state, code := zaiConfiguredKeyCode(source)
	if state != "" {
		return codexbarEntry{Status: "error", ErrorCode: code, Error: zaiConfigNext(state)}, ""
	}
	if source.Region != "" && region != source.Region {
		return codexbarEntry{Status: "error", ErrorCode: "unsupported_login", Error: zaiConfigNext("not_supported_yet")}, ""
	}
	if c == nil {
		c = nativeClient
	}
	client := *c
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	authorization := "Bearer " + key
	if source.Tool == "zcode" {
		authorization = key
	}
	e := fetchZaiAuthorization(ctx, &client, region, key, authorization, now)
	if e.Status != "ok" {
		// Existing parser messages can contain provider text; never propagate it.
		state = "upstream_changed"
		if strings.Contains(e.Error, "rejected") {
			state = "expired_login"
		}
		e.Error = zaiConfigNext(state)
	}
	// Only numeric usage windows survive. Configured key possession doesn't prove
	// membership or a particular plan, and generic server plan text isn't retained.
	e.Plan = ""
	return e, key
}

// ZCodeProviderConfig: the provider file ZCode Desktop and its CLI share. Only this fixed
// location is used; no other file or credential store of ZCode is opened.
func ZCodeProviderConfig(home string) string {
	return filepath.Join(home, ".zcode", "v2", "provider_config.json")
}

// zcodeTemplateRegion: ZCode's own Coding Plan templates (zcode-builtin.json), used only when
// the selected provider inherits its endpoint from one of them.
var zcodeTemplateRegion = map[string]string{"zai-api": "global", "bigmodel-api": "bigmodel-cn"}

// zcodeProviderKey reads only the provider ZCode itself has selected
// (config.defaultModelSelection.providerId) and only when it is a Coding Plan key on a
// documented Z.ai/BigModel endpoint; this is the provider ZCode's own Plan usage panel reads.
// Account logins keep no key in this file and stay "not supported yet". Option B of the
// 2026-11-05 research note.
func zcodeProviderKey(b []byte) (region, key, state, code string) {
	var cfg struct {
		SchemaVersion int `json:"schemaVersion"`
		Config        struct {
			ProviderConfigRules struct {
				ProviderRules []struct {
					ProviderID string  `json:"providerId"`
					TemplateID *string `json:"templateId"`
					Enabled    *bool   `json:"enabled"`
					Config     struct {
						Access *struct {
							Type   string  `json:"type"`
							APIKey *string `json:"apiKey"`
						} `json:"access"`
						API *struct {
							BaseURL *string `json:"baseUrl"`
						} `json:"api"`
					} `json:"config"`
				} `json:"providerRules"`
			} `json:"providerConfigRules"`
			DefaultModelSelection *struct {
				ProviderID string `json:"providerId"`
			} `json:"defaultModelSelection"`
		} `json:"config"`
	}
	if json.Unmarshal(b, &cfg) != nil || cfg.SchemaVersion != 1 {
		return "", "", "not_supported_yet", "parse_error"
	}
	selected := cfg.Config.DefaultModelSelection
	if selected == nil || selected.ProviderID == "" || strings.HasPrefix(selected.ProviderID, "account:") {
		return "", "", "not_supported_yet", "unsupported_login"
	}
	found := 0
	for _, rule := range cfg.Config.ProviderConfigRules.ProviderRules {
		if rule.ProviderID != selected.ProviderID {
			continue
		}
		if found++; found > 1 || (rule.Enabled != nil && !*rule.Enabled) || rule.Config.Access == nil || rule.Config.Access.APIKey == nil {
			return "", "", "not_supported_yet", "unsupported_login"
		}
		base := ""
		if rule.Config.API != nil && rule.Config.API.BaseURL != nil {
			base = *rule.Config.API.BaseURL
		}
		switch rule.Config.Access.Type {
		case "zhipu-coding-plan-api-key":
			if base != "" {
				region = ZaiConfigRegion(base)
			} else if rule.TemplateID != nil {
				region = zcodeTemplateRegion[*rule.TemplateID]
			}
		case "api-key":
			region = ZaiConfigRegion(base)
		}
		if region == "" {
			return "", "", "not_supported_yet", "unsupported_login"
		}
		key = *rule.Config.Access.APIKey
	}
	if found != 1 {
		return "", "", "not_supported_yet", "unsupported_login"
	}
	return region, key, "", ""
}

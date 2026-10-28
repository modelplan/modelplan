package quota

import (
	"context"
	"encoding/json"
	"errors"
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
		return nil, errors.New("configuration unavailable")
	}
	for p := filepath.Clean(path); ; p = filepath.Dir(p) {
		fi, err := os.Lstat(p)
		if err != nil || fi.Mode()&os.ModeSymlink != 0 {
			return nil, errors.New("configuration unavailable")
		}
		if p == filepath.Dir(p) {
			break
		}
	}
	before, err := os.Lstat(path)
	if err != nil || !before.Mode().IsRegular() || before.Size() > 256<<10 {
		return nil, errors.New("configuration unavailable")
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, errors.New("configuration unavailable")
	}
	defer f.Close()
	after, err := f.Stat()
	if err != nil || !os.SameFile(before, after) {
		return nil, errors.New("configuration unavailable")
	}
	b, err := io.ReadAll(io.LimitReader(f, 256<<10+1))
	if err != nil || len(b) > 256<<10 {
		return nil, errors.New("configuration unavailable")
	}
	return b, nil
}
func zaiConfiguredKey(source ZaiConfigSource) (region, key, state string) {
	b, err := zaiConfigFile(source.SettingsPath)
	if err != nil {
		return "", "", "not_detected"
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
			return "", "", "not_supported_yet"
		}
		region = ZaiConfigRegion(cfg.Env.Base)
		if region == "" {
			return "", "", "not_supported_yet"
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
			return "", "", "not_supported_yet"
		}
		provider, ok := cfg.Provider[source.OpenCodeProvider]
		if !ok {
			return "", "", "not_supported_yet"
		}
		region = ZaiConfigRegion(provider.Options.Base)
		if region == "" {
			return "", "", "not_supported_yet"
		}
		key = provider.Options.Key
		if strings.HasPrefix(key, "{env:") && strings.HasSuffix(key, "}") {
			name := strings.TrimSuffix(strings.TrimPrefix(key, "{env:"), "}")
			if !envName.MatchString(name) {
				return "", "", "not_supported_yet"
			}
			key = os.Getenv(name)
		} else if strings.ContainsAny(key, "{}") {
			return "", "", "not_supported_yet"
		}
		if key == "" && source.AuthPath != "" {
			b, err = zaiConfigFile(source.AuthPath)
			if err != nil {
				return "", "", "not_detected"
			}
			var auth map[string]struct {
				Type string `json:"type"`
				Key  string `json:"key"`
			}
			if json.Unmarshal(b, &auth) != nil || auth[source.OpenCodeProvider].Type != "api" {
				return "", "", "not_supported_yet"
			}
			key = auth[source.OpenCodeProvider].Key
		}
	default:
		return "", "", "not_supported_yet"
	}
	key = strings.TrimSpace(key)
	if key == "" {
		return "", "", "expired_login"
	}
	if len(key) > 4096 || strings.ContainsAny(key, "\r\n\x00") {
		return "", "", "not_supported_yet"
	}
	return region, key, ""
}
func fetchZaiConfig(ctx context.Context, c *http.Client, _, _ string, now time.Time) codexbarEntry {
	source, ok := ctx.Value(zaiConfigSourceKey{}).(ZaiConfigSource)
	if !ok {
		return codexbarEntry{Status: "error", Error: zaiConfigNext("not_supported_yet")}
	}
	region, key, state := zaiConfiguredKey(source)
	if source.Region != "" && region != source.Region {
		return codexbarEntry{Status: "error", Error: zaiConfigNext("not_supported_yet")}
	}
	if state != "" {
		return codexbarEntry{Status: "error", Error: zaiConfigNext(state)}
	}
	if c == nil {
		c = nativeClient
	}
	client := *c
	client.CheckRedirect = func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }
	e := fetchZai(ctx, &client, region, key, now)
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
	return e
}
